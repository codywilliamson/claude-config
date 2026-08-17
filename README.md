# claude-config

[![CI](https://github.com/codywilliamson/claude-config/actions/workflows/ci.yml/badge.svg)](https://github.com/codywilliamson/claude-config/actions/workflows/ci.yml)
[![Security](https://github.com/codywilliamson/claude-config/actions/workflows/security.yml/badge.svg)](https://github.com/codywilliamson/claude-config/actions/workflows/security.yml)
[![Commitlint](https://github.com/codywilliamson/claude-config/actions/workflows/commitlint.yml/badge.svg)](https://github.com/codywilliamson/claude-config/actions/workflows/commitlint.yml)

One [Claude Code](https://docs.anthropic.com/en/docs/claude-code) setup, versioned in Git and reproduced on every machine you work from. Instructions, settings, skills, agents and hooks live here; a single command puts them in place and keeps whatever is specific to that machine intact.

Runs on Linux, macOS and Windows. The sync engine is one Node script rather than one implementation per platform, and CI runs its test suite on all three.

## What's here

The repo mirrors the shape of `~/.claude`, so a directory here lands at the same path there.

`CLAUDE.md` carries the global instructions applied to every session, and `settings.json` is the shared base for permissions, hooks and the statusline. `skills/`, `agents/` and `commands/` hold the things Claude can invoke. `hooks/` holds shell scripts that Claude Code runs on session events. `scripts/` has the sync engine, first-time setup, and the checks CI runs.

For what any of those currently contain, read the directory. This file deliberately keeps no inventory, because an inventory in a README is a list that goes stale the moment anyone touches anything.

## Setup

```bash
git clone https://github.com/codywilliamson/claude-config.git ~/dev/claude-config

# Linux / macOS / WSL
bash ~/dev/claude-config/scripts/setup.sh

# Windows
~/dev/claude-config/scripts/setup.ps1
```

Setup detects your platform, checks prerequisites, writes a gitignored `.env.local`, and runs the first sync.

You need Git and Node. Node is not really an extra ask, since Claude Code installs through npm. The hooks additionally need `jq`, and the prompt-refinement hook wants `aspell`; without either, the affected hooks exit quietly instead of breaking your session.

## Syncing

```bash
./scripts/sync.sh status    # What differs, in both directions. Writes nothing
./scripts/sync.sh push      # repo -> ~/.claude
./scripts/sync.sh pull      # ~/.claude -> repo, then review with git diff
```

Use `scripts/sync.ps1` on Windows. Sitting down at another machine, `push --git` pulls the latest first, so one command gets you current.

Two things are worth knowing before you run it. Sync only ever touches entries the repo actually contains, so anything else in `~/.claude` — symlinked skills, one-machine-only skills, caches — is never deleted. And `settings.json` is generated rather than copied, by merging the repo's shared base with a gitignored `settings.local.json` that holds whatever is true of only that machine.

[**docs/sync.md**](docs/sync.md) covers the ownership rules, the merge semantics, and the tradeoffs.

## Safety

This repo runs shell scripts on your machine and feeds markdown into your model's context, so the checks target those two things rather than stopping at "it parses".

The sync engine has a test suite that mostly proves restraint: it does not delete symlinked skills, does not drop machine-only settings, and converges rather than accumulating when run repeatedly. It runs on all three platforms. Separately, every tracked file is scanned for invisible Unicode — payloads hidden in the Unicode Tag block render as nothing to a human reviewer but are still tokens to a model — along with prompt-injection phrasing, `curl | bash` patterns in the hooks, and permission settings that would pre-approve too much.

Every check is a dependency-free script in `scripts/`, so you can read it and run it yourself before trusting any of it.

[**docs/ci.md**](docs/ci.md) explains each check and why it exists.

## Statusline

`statusline-command.sh` renders the working directory, Git branch, active model, session cost and elapsed time, commits made today, and a context-usage bar. Segments that carry no information yet hide themselves, so a fresh session stays quiet. It needs a Nerd Font for the glyphs.

## Customizing

Fork it, rewrite `CLAUDE.md` in your own voice, add skills, agents and commands in their directories, then run `./scripts/sync.sh push`.

Keep `settings.json` portable — use `$HOME` rather than absolute paths, and put anything true of only one machine in `~/.claude/settings.local.json`, which sync never overwrites and Git never sees.

## Skills from elsewhere

Some skills in `~/.claude/skills` are symlinks into `~/.agents/skills` and are **not** managed by this repo. They come from [Matt Pocock's skills](https://github.com/mattpocock/skills), installed separately. Sync leaves them alone by design, which is the main reason it refuses to delete anything it does not own.

## Documentation

- [How syncing works](docs/sync.md)
- [What CI checks](docs/ci.md)
- [Hooks](docs/hooks.md)
