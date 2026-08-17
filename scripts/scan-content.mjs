#!/usr/bin/env node
// security scan for a repo whose whole job is to inject text into an LLM and
// shell scripts into your session.
//
//   node scripts/scan-content.mjs
//
// three risks, three file sets. each check runs only against the files that
// actually carry that risk, so nothing needs an exemption from its own rule.
//
//   invisible unicode  every tracked text file
//   shell patterns     the .sh files that hooks and setup actually execute
//   injection phrases  the markdown that gets loaded into a model's context
//   absolute paths     everything, to stop one machine's homedir shipping

import { execFileSync } from 'node:child_process'
import { readFileSync, statSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

// SCAN_ROOT lets the test suite point this at a fixture repo
const REPO = process.env.SCAN_ROOT || dirname(dirname(fileURLToPath(import.meta.url)))

// ── invisible unicode ────────────────────────────────────────────
//
// the attack: a codepoint with no glyph survives human review but is still a
// distinct token to the model. the Unicode Tag block is the nasty one — it
// encodes a full ASCII message that renders as absolutely nothing.
// see https://embracethered.com/blog/posts/2026/scary-agent-skills/

const INVISIBLE = [
  { name: 'unicode tag (ASCII smuggling)', test: (c) => c >= 0xe0000 && c <= 0xe007f },
  { name: 'zero-width', test: (c) => [0x200b, 0x200c, 0x200d, 0x2060, 0xfeff].includes(c) },
  { name: 'bidi override (trojan source)', test: (c) => (c >= 0x202a && c <= 0x202e) || (c >= 0x2066 && c <= 0x2069) },
  { name: 'soft hyphen', test: (c) => c === 0x00ad },
]

// tag chars map onto ascii by subtracting the block base — decode so a finding
// shows what the payload actually said rather than just "something is hidden"
const decodeTag = (cps) => cps.map((c) => String.fromCharCode(c - 0xe0000)).join('')

// ── shell patterns ───────────────────────────────────────────────

const SHELL_PATTERNS = [
  [/\b(curl|wget)\b[^|\n]*\|\s*(sudo\s+)?(bash|sh|zsh)\b/, 'pipes a download straight into a shell'],
  [/\bbase64\s+(-d|--decode)[^|\n]*\|\s*(bash|sh)\b/, 'decodes base64 into a shell'],
  [/\beval\s+["'`]?\$\(\s*(curl|wget)/, 'evals the output of a network fetch'],
  [/\bcurl\b[^\n]*\s(-d|--data(-binary|-raw)?)\s*@/, 'POSTs a local file to a remote host'],
  [/\bnc\b\s+(-e|--exec)/, 'netcat with command execution'],
  [/\bchmod\s+(-R\s+)?777\b/, 'world-writable permissions'],
  [/\brm\s+-rf\s+["']?(\$\{?[A-Za-z_]|\/[^\s"']*\/?\s*$)/, 'rm -rf on an unguarded variable or absolute path'],
]

// ── injection phrases ────────────────────────────────────────────
//
// deliberately narrow. broad phrase matching on prose produces noise, and a
// noisy security check is one people learn to ignore.

const INJECTION_PATTERNS = [
  [/ignore\s+(all\s+)?(your\s+)?(previous|prior|earlier|above)\s+instructions/i, 'instruction override'],
  [/disregard\s+(the\s+)?(above|previous|prior|all\s+earlier)/i, 'instruction override'],
  [/\byou\s+are\s+now\s+(a|an|in)\b/i, 'persona reassignment'],
  [/\b(do\s+not|don'?t)\s+(tell|inform|mention\s+to)\s+the\s+user\b/i, 'concealment from the user'],
  [/<\s*\/?\s*(system|assistant)\s*>/i, 'fake role/message boundary tag'],
]

const HOME_PATH = /(^|[^\w.])(\/home\/[a-z][-\w.]*|\/Users\/[A-Za-z][-\w.]*)(?![\w-])/

// ── walk ─────────────────────────────────────────────────────────

const tracked = execFileSync('git', ['-C', REPO, 'ls-files', '-z'], { encoding: 'utf8' })
  .split('\0')
  .filter(Boolean)
  // vendored upstream marketplace metadata — not ours to police
  .filter((f) => !f.startsWith('plugins/'))

const isText = (f) => {
  try {
    if (statSync(join(REPO, f)).size > 2_000_000) return false
    const b = readFileSync(join(REPO, f))
    return !b.subarray(0, 8000).includes(0)
  } catch {
    return false
  }
}

// anything that reaches a model as instructions, wherever it lives
const inContext = (f) =>
  /^(CLAUDE|AGENTS)\.md$/.test(f) || /^(skills|agents|commands|\.claude)\//.test(f)
const isShell = (f) => f.endsWith('.sh')

const findings = []
const add = (sev, file, line, what, detail) => findings.push({ sev, file, line, what, detail })

for (const file of tracked) {
  if (!isText(file)) continue
  // normalise CRLF so line-anchored patterns behave the same on every platform
  const text = readFileSync(join(REPO, file), 'utf8').replace(/\r\n/g, '\n')
  const lines = text.split('\n')

  // invisible unicode — every file
  lines.forEach((line, i) => {
    const hits = new Map()
    const tags = []
    for (const ch of line) {
      const c = ch.codePointAt(0)
      // a BOM at the very start of the file is legitimate
      if (c === 0xfeff && i === 0 && line.startsWith(ch)) continue
      const kind = INVISIBLE.find((k) => k.test(c))
      if (!kind) continue
      hits.set(kind.name, (hits.get(kind.name) ?? 0) + 1)
      if (c >= 0xe0000 && c <= 0xe007f) tags.push(c)
    }
    for (const [name, n] of hits) {
      const detail = tags.length ? `decodes to: ${JSON.stringify(decodeTag(tags))}` : `${n} occurrence(s)`
      add('error', file, i + 1, `invisible ${name}`, detail)
    }
  })

  // executable risk — only the scripts that actually run
  if (isShell(file)) {
    lines.forEach((line, i) => {
      if (line.trimStart().startsWith('#')) return
      for (const [re, what] of SHELL_PATTERNS) {
        if (re.test(line)) add('error', file, i + 1, what, line.trim().slice(0, 100))
      }
    })
  }

  // prompt injection — only text that reaches a model as instructions
  if (inContext(file)) {
    lines.forEach((line, i) => {
      for (const [re, what] of INJECTION_PATTERNS) {
        if (re.test(line)) add('error', file, i + 1, `possible ${what}`, line.trim().slice(0, 100))
      }
    })
  }

  // machine paths — a public repo should not carry someone's homedir
  lines.forEach((line, i) => {
    const m = HOME_PATH.exec(line)
    if (m) add('warn', file, i + 1, 'absolute home path', m[2])
  })
}

// ── settings policy ──────────────────────────────────────────────
//
// settings.json is the file that decides what claude may do without asking.
// a permission change here is a security change, so it gets its own rules.

const SETTINGS = 'settings.json'
if (tracked.includes(SETTINGS)) {
  let settings
  try {
    settings = JSON.parse(readFileSync(join(REPO, SETTINGS), 'utf8'))
  } catch (e) {
    add('error', SETTINGS, 1, 'invalid JSON', e.message)
  }
  if (settings) {
    const mode = settings.permissions?.defaultMode
    if (mode === 'bypassPermissions') {
      add('error', SETTINGS, 1, 'defaultMode is bypassPermissions', 'disables every permission prompt for anyone who syncs this')
    }
    for (const rule of settings.permissions?.allow ?? []) {
      if (/^Bash$|^Bash\(\s*\*\s*\)$|^Write$|^Edit$/.test(rule)) {
        add('error', SETTINGS, 1, `unbounded allow rule "${rule}"`, 'pre-approves an entire tool with no argument filter')
      }
    }
    const walkHooks = (node) => {
      if (Array.isArray(node)) return node.forEach(walkHooks)
      if (node && typeof node === 'object') {
        if (typeof node.command === 'string' && !/^\s*(bash|sh|node|pwsh)?\s*"?\$(HOME|\{HOME\})/.test(node.command)) {
          add('warn', SETTINGS, 1, 'hook command is not $HOME-relative', node.command.slice(0, 80))
        }
        Object.values(node).forEach(walkHooks)
      }
    }
    walkHooks(settings.hooks ?? {})
  }
}

// ── report ───────────────────────────────────────────────────────

const errors = findings.filter((f) => f.sev === 'error')
const warns = findings.filter((f) => f.sev === 'warn')

console.log(`\nscanned ${tracked.filter(isText).length} tracked text files`)

for (const [label, list] of [['warnings', warns], ['findings', errors]]) {
  if (!list.length) continue
  console.log(`\n${label}`)
  for (const f of list) {
    console.log(`  ${f.sev === 'error' ? '✗' : '!'} ${f.file}:${f.line}  ${f.what}`)
    console.log(`      ${f.detail}`)
  }
}

if (errors.length) {
  console.log(`\n${errors.length} finding(s) — failing\n`)
  process.exit(1)
}
console.log(`\nclean${warns.length ? ` — ${warns.length} warning(s)` : ''}\n`)
