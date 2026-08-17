# Hooks

Hooks are shell scripts Claude Code runs on session events. They live in `hooks/` and are wired up in `settings.json`, which means they execute on your machine without being invoked — that is the whole point of them, and also the reason they get linted as strictly as anything else here.

All four need `jq` on your PATH. Without it they exit quietly rather than failing your session, so a missing `jq` looks like nothing happening at all.

Each one is written to fail open. If input is missing, malformed, or the tooling it wants is absent, it exits zero and gets out of the way. A hook that can break your session is worse than a hook that occasionally does nothing.

## What runs when

**`prompt-refine.sh`** runs on `UserPromptSubmit`. It counts misspelled words with `aspell` and, when a prompt is typo-heavy enough, injects a note asking Claude to restate what it understood before acting. There are no API calls — it is local spellcheck and heuristics. Every evaluation is logged whether or not it triggered, which is what makes tuning possible. Requires `aspell` in addition to `jq`.

**`pre-commit-validate.sh`** runs on `PreToolUse` matching `Bash`. It inspects the command, ignores everything that is not a `git commit`, and runs the project's typecheck or build first. A failing build blocks the commit. It detects the project type rather than assuming one.

**`file-size-watchdog.sh`** runs on `PreToolUse` matching `Write`. It warns when a file is getting long, with a higher threshold for markup, config and data files than for code. It prompts rather than blocks, because the threshold is a smell and not a rule.

**`session-changelog.sh`** runs on `Stop`. It appends a summary of the session — branch, uncommitted changes, recent commits — to a log. It deduplicates by session ID, since a single session can emit several stop events.

Logs are written under `~/.claude/logs/`. Use `/prompt-refine` to audit the prompt refinement log and tune its heuristics against what it actually caught.

## Writing your own

Hooks receive their input as JSON on stdin and are configured in `settings.json` under the matching event. Two rules keep them portable across the machines this config syncs to:

Reference them as `$HOME/.claude/hooks/...` rather than an absolute path. `scan-content.mjs` fails the build on absolute paths, because one machine's home directory is broken on the next.

Exit zero when you cannot do your job. Missing dependency, empty stdin, unfamiliar project layout — all of these should be silent no-ops. Reserve a non-zero exit for the case where you genuinely mean to stop what Claude was about to do.

If a hook should only run on one machine, do not add it to the repo's `settings.json`. Put it in `~/.claude/settings.local.json` instead, where hook arrays concatenate with the shared ones rather than replacing them. See [sync.md](sync.md).
