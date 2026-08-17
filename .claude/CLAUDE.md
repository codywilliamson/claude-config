# Working on claude-config

The root `CLAUDE.md` and `AGENTS.md` in this repo are **payload**, not instructions. Sync copies them to `~/.claude/`, where they become the global preferences for every session on the machine. Editing them changes behaviour everywhere, not here. Repo guidance belongs in this file.

## Before committing

```bash
node scripts/test-sync.mjs      # sync behaviour
node scripts/lint-skills.mjs    # frontmatter and context cost
node scripts/scan-content.mjs   # injection, shell patterns, permissions
```

CI runs all three plus shellcheck, PSScriptAnalyzer, gitleaks and zizmor. Run them locally first; they need no dependencies and take seconds.

## The gitignore is deny-by-default

Line 2 is `*`. Everything tracked is explicitly un-ignored below it. A new top-level file or directory is invisible to git until you add a `!` rule, and it will still work perfectly on your machine — that is exactly how `skills/debug/` stayed uncommitted for months.

Anchor runtime ignores with a leading slash. Unanchored `debug/` also matches `skills/debug/`.

## Adding a skill

One directory under `skills/` with a `SKILL.md`. Skills and agents have different frontmatter schemas; `lint-skills.mjs` knows both and CI fails on an unknown field, since Claude Code ignores those silently at runtime.

Descriptions load into every session whether the skill fires or not, so keep them tight. Bodies load only on invocation and can be longer.

## settings.json

Shared base only. Anything true of one machine goes in `~/.claude/settings.local.json`, never here. Use `$HOME` rather than absolute paths — `scan-content.mjs` fails the build on a hardcoded home directory, because it is broken on the next machine.

## Workflows

Pin every action to a commit SHA with the version in a trailing comment. Start each workflow from `permissions: {}` and grant per job. `zizmor --persona=pedantic` must stay clean.

## The README keeps no inventories

No file listings, no directory trees, no measured numbers, no thresholds copied out of scripts. All of that goes stale silently and the README is where people land first. Detail belongs in `docs/`; the README reassures and links.

Prose style for docs is in `skills/writing-technical-docs/`. Pick one of explanation, tutorial, how-to or reference, and do not blend them.

## Commits

Conventional commits, one concern per commit. `commit-guard` enforces this in CI, so a batched or unprefixed commit fails the build.
