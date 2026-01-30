# Cody's Global Claude Code Preferences

> These instructions apply to ALL Claude Code sessions across all repositories.

## Custom Commands

**`/gac`** - Git Add & Commit with comprehensive analysis
- Automatically analyzes all changes and creates structured conventional commits
- Usage: `/gac` or `/gac [optional custom instructions]`

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

- Keep code changes minimal and focused
- Prefer TypeScript for type safety
- Always review diffs before committing
- Test changes when applicable
