# claude-config

[![ci](https://github.com/codywilliamson/claude-config/actions/workflows/ci.yml/badge.svg)](https://github.com/codywilliamson/claude-config/actions/workflows/ci.yml)
[![security](https://github.com/codywilliamson/claude-config/actions/workflows/security.yml/badge.svg)](https://github.com/codywilliamson/claude-config/actions/workflows/security.yml)

portable [claude code](https://docs.anthropic.com/en/docs/claude-code) config — instructions, settings, commands, agents, hooks and skills, kept in one repo and synced onto every machine you work from.

runs on linux, macos and windows. the sync engine is a single node script rather than one implementation per platform, and CI runs the test suite on all three.

## layout

the repo mirrors the shape of `~/.claude`, so a directory here lands at the same path there:

- `CLAUDE.md` — global instructions applied to every session
- `settings.json` — the shared base for permissions, hooks and statusline
- `agents/`, `commands/`, `skills/` — things claude can invoke
- `hooks/` — shell scripts claude code runs on session events
- `scripts/` — sync engine, setup, and the checks CI runs

for what any of these currently contain, read the directory. this file deliberately doesn't keep an inventory, because an inventory in a README is a list that silently goes stale.

## setup

```bash
git clone https://github.com/codywilliamson/claude-config.git ~/dev/claude-config

# linux / macos / wsl
bash ~/dev/claude-config/scripts/setup.sh

# windows
~/dev/claude-config/scripts/setup.ps1
```

setup detects your platform, checks prerequisites, writes a gitignored `.env.local`, and runs the first sync.

you need git and node. node is not really an extra ask — claude code installs through npm, so it's already there. the prompt-refinement hook additionally wants `aspell` on your PATH and quietly does nothing without it.

## syncing

three commands, identical on every platform (`scripts/sync.ps1` on windows):

```bash
./scripts/sync.sh status    # what differs, in both directions. writes nothing
./scripts/sync.sh push      # repo -> ~/.claude
./scripts/sync.sh pull      # ~/.claude -> repo, then review with git diff
```

sitting down at another machine, `push --git` runs `git pull --ff-only` first so one command gets you current. `--dry-run` prints the plan without writing, and `--no-plugins` skips the plugin install pass.

### what sync will and won't touch

the repo owns named entries and nothing more. every top-level entry inside the mirrored directories is owned, along with the root config files. anything else living in `~/.claude` is never read, moved or deleted — that covers symlinked skills, skills you keep on one machine only, and every runtime and cache directory claude code maintains.

inside an owned entry it mirrors exactly, so renaming a file within a skill propagates instead of leaving the old copy behind. symlinks are skipped in both directions: they can't be clobbered on push, and they can't leak machine-specific paths into the repo on pull.

the flip side is worth knowing. deleting a skill from the repo does **not** delete it from `~/.claude` on your other machines, because a removed entry isn't owned anymore. remove those by hand.

### settings.json is generated, not copied

this is the part that makes multiple machines survivable. copying `settings.json` around means every sync wipes whatever the other machine had configured.

```
repo settings.json          shared base, committed
  +  settings.local.json    machine-only, gitignored, lives in ~/.claude
  =  ~/.claude/settings.json  generated on every push
```

objects merge deeply and local scalars win. hook arrays concatenate, so the repo's hooks and the machine's hooks both run rather than one replacing the other. the live file is rebuilt from base plus overlay every time instead of being patched in place, which is why pushing repeatedly is indistinguishable from pushing once.

the first push on a machine splits whatever is already in `settings.json` into the overlay for you. before writing, it checks that merging the split back reproduces everything you had; if anything would be lost it refuses and tells you where to look.

pull deliberately does not send settings back the other way. deciding which live key is shared and which is machine-only is exactly the guess that causes damage, so pull reports the drift and lets you place it yourself.

## what CI checks

cloning a config repo means letting someone else's shell scripts run on every prompt you type, and someone else's markdown into your model's context. that deserves more than a green check on "it parses", so the checks are built around the things that can actually hurt you.

**the sync engine can delete your files.** its test suite runs against throwaway home directories, and most of it tests restraint rather than function: a symlinked skill survives a push, a machine-only skill survives a push, a hook you deleted comes back instead of vanishing, and repeated pushes converge instead of accumulating. it runs on linux, macos and windows, because path handling and symlink support are precisely where a node script quietly stops being portable.

**markdown here becomes instructions.** the content scanner looks for invisible unicode, the failure mode human review cannot catch — a payload in the unicode tag block renders as nothing at all yet is still tokens to the model. when it finds one it decodes it, so the report shows what the hidden text actually said. it also flags zero-width characters, bidi overrides, instruction-override phrasing in anything loaded into context, and `curl | bash`-shaped patterns in the hooks. each rule runs only against the files that carry that risk, so nothing is exempt from its own check.

**settings.json decides what claude may do without asking.** the same scanner rejects a `bypassPermissions` default, allow rules that pre-approve a whole tool with no argument filter, and hook commands that aren't `$HOME`-relative.

the rest is ordinary hygiene: shellcheck over the shell, PSScriptAnalyzer over the powershell, frontmatter validated against claude code's real field lists, gitleaks across the full history, and [zizmor](https://docs.zizmor.sh) auditing the workflows themselves. actions are pinned to commit SHAs and every workflow starts from `permissions: {}`.

one check exists purely because this repo got it wrong: an unanchored `debug/` in `.gitignore` also matched `skills/debug/`, so that skill sat untracked and invisible to anyone cloning. CI now fails if a skill exists on disk without being tracked by git.

everything CI runs is a plain script in `scripts/` with no dependencies, so you can run the same checks locally and read what they do before trusting them.

### context budget

`node scripts/lint-skills.mjs` prints what this config costs you in context. skill names and descriptions load into the system prompt on **every** session whether or not the skill fires, while bodies load only on invocation — so a bloated description is a tax on every turn and a long body mostly isn't. the linter fails when a description exceeds the length at which claude code truncates the listing, and prints the current totals so you can see the trend rather than trusting a number written down here.

## customizing

fork it, rewrite `CLAUDE.md` in your own voice, then add skills, agents and commands in their directories and run `./scripts/sync.sh push`.

keep `settings.json` portable — use `$HOME` rather than absolute paths, and put anything true of only one machine in `~/.claude/settings.local.json`, which sync never overwrites and never commits.

## skills from elsewhere

some skills in `~/.claude/skills` are symlinks into `~/.agents/skills` and are **not** managed by this repo. they come from [matt pocock's skills](https://github.com/mattpocock/skills) — install those separately. sync leaves them alone by design, which is the main reason it refuses to delete anything it doesn't own.
