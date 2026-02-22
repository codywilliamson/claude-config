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

**`/trello-dev`** - Trello Development Workflow
- Process Trello cards with full dev cycle: investigate → implement → simplify → review → commit → update Trello
- Usage: `/trello-dev [board-name] [list-name] [card-numbers...]`
- Example: `/trello-dev HP-S3 "In Progress" 179 183`
- Workflow:
  1. Fetch card details and comments
  2. Investigate codebase and implement changes
  3. Run code-simplifier (DRY/KISS) and code-reviewer agents
  4. Create commits with `(Card #XXX)` references
  5. Add Trello comment with non-technical summary AND technical details
  6. Move card to top of "Done" list

**`/load-story`** - Load Environment Library Epic Story Context
- Loads full context for working on a story from the environment library epic
- Usage: `/load-story S07` or `/load-story S12a`
- Location: `C:\Users\Cody\source\notes\Obsidian Vault\work\icom\environment-details\epic\`
- Actions:
  1. Read the story markdown from `stories/{story-id}*.md`
  2. Read the context manifest from `context/{story-id}.yaml`
  3. Read all required source files from icom repo (`C:\Users\Cody\source\repos\icom\`)
  4. Check dependencies in `progress.yaml` - warn if blockers not completed
  5. Load any completed dependency outcomes from `stories/outcomes/`
  6. Present summary: story details, files loaded, dependencies status
  7. Update `progress.yaml` to mark story as `in_progress` with today's date

**`/story-status`** - Check Environment Library Epic Progress
- Shows current epic progress and story status
- Usage: `/story-status` or `/story-status S07`
- Actions:
  1. Read `progress.yaml`
  2. If story ID provided: show that story's status, blockers, and dependents
  3. If no ID: show phase progress summary and next available stories

**`/story-done`** - Complete a Story
- Marks a story as completed and creates outcome file
- Usage: `/story-done S07`
- Actions:
  1. Update `progress.yaml` to mark story as `completed`
  2. Create outcome file from template at `stories/outcomes/{story-id}-outcome.md`
  3. Prompt for: implementation summary, key decisions, files changed
  4. Show which stories are now unblocked

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
