# Cody's Global Claude Code Preferences

> These instructions apply to ALL Claude Code sessions across all repositories.

## Custom Commands

**`/gac`** - Git Add & Commit with comprehensive analysis
- Automatically analyzes all changes and creates structured conventional commits
- Usage: `/gac` or `/gac [optional custom instructions]`

## Git Commit Style

- informal lowercase
- minimal punctuation
- short and descriptive

## Code Style

- DRY and KISS first, always concise
- limited comments, only when necessary
- comments should be lowercase, informal, minimal punctuation

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

## Debugging

- Investigate before fixing — read error paths, logs, and source before editing anything
- Form a hypothesis with evidence, present it, then fix — no guessing
- If first fix doesn't work, re-examine root cause — don't try variations blindly
- One fix at a time, simplest first

## Task Context

- Read the full task context (Trello card comments, attachments, linked cards) before implementing
- Don't start work until requirements are fully understood — ask if unclear

## Infrastructure / SSH

- Check `~/.ssh/config` for custom ports before defaulting to port 22
- Avoid heredocs with complex quoting on remote servers — write scripts locally and scp instead
- When deploying, verify the service is healthy after deploy (curl health endpoint, check logs)
