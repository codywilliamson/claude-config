# Cody's Global Claude Code Preferences

> These instructions apply to ALL Claude Code sessions across all repositories.

## Custom Commands

**`/gac`** - Git Add & Commit with comprehensive analysis
- Automatically analyzes all changes and creates structured conventional commits
- Usage: `/gac` or `/gac [optional custom instructions]`

## Git Commit Style

- **always use conventional commits** — `type: description`
- types: `feat`, `fix`, `chore`, `ci`, `test`, `refactor`, `docs`, `style`, `perf`, `build`
- informal lowercase, minimal punctuation
- short and descriptive
- no scope unless it adds clarity (e.g. `fix(api): ...`)
- body only when the "why" isn't obvious from the subject

## Code Style

- DRY and KISS first, always concise
- limited comments, only when necessary
- comments should be lowercase, informal, minimal punctuation

## Engineering Standards

- SRP — one job per file/function; if describing it needs "and", split it
- YAGNI — build exactly what's asked; no config systems, plugins, or speculative future-proofing
- Strict types — no `any` on shared/contract types; keep one source of truth for shared shapes (import, never redefine)
- Readability — named constants over magic values, plain-English function names
- Conventional commits, one concern per commit — never batch unrelated changes

## General Preferences

- Be concise in responses — skip fluff, get to the point
- Don't over-explain — no filler paragraphs, skip obvious observations
- Prefer editing existing files over creating new ones
- Keep files small and focused — split when they get large, avoid bloat (important for context)
- Only change what's asked — no drive-by refactors or unsolicited improvements
- Keep code changes minimal and focused
- Prefer TypeScript for type safety
- Prefer pnpm for package management
- Always review diffs before committing
- Test changes when applicable
- Stay focused on the current task — don't wander into unrelated work or scope creep

## Working Autonomously

When asked to work autonomously (e.g. "work fully autonomously", "don't ask", "just do it"):
- Do not ask clarifying questions — make a reasonable decision, document it, and move on
- If you hit a genuine ambiguity that needs a different architecture, pick the simpler path
- Note the decisions you made (and why) in the final summary
- Still verify before declaring done, and report outcomes faithfully — failing tests, skipped steps, and all

This overrides the default "ask if unclear" (Task Context) for the duration of that task.

## Debugging

- Investigate before fixing — read error paths, logs, and source before editing anything
- Form a hypothesis with evidence, present it, then fix — no guessing
- If first fix doesn't work, re-examine root cause — don't try variations blindly
- One fix at a time, simplest first

## Verification

- Run the real check (tests, typecheck, build, or the app) before claiming something works — evidence before assertions
- Green unit tests ≠ a working app; verify the behavior tests don't cover (UI, integration)
- If something failed or was skipped, say so plainly with the output

## Task Context

- Read the full task context (Trello card comments, attachments, linked cards) before implementing
- Don't start work until requirements are fully understood — ask if unclear

## Infrastructure / SSH

- Check `~/.ssh/config` for custom ports before defaulting to port 22
- Avoid heredocs with complex quoting on remote servers — write scripts locally and scp instead
- When deploying, verify the service is healthy after deploy (curl health endpoint, check logs)
