#!/usr/bin/env node
// validate skills, agents and commands against claude code's frontmatter rules,
// and report what they cost in context.
//
//   node scripts/lint-skills.mjs
//
// the context budget is the part people forget. claude code loads every skill's
// name + description into the system prompt on every session, so a bloated
// description is a tax you pay on every turn whether or not the skill runs.
// the body only loads when the skill is invoked, which is why it's a soft cap.

import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs'
import { basename, dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const REPO = dirname(dirname(fileURLToPath(import.meta.url)))

// https://code.claude.com/docs/en/skills — every field claude code accepts on a
// skill. custom commands merged into skills, so commands/*.md share this set.
// an unknown key is almost always a typo, and it fails silently at runtime.
const SKILL_FIELDS = new Set([
  'name', 'description', 'when_to_use', 'argument-hint', 'arguments',
  'disable-model-invocation', 'user-invocable', 'allowed-tools',
  'disallowed-tools', 'model', 'effort', 'context', 'agent', 'background',
  'hooks', 'paths', 'shell', 'metadata', 'license', 'compatibility',
])

// https://code.claude.com/docs/en/sub-agents — a different schema. `tools`, not
// `allowed-tools`, and `color` is valid here but not on a skill.
const AGENT_FIELDS = new Set([
  'name', 'description', 'tools', 'disallowedTools', 'model', 'permissionMode',
  'maxTurns', 'skills', 'mcpServers', 'hooks', 'memory', 'background', 'effort',
  'isolation', 'color', 'initialPrompt',
])

// fields outside the agentskills.io spec don't travel to claude.ai uploads or
// the skills api. worth knowing about, not worth failing over.
const PORTABLE = new Set(['name', 'description', 'license', 'compatibility', 'metadata', 'allowed-tools'])

// description + when_to_use are truncated at 1,536 chars in the skill listing
const DESC_CAP = 1536
// soft ceiling on a body, ~2k tokens. past this, split into references/
const BODY_WARN = 8000

const SCHEMA = {
  skill: { fields: SKILL_FIELDS, capIsError: true, portability: true },
  command: { fields: SKILL_FIELDS, capIsError: true, portability: true },
  // agents aren't uploadable to claude.ai and their descriptions routinely carry
  // <example> blocks, so the listing cap and bracket check are advisory here.
  agent: { fields: AGENT_FIELDS, capIsError: false, portability: false },
}

const errors = []
const warnings = []
const rows = []

const fail = (file, msg) => errors.push(`${file}: ${msg}`)
const warn = (file, msg) => warnings.push(`${file}: ${msg}`)

// minimal frontmatter reader. deliberately not a yaml library: we only need
// top-level keys, and a dependency here would be a supply-chain surface on a
// repo whose whole pitch is "you can audit this".
function frontmatter(text, file) {
  if (!text.startsWith('---\n')) return null
  const end = text.indexOf('\n---', 3)
  if (end === -1) {
    fail(file, 'frontmatter opened with --- but never closed')
    return null
  }
  const body = text.slice(end + 4)
  const out = {}
  let key = null
  for (const line of text.slice(4, end).split('\n')) {
    if (!line.trim() || line.trimStart().startsWith('#')) continue
    const m = /^([A-Za-z_][\w-]*):\s?(.*)$/.exec(line)
    if (m) {
      key = m[1]
      out[key] = m[2].trim()
    } else if (key && /^\s/.test(line)) {
      // continuation or list item
      out[key] = `${out[key]} ${line.trim()}`.trim()
    }
  }
  return { fields: out, body }
}

// git checks these out with CRLF on windows, which is invisible until a parser
// anchored on "---\n" declares every file broken
const read = (p) => readFileSync(p, 'utf8').replace(/\r\n/g, '\n')

function check(path, kind, expectedName) {
  const file = path.slice(REPO.length + 1).replaceAll('\\', '/')
  const schema = SCHEMA[kind]
  const parsed = frontmatter(read(path), file)
  if (!parsed) return fail(file, 'missing YAML frontmatter (--- block at the top)')
  const { fields, body } = parsed

  for (const k of Object.keys(fields)) {
    if (!schema.fields.has(k)) fail(file, `unknown ${kind} frontmatter field "${k}"`)
    else if (schema.portability && !PORTABLE.has(k)) {
      warn(file, `"${k}" is claude-code-only, won't travel to claude.ai uploads`)
    }
  }

  // name is optional everywhere — it defaults to the directory or file name.
  // it only needs checking when someone sets it explicitly.
  const name = fields.name
  if (kind === 'agent' && !name) fail(file, 'agents require an explicit name field')
  if (name) {
    if (!/^[a-z0-9]+(-[a-z0-9]+)*$/.test(name)) fail(file, `name "${name}" must be lowercase-with-hyphens`)
    if (name.length > 64) fail(file, `name is ${name.length} chars, max 64`)
    if (expectedName && name !== expectedName) fail(file, `name "${name}" does not match "${expectedName}"`)
    if (/\b(anthropic|claude)\b/.test(name)) warn(file, 'name contains a reserved word, rejected by the skills api')
  }

  const desc = fields.description ?? ''
  const listing = desc.length + (fields.when_to_use?.length ?? 0)
  if (!desc) {
    fail(file, 'no description — claude uses it to decide when to load this')
  } else if (listing > DESC_CAP) {
    const msg = `description + when_to_use is ${listing} chars, listing truncates at ${DESC_CAP}`
    schema.capIsError ? fail(file, msg) : warn(file, msg)
  }
  if (schema.portability && /[<>]/.test(desc)) {
    warn(file, 'description contains angle brackets, which get escaped in the listing')
  }
  if (body.length > BODY_WARN) warn(file, `body is ${body.length} chars — consider splitting into references/`)

  rows.push({ kind, name: name ?? expectedName ?? basename(path), listing, body: body.length })
}

// ── walk the repo ────────────────────────────────────────────────

const skillsDir = join(REPO, 'skills')
for (const entry of existsSync(skillsDir) ? readdirSync(skillsDir).sort() : []) {
  const dir = join(skillsDir, entry)
  if (!statSync(dir).isDirectory()) continue
  const skill = join(dir, 'SKILL.md')
  if (!existsSync(skill)) {
    fail(`skills/${entry}`, 'directory has no SKILL.md')
    continue
  }
  check(skill, 'skill', entry)
}

for (const [dir, kind] of [['agents', 'agent'], ['commands', 'command']]) {
  const d = join(REPO, dir)
  for (const f of existsSync(d) ? readdirSync(d).sort() : []) {
    if (f.endsWith('.md')) check(join(d, f), kind, basename(f, '.md'))
  }
}

// ── report ───────────────────────────────────────────────────────

const listingTotal = rows.reduce((n, r) => n + r.listing, 0)
const bodyTotal = rows.reduce((n, r) => n + r.body, 0)

console.log('\n  kind     name                        listing    body')
console.log('  ' + '─'.repeat(56))
for (const r of rows.sort((a, b) => b.listing - a.listing)) {
  console.log(`  ${r.kind.padEnd(8)} ${r.name.padEnd(26)} ${String(r.listing).padStart(6)}  ${String(r.body).padStart(6)}`)
}
console.log('  ' + '─'.repeat(56))
console.log(`  ${''.padEnd(8)} ${String(rows.length + ' entries').padEnd(26)} ${String(listingTotal).padStart(6)}  ${String(bodyTotal).padStart(6)}`)
console.log(`\n  always-on listing cost: ~${listingTotal} chars (~${Math.round(listingTotal / 4)} tokens)`)
console.log(`  loaded only when invoked: ~${bodyTotal} chars (~${Math.round(bodyTotal / 4)} tokens)`)

if (warnings.length) {
  console.log('\nwarnings')
  for (const w of warnings) console.log(`  ! ${w}`)
}
if (errors.length) {
  console.log('\nerrors')
  for (const e of errors) console.log(`  ✗ ${e}`)
  console.log(`\n${errors.length} error(s)\n`)
  process.exit(1)
}
console.log(`\nok — ${rows.length} entries valid${warnings.length ? `, ${warnings.length} warning(s)` : ''}\n`)
