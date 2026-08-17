#!/usr/bin/env node
// tests for sync.mjs — the script that writes into your home directory, so the
// bar is "prove it never deletes something it doesn't own".
//
//   node scripts/test-sync.mjs
//
// each test gets a throwaway CLAUDE_HOME. the repo side is the real repo, read
// only, so these also catch a skill that stops parsing.

import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import {
  existsSync, mkdirSync, mkdtempSync, readFileSync,
  rmSync, symlinkSync, writeFileSync,
} from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const REPO = dirname(dirname(fileURLToPath(import.meta.url)))
const SYNC = join(REPO, 'scripts', 'sync.mjs')

const homes = []
function newHome() {
  const d = mkdtempSync(join(tmpdir(), 'claude-sync-test-'))
  homes.push(d)
  return join(d, 'home')
}

// --no-plugins everywhere: CI must not reach the network
const sync = (home, ...args) =>
  execFileSync('node', [SYNC, ...args, '--no-plugins'], {
    env: { ...process.env, CLAUDE_HOME: home },
    encoding: 'utf8',
  })

const readJson = (p) => JSON.parse(readFileSync(p, 'utf8'))
const write = (p, s) => (mkdirSync(dirname(p), { recursive: true }), writeFileSync(p, s))

let passed = 0
let skipped = 0
const failures = []
function t(name, fn) {
  try {
    fn()
    passed++
    console.log(`  ok   ${name}`)
  } catch (e) {
    if (e.skip) {
      skipped++
      console.log(`  skip ${name} — ${e.message}`)
      return
    }
    failures.push({ name, e })
    console.log(`  FAIL ${name}`)
    console.log(`       ${e.message.split('\n')[0]}`)
  }
}

// unprivileged windows can't create symlinks; the behaviour still needs testing
// on linux and macos, so skip rather than pretend it passed
function requireSymlinks(target, path) {
  try {
    symlinkSync(target, path, 'junction')
  } catch {
    throw Object.assign(new Error('symlinks unavailable on this runner'), { skip: true })
  }
}

console.log('\nsync.mjs')

t('push populates an empty home', () => {
  const home = newHome()
  sync(home, 'push')
  assert.ok(existsSync(join(home, 'CLAUDE.md')), 'CLAUDE.md')
  assert.ok(existsSync(join(home, 'skills', 'pr', 'SKILL.md')), 'skills/pr')
  assert.ok(existsSync(join(home, 'settings.json')), 'settings.json')
  assert.ok(existsSync(join(home, 'hooks')), 'hooks/')
})

t('push never deletes a symlinked skill', () => {
  const home = newHome()
  sync(home, 'push')
  const external = join(home, '..', 'external-skill')
  write(join(external, 'SKILL.md'), '# external\n')
  requireSymlinks(external, join(home, 'skills', 'linked'))
  sync(home, 'push')
  assert.ok(existsSync(join(home, 'skills', 'linked', 'SKILL.md')), 'symlink survived')
})

t('push never deletes a machine-only entry', () => {
  const home = newHome()
  sync(home, 'push')
  write(join(home, 'skills', 'private', 'SKILL.md'), '# mine\n')
  write(join(home, 'agents', 'private.md'), '# mine\n')
  sync(home, 'push')
  assert.ok(existsSync(join(home, 'skills', 'private', 'SKILL.md')), 'private skill')
  assert.ok(existsSync(join(home, 'agents', 'private.md')), 'private agent')
})

t('push repairs a deleted file inside an owned entry', () => {
  const home = newHome()
  sync(home, 'push')
  rmSync(join(home, 'skills', 'pr', 'SKILL.md'))
  sync(home, 'push')
  assert.ok(existsSync(join(home, 'skills', 'pr', 'SKILL.md')), 'restored')
})

t('push removes a stale file inside an owned entry', () => {
  const home = newHome()
  sync(home, 'push')
  const stale = join(home, 'skills', 'pr', 'STALE.md')
  writeFileSync(stale, 'x')
  sync(home, 'push')
  assert.ok(!existsSync(stale), 'stale file cleared')
})

t('push is idempotent', () => {
  const home = newHome()
  sync(home, 'push')
  const out = sync(home, 'push')
  assert.match(out, /already matches repo/, 'no file work on second run')
  assert.match(out, /already matches base \+ local/, 'no settings work on second run')
})

t('dry run writes nothing', () => {
  const home = newHome()
  sync(home, 'push', '--dry-run')
  assert.ok(!existsSync(join(home, 'CLAUDE.md')), 'nothing written')
})

console.log('\nsettings merge')

t('local overlay beats the repo base', () => {
  const home = newHome()
  sync(home, 'push')
  const overlay = join(home, 'settings.local.json')
  writeFileSync(overlay, JSON.stringify({ model: 'test-model-xyz' }))
  sync(home, 'push')
  assert.equal(readJson(join(home, 'settings.json')).model, 'test-model-xyz')
})

t('hook arrays concatenate instead of replacing', () => {
  const home = newHome()
  sync(home, 'push')
  const base = readJson(join(REPO, 'settings.json'))
  const event = Object.keys(base.hooks ?? {})[0]
  assert.ok(event, 'repo base defines at least one hook event')
  const baseLen = base.hooks[event].length

  writeFileSync(join(home, 'settings.local.json'), JSON.stringify({
    hooks: { [event]: [{ matcher: '', hooks: [{ type: 'command', command: 'echo local' }] }] },
  }))
  sync(home, 'push')
  const merged = readJson(join(home, 'settings.json'))
  assert.equal(merged.hooks[event].length, baseLen + 1, 'base hook plus local hook')
})

t('repeated pushes do not accumulate hooks', () => {
  const home = newHome()
  sync(home, 'push')
  const base = readJson(join(REPO, 'settings.json'))
  const event = Object.keys(base.hooks ?? {})[0]
  writeFileSync(join(home, 'settings.local.json'), JSON.stringify({
    hooks: { [event]: [{ matcher: '', hooks: [{ type: 'command', command: 'echo local' }] }] },
  }))
  sync(home, 'push')
  const after1 = readJson(join(home, 'settings.json')).hooks[event].length
  sync(home, 'push')
  sync(home, 'push')
  const after3 = readJson(join(home, 'settings.json')).hooks[event].length
  assert.equal(after3, after1, 'hook count stable across pushes')
})

t('first push splits existing drift without losing it', () => {
  const home = newHome()
  mkdirSync(home, { recursive: true })
  // a home that already has machine-local settings, as every real machine does
  const base = readJson(join(REPO, 'settings.json'))
  const drifted = {
    ...base,
    tui: 'fullscreen',
    someLocalKey: { nested: true },
    hooks: {
      ...base.hooks,
      Notification: [{ matcher: '', hooks: [{ type: 'command', command: 'echo machine' }] }],
    },
  }
  writeFileSync(join(home, 'settings.json'), JSON.stringify(drifted, null, 2))

  sync(home, 'push')

  const after = readJson(join(home, 'settings.json'))
  assert.equal(after.tui, 'fullscreen', 'local scalar kept')
  assert.deepEqual(after.someLocalKey, { nested: true }, 'local object kept')
  assert.equal(after.hooks.Notification.length, 1, 'local hook kept')
  const overlay = readJson(join(home, 'settings.local.json'))
  assert.equal(overlay.tui, 'fullscreen', 'drift landed in the overlay')
})

t('push onto a minimal settings.json keeps it and adds the base', () => {
  const home = newHome()
  mkdirSync(home, { recursive: true })
  // the common first-run case: claude code's own defaults, no repo hooks yet
  writeFileSync(join(home, 'settings.json'), JSON.stringify({ model: 'sonnet' }))
  sync(home, 'push')
  const after = readJson(join(home, 'settings.json'))
  assert.equal(after.model, 'sonnet', 'existing local value kept')
  assert.ok(after.hooks, "base's hooks added")
})

t('a hook the machine deleted is restored, not lost', () => {
  const home = newHome()
  sync(home, 'push')
  const base = readJson(join(REPO, 'settings.json'))
  const event = Object.keys(base.hooks ?? {})[0]
  const live = readJson(join(home, 'settings.json'))
  delete live.hooks[event]
  writeFileSync(join(home, 'settings.json'), JSON.stringify(live, null, 2))
  rmSync(join(home, 'settings.local.json'))
  sync(home, 'push')
  assert.ok(readJson(join(home, 'settings.json')).hooks[event], 'repo hook back')
})

console.log('\npull')

t('pull leaves settings.json alone', () => {
  const home = newHome()
  sync(home, 'push')
  const before = readFileSync(join(REPO, 'settings.json'), 'utf8')
  writeFileSync(join(home, 'settings.json'), JSON.stringify({ evil: true }))
  sync(home, 'pull')
  assert.equal(readFileSync(join(REPO, 'settings.json'), 'utf8'), before, 'repo base untouched')
})

t('pull reports untracked entries instead of adopting them', () => {
  const home = newHome()
  sync(home, 'push')
  write(join(home, 'skills', 'brand-new', 'SKILL.md'), '# new\n')
  const out = sync(home, 'pull')
  assert.match(out, /brand-new/, 'reported')
  assert.ok(!existsSync(join(REPO, 'skills', 'brand-new')), 'not silently copied into the repo')
})

for (const d of homes) rmSync(d, { recursive: true, force: true })

const tail = skipped ? `, ${skipped} skipped` : ''
console.log('')
if (failures.length) {
  console.log(`${passed} passed, ${failures.length} failed${tail}\n`)
  for (const f of failures) console.log(`${f.name}\n${f.e.stack}\n`)
  process.exit(1)
}
console.log(`${passed} passed${tail} on ${process.platform}\n`)
