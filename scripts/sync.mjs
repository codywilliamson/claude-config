#!/usr/bin/env node
// sync claude-config repo <-> local claude code install
//
//   node sync.mjs status        show what differs, changes nothing
//   node sync.mjs push          repo -> ~/.claude
//   node sync.mjs pull          ~/.claude -> repo
//
// flags: --dry-run  --no-plugins  --git (git pull --ff-only first)
//
// two rules make this safe to run anywhere, any number of times:
//   1. the repo owns named entries only. anything else in ~/.claude is never
//      read, moved, or deleted — that's how the ~/.agents symlinks survive.
//   2. settings.json is generated, never copied. see mergeSettings below.

import { execFileSync } from 'node:child_process'
import {
  chmodSync, copyFileSync, existsSync, lstatSync, mkdirSync, readdirSync,
  readFileSync, rmSync, writeFileSync,
} from 'node:fs'
import { homedir } from 'node:os'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const REPO = process.env.CLAUDE_CONFIG_REPO || dirname(dirname(fileURLToPath(import.meta.url)))
const LIVE = process.env.CLAUDE_HOME || join(homedir(), '.claude')

// repo-owned entries. TREES are owned per top-level entry inside them, not
// wholesale — ~/.claude/skills/tdd is invisible to us because the repo has no
// skills/tdd. FILES are owned outright.
// AGENTS.md holds the actual preferences and CLAUDE.md is a one-line import of
// it. both have to land in ~/.claude or that import resolves to nothing.
const FILES = ['CLAUDE.md', 'AGENTS.md', 'keybindings.json', 'statusline-command.sh']
const TREES = ['agents', 'commands', 'hooks', 'skills']

const SETTINGS = 'settings.json'
const SETTINGS_LOCAL = 'settings.local.json'

const PLUGINS = [
  ['anthropics/claude-plugins-official', 'frontend-design'],
  ['anthropics/claude-plugins-official', 'typescript-lsp'],
  ['anthropics/claude-plugins-official', 'claude-md-management'],
  ['anthropics/claude-plugins-official', 'superpowers'],
  ['anthropics/claude-plugins-official', 'github'],
  ['anthropics/claude-plugins-official', 'ralph-loop'],
  ['anthropics/claude-plugins-official', 'code-simplifier'],
  ['anthropics/claude-plugins-official', 'playwright'],
  ['anthropics/claude-plugins-official', 'agent-sdk-dev'],
  ['anthropics/claude-code', 'security-guidance'],
  ['anthropics/claude-code', 'feature-dev'],
]

// ── output ───────────────────────────────────────────────────────

const C = process.stdout.isTTY && !process.env.NO_COLOR
const paint = (code, s) => (C ? `\x1b[${code}m${s}\x1b[0m` : s)
const info = (m) => console.log(`${paint('0;34', '→')} ${m}`)
const ok = (m) => console.log(`${paint('0;32', '✓')} ${m}`)
const warn = (m) => console.log(`${paint('0;33', '!')} ${m}`)
const err = (m) => console.error(`${paint('0;31', '✗')} ${m}`)
const header = (m) => console.log(`\n${paint('1;36', m)}`)

// ── settings merge ───────────────────────────────────────────────
//
// live settings.json = mergeSettings(repo base, machine local overlay).
// regenerated from scratch every push, so running twice changes nothing.

const isObj = (v) => v !== null && typeof v === 'object' && !Array.isArray(v)
const canon = (v) =>
  Array.isArray(v) ? v.map(canon)
    : isObj(v) ? Object.fromEntries(Object.keys(v).sort().map((k) => [k, canon(v[k])]))
      : v
const same = (a, b) => JSON.stringify(canon(a)) === JSON.stringify(canon(b))

// hook arrays concatenate (base hooks AND machine hooks both run). everything
// else: local wins.
const isHookList = (path) => path[0] === 'hooks' && path.length === 2

function mergeSettings(base, local, path = []) {
  const out = { ...base }
  for (const [k, lv] of Object.entries(local)) {
    const bv = out[k]
    const p = [...path, k]
    if (isHookList(p) && Array.isArray(bv) && Array.isArray(lv)) out[k] = [...bv, ...lv]
    else if (isObj(bv) && isObj(lv)) out[k] = mergeSettings(bv, lv, p)
    else out[k] = lv
  }
  return out
}

// does `next` preserve everything `live` had? extra keys contributed by the
// base are fine — that's the point of pushing. silently dropping or changing
// something the machine already had is not, so that's what we check for.
function covers(next, live, path = []) {
  if (isObj(live)) {
    if (!isObj(next)) return false
    return Object.entries(live).every(([k, v]) => covers(next[k], v, [...path, k]))
  }
  if (isHookList(path) && Array.isArray(live)) {
    if (!Array.isArray(next)) return false
    const have = new Set(next.map((x) => JSON.stringify(canon(x))))
    return live.every((x) => have.has(JSON.stringify(canon(x))))
  }
  return same(next, live)
}

// inverse of mergeSettings: everything in `live` that `base` doesn't explain.
// used once to split existing machine drift out into the local overlay.
function extractLocal(live, base, path = []) {
  const out = {}
  for (const [k, lv] of Object.entries(live)) {
    const bv = isObj(base) ? base[k] : undefined
    const p = [...path, k]
    if (isObj(lv) && isObj(bv)) {
      const sub = extractLocal(lv, bv, p)
      if (Object.keys(sub).length) out[k] = sub
    } else if (isHookList(p) && Array.isArray(lv) && Array.isArray(bv)) {
      const known = new Set(bv.map((x) => JSON.stringify(canon(x))))
      const extra = lv.filter((x) => !known.has(JSON.stringify(canon(x))))
      if (extra.length) out[k] = extra
    } else if (!same(lv, bv)) {
      out[k] = lv
    }
  }
  return out
}

const readJson = (p) => (existsSync(p) ? JSON.parse(readFileSync(p, 'utf8')) : null)
const writeJson = (p, v) => writeFileSync(p, `${JSON.stringify(v, null, 2)}\n`)

// ── file ops ─────────────────────────────────────────────────────

const listDir = (p) => (existsSync(p) ? readdirSync(p).sort() : [])
const isLink = (p) => existsSync(p) && lstatSync(p).isSymbolicLink()

function walk(root, base = '') {
  const out = []
  for (const name of listDir(join(root, base))) {
    const rel = base ? join(base, name) : name
    const st = lstatSync(join(root, rel))
    if (st.isSymbolicLink()) continue
    if (st.isDirectory()) out.push(...walk(root, rel))
    else out.push(rel)
  }
  return out
}

const differs = (a, b) =>
  !existsSync(b) || readFileSync(a).compare(readFileSync(b)) !== 0

// mirror one owned entry src -> dst, including deleting files that no longer
// exist inside it. never reaches outside the entry.
function mirror(src, dst, plan) {
  if (!existsSync(src)) return
  if (isLink(src) || isLink(dst)) {
    warn(`skipped ${dst.replace(homedir(), '~')} — symlink involved, not touching it`)
    return
  }
  if (lstatSync(src).isFile()) {
    if (differs(src, dst)) plan.push({ op: 'write', src, dst })
    return
  }
  const wanted = walk(src)
  for (const rel of wanted) {
    const s = join(src, rel)
    const d = join(dst, rel)
    if (differs(s, d)) plan.push({ op: 'write', src: s, dst: d })
  }
  const keep = new Set(wanted)
  for (const rel of walk(dst)) {
    if (!keep.has(rel)) plan.push({ op: 'delete', dst: join(dst, rel) })
  }
}

function apply(plan, dryRun) {
  for (const step of plan) {
    if (step.op === 'write') {
      if (!dryRun) {
        mkdirSync(dirname(step.dst), { recursive: true })
        copyFileSync(step.src, step.dst)
      }
    } else if (!dryRun) {
      rmSync(step.dst, { force: true })
    }
  }
}

function describe(plan, from, to) {
  const shorten = (p) => p.replace(LIVE, '~/.claude').replace(REPO, 'repo')
  for (const step of plan) {
    if (step.op === 'write') info(`${shorten(step.dst)}`)
    else warn(`remove ${shorten(step.dst)} (gone from ${from})`)
  }
  if (!plan.length) ok(`${to} already matches ${from}`)
}

// ── owned entries ────────────────────────────────────────────────
//
// discovered from the repo side. an entry the repo doesn't have is not ours.
function ownedEntries() {
  const out = []
  for (const f of FILES) if (existsSync(join(REPO, f))) out.push(f)
  for (const tree of TREES) {
    for (const name of listDir(join(REPO, tree))) out.push(join(tree, name))
  }
  return out
}

// ── commands ─────────────────────────────────────────────────────

function planFiles(from, to) {
  const plan = []
  for (const rel of ownedEntries()) mirror(join(from, rel), join(to, rel), plan)
  return plan
}

function backupLive(dryRun) {
  const src = join(LIVE, SETTINGS)
  if (!existsSync(src) || dryRun) return
  const dir = join(LIVE, 'backups')
  mkdirSync(dir, { recursive: true })
  const stamp = new Date().toISOString().replace(/[:.]/g, '-')
  copyFileSync(src, join(dir, `settings.${stamp}.json`))
}

function pushSettings(dryRun) {
  const base = readJson(join(REPO, SETTINGS))
  if (!base) return warn(`no ${SETTINGS} in repo — skipping`)

  const localPath = join(LIVE, SETTINGS_LOCAL)
  const livePath = join(LIVE, SETTINGS)
  let local = readJson(localPath)

  // first run on this machine: split existing drift out into the overlay so
  // nothing local is lost the first time we generate the file.
  if (local === null) {
    const live = readJson(livePath)
    local = live ? extractLocal(live, base) : {}
    if (live && !covers(mergeSettings(base, local), live)) {
      err(`cannot split ${SETTINGS} without losing something — refusing to touch it`)
      err(`  inspect ${livePath} by hand, or move the machine-only keys into`)
      err(`  ${localPath} yourself and run push again.`)
      return
    }
    if (!dryRun) writeJson(localPath, local)
    const n = Object.keys(local).length
    ok(`created ${SETTINGS_LOCAL} with ${n} machine-local key${n === 1 ? '' : 's'}`)
  }

  const next = mergeSettings(base, local)
  const live = readJson(livePath)
  if (same(next, live)) return ok(`${SETTINGS} already matches base + local`)

  backupLive(dryRun)
  if (!dryRun) writeJson(livePath, next)
  ok(`${SETTINGS} regenerated from base + ${SETTINGS_LOCAL}`)
}

// settings never auto-flows back. guessing which live key is shared and which
// is machine-only is the bug that made this painful in the first place.
function pullSettings() {
  const base = readJson(join(REPO, SETTINGS))
  const local = readJson(join(LIVE, SETTINGS_LOCAL)) || {}
  const live = readJson(join(LIVE, SETTINGS))
  if (!base || !live) return
  if (same(mergeSettings(base, local), live)) return ok(`${SETTINGS} in sync`)

  const drift = extractLocal(live, mergeSettings(base, local))
  warn(`${SETTINGS} has live changes in neither the base nor the overlay:`)
  for (const k of Object.keys(drift)) console.log(`    ${k}`)
  info(`  shared? edit ${join(REPO, SETTINGS)}. machine-only? edit ${join(LIVE, SETTINGS_LOCAL)}.`)
}

function installPlugins() {
  try {
    execFileSync('claude', ['--version'], { stdio: 'ignore' })
  } catch {
    return warn('claude cli not found — skipping plugin install')
  }
  for (const [repo, name] of PLUGINS) {
    try {
      execFileSync('claude', ['plugin', 'install', repo, name], { stdio: 'ignore' })
    } catch {
      // already installed, or offline. neither is worth failing a sync over.
    }
  }
  ok(`${PLUGINS.length} plugins checked`)
}

function untracked() {
  const owned = new Set(ownedEntries())
  const extra = []
  for (const tree of TREES) {
    for (const name of listDir(join(LIVE, tree))) {
      const rel = join(tree, name)
      if (!owned.has(rel) && !isLink(join(LIVE, rel))) extra.push(rel)
    }
  }
  return extra
}

// ── main ─────────────────────────────────────────────────────────

const args = process.argv.slice(2)
const cmd = args.find((a) => !a.startsWith('-')) || 'status'
const dryRun = args.includes('--dry-run')
const noPlugins = args.includes('--no-plugins')

if (!existsSync(join(REPO, 'CLAUDE.md'))) {
  err(`${REPO} doesn't look like the claude-config repo`)
  process.exit(1)
}

// opt-in, because a sync tool that quietly moves your git HEAD is not one you
// can trust. sitting down at another machine, you want this.
if (args.includes('--git')) {
  try {
    execFileSync('git', ['-C', REPO, 'pull', '--ff-only'], { stdio: 'inherit' })
  } catch {
    warn('git pull failed — continuing with the local checkout')
  }
}

if (cmd === 'push') {
  header(`push  repo -> ${LIVE}`)
  if (dryRun) info('dry run, nothing will be written')
  mkdirSync(LIVE, { recursive: true })

  const plan = planFiles(REPO, LIVE)
  describe(plan, 'repo', '~/.claude')
  apply(plan, dryRun)

  pushSettings(dryRun)

  if (!dryRun) {
    for (const f of listDir(join(LIVE, 'hooks'))) {
      // chmodSync, not a chmod subprocess: there is no chmod on windows
      if (f.endsWith('.sh')) chmodSync(join(LIVE, 'hooks', f), 0o755)
    }
  }
  if (!noPlugins && !dryRun) installPlugins()
  console.log('')
  ok(dryRun ? 'dry run complete' : `synced to ${LIVE}`)
} else if (cmd === 'pull') {
  header(`pull  ${LIVE} -> repo`)
  if (dryRun) info('dry run, nothing will be written')

  const plan = planFiles(LIVE, REPO)
  describe(plan, '~/.claude', 'repo')
  apply(plan, dryRun)

  pullSettings()

  const extra = untracked()
  if (extra.length) {
    console.log('')
    info('in ~/.claude but not tracked by the repo (copy in by hand to adopt):')
    for (const rel of extra) console.log(`    ${rel}`)
  }
  console.log('')
  info(`review with: git -C ${REPO} diff`)
} else if (cmd === 'status') {
  header('status')
  const push = planFiles(REPO, LIVE)
  const pull = planFiles(LIVE, REPO)
  console.log(`  repo -> ~/.claude   ${push.length} file(s) differ`)
  console.log(`  ~/.claude -> repo   ${pull.length} file(s) differ`)
  const base = readJson(join(REPO, SETTINGS))
  const local = readJson(join(LIVE, SETTINGS_LOCAL))
  const live = readJson(join(LIVE, SETTINGS))
  if (base && live) {
    const synced = same(mergeSettings(base, local || {}), live)
    console.log(`  settings.json       ${synced ? 'in sync' : 'differs'}${local ? '' : `  (no ${SETTINGS_LOCAL} yet)`}`)
  }
  const extra = untracked()
  if (extra.length) console.log(`  untracked locally   ${extra.length} entry(s)`)
  console.log('')
  info('push:  node scripts/sync.mjs push')
  info('pull:  node scripts/sync.mjs pull')
} else {
  err(`unknown command: ${cmd}`)
  console.log('usage: sync.mjs [status|push|pull] [--dry-run] [--no-plugins]')
  process.exit(1)
}
