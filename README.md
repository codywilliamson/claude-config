# claude-config

portable [claude code](https://docs.anthropic.com/en/docs/claude-code) config — settings, commands, agents, hooks, and skills synced across machines.

```
…/dev/claude-config (master) Opus 4.6 ctx:16%
```

## what's in the box

| path | what it does |
|------|-------------|
| `CLAUDE.md` | global instructions — writing style, code style, git conventions, debugging workflow |
| `settings.json` | model, permissions, hooks, statusline config (uses `$HOME` for portability) |
| `keybindings.json` | keyboard shortcuts |
| `statusline-command.sh` | renders path, branch, model, session cost/time, commits today, and a context bar with mood emoji |
| `commands/gac.md` | `/gac` — analyzes changes and creates conventional commits |
| `skills/deploy/` | `/deploy` — pre-deploy validation (typecheck, lint, test, build, push) |
| `skills/pr/` | `/pr` — git and gh mechanics for opening a PR from branch history |
| `skills/writing-pr-descriptions/` | prose rules for PR titles and bodies (used by `/pr`) |
| `skills/writing-pr-comments/` | prose rules for code review comments |
| `skills/prompt-refine/` | `/prompt-refine` — audit prompt refinement hook log, tune heuristics |
| `skills/design-system/` | `/design-system` — curated UI design systems (stripe, supabase, resend, spotify) |
| `agents/code-reviewer.md` | code review agent — design principles, bug detection, security |
| `agents/code-simplifier.md` | refactoring agent — DRY/KISS cleanup, comment pruning |
| `hooks/prompt-refine.sh` | detects typo-heavy prompts via aspell and nudges claude to interpret before acting |
| `hooks/pre-commit-validate.sh` | blocks commits if typecheck/build fails (TS, Go, C#) |
| `hooks/file-size-watchdog.sh` | warns when writing files over 500 lines (1000 for markup/config) |
| `hooks/session-changelog.sh` | logs session summary (branch, commits, dirty files) on stop |
| `skills/debug/` | `/debug` — investigate before fixing, hypothesis-first debugging |
| `scripts/sync.mjs` | the sync engine — `status`, `push`, `pull`. one implementation, all platforms |
| `scripts/sync.sh` / `sync.ps1` | thin wrappers around `sync.mjs` |
| `scripts/setup.sh` | first-time setup — detects os, checks prerequisites, generates env, syncs (linux/mac/wsl) |
| `scripts/setup.ps1` | first-time setup (windows/powershell) |

## hooks

four hooks run automatically during claude code sessions:

| hook | event | what it does |
|------|-------|-------------|
| `prompt-refine.sh` | `UserPromptSubmit` | counts misspelled words via aspell; if >15% are typos, injects context asking claude to restate intent before acting. logs all evaluations to `~/.claude/logs/prompt-refine.log` |
| `pre-commit-validate.sh` | `PreToolUse` (Bash) | intercepts `git commit` commands and runs typecheck/lint/build first (TS, Go, C#) |
| `file-size-watchdog.sh` | `PreToolUse` (Write) | warns when a file exceeds 500 lines (1000 for html/markup/config). prompts for confirmation instead of blocking |
| `session-changelog.sh` | `Stop` | logs timestamp, branch, uncommitted changes, and recent commits to `~/.claude/logs/session-changelog.log`. deduplicates by session id |

logs live at `~/.claude/logs/`. use `/prompt-refine` to audit the prompt refinement log and tune thresholds.

## statusline

```
 …/dev/claude-config ❯  master ❯  Opus 4.8 ❯  $0.42 ❯  3m ❯  2 ❯ ▓▓▓▓▓▓░░░░ 62% 😅
 │                       │          │           │        │      │    │
 │                       │          │           │        │      │    └─ context bar (green→yellow→red) + mood emoji (😎🙂😅😰🔥)
 │                       │          │           │        │      └─ commits made today (hidden when 0)
 │                       │          │           │        └─ session elapsed time
 │                       │          │           └─ session cost in usd (hidden until reported)
 │                       │          └─ current model
 │                       └─ git branch
 └─ truncated working directory (last 2 segments)
```

requires a nerd font for the glyphs. data-bearing segments (cost, time, commits) hide themselves when empty/zero, so a fresh session stays clean.

## setup

### first time

```bash
git clone https://github.com/codywilliamson/claude-config.git ~/dev/claude-config

# linux/mac/wsl:
bash ~/dev/claude-config/scripts/setup.sh

# windows (powershell):
~/dev/claude-config/scripts/setup.ps1
```

setup detects your os, checks prerequisites, generates a `.env.local`, and runs the first sync.

### prerequisites

- **required:** git, node (claude code installs via npm, so you almost certainly have it)
- **recommended:** claude code cli, pnpm, aspell (for prompt refinement hook)

install aspell if you want the prompt refinement hook:
```bash
# linux (debian/ubuntu):
sudo apt install aspell aspell-en

# macos:
brew install aspell

# windows (msys2):
pacman -S mingw-w64-x86_64-aspell
```

## syncing

three commands, same on every platform (`sync.ps1` on windows):

```bash
./scripts/sync.sh status          # what differs, in both directions. changes nothing
./scripts/sync.sh push            # repo -> ~/.claude
./scripts/sync.sh pull            # ~/.claude -> repo, review with git diff
```

sitting down at another machine, `push --git` does a `git pull --ff-only` first:

```bash
./scripts/sync.sh push --git
```

add `--dry-run` to any of them to print the plan without writing. `--no-plugins` skips the plugin install pass.

### what sync will and won't touch

**the repo owns named entries, nothing more.** the manifest is the top-level entries the repo actually has: each file in `agents/`, `commands/`, `hooks/`, `skills/`, plus `CLAUDE.md`, `keybindings.json`, and `statusline-command.sh`. anything else living in `~/.claude` is never read, moved, or deleted. that includes symlinked skills, skills you keep on one machine only, and every runtime directory.

inside an owned entry sync mirrors exactly, so renaming a file inside `skills/pr/` propagates instead of leaving the old one behind. symlinks are skipped in both directions — they can't be clobbered on push and can't leak machine-specific paths into the repo on pull.

### settings.json is generated, not copied

this is the part that makes it work across machines. copying `settings.json` around means every sync wipes whatever that machine had.

```
repo/settings.json                shared base, committed
  +  ~/.claude/settings.local.json  machine-only, gitignored
  =  ~/.claude/settings.json        generated on every push
```

merge rules: objects merge deeply, local scalars win, and **hook arrays concatenate** so the repo's hooks and the machine's hooks both run. the live file is rebuilt from base + overlay every time rather than patched, so pushing ten times gives the same result as pushing once — hooks never accumulate.

the first push on a machine splits whatever is already in `settings.json` into the overlay for you, and verifies the split round-trips before writing anything. if it can't reproduce your current file exactly, it refuses and tells you.

pull deliberately does **not** push settings back. deciding which live key is shared and which is machine-only is exactly the guess that causes the damage, so pull reports drift and lets you place it yourself.

## customizing

1. fork this repo
2. edit `CLAUDE.md` with your preferences
3. update `settings.json` — paths use `$HOME` which resolves at runtime. machine-specific values belong in `~/.claude/settings.local.json` instead
4. add commands in `commands/`, skills in `skills/`, agents in `agents/`
5. run `./scripts/sync.sh push`

## skills from elsewhere

some of the skills in `~/.claude/skills` are symlinks into `~/.agents/skills` and are **not** managed by this repo — they come from [matt pocock's agent skills](https://github.com/mattpocock) (`codebase-design`, `diagnosing-bugs`, `domain-modeling`, `triage`, `to-spec`, `tdd`, `research`, `writing-for-agents`, and others). install them separately; sync leaves them alone by design.

## structure

```
claude-config/
├── CLAUDE.md
├── settings.json
├── keybindings.json
├── statusline-command.sh
├── agents/
│   ├── code-reviewer.md
│   └── code-simplifier.md
├── commands/
│   └── gac.md
├── hooks/
│   ├── file-size-watchdog.sh
│   ├── pre-commit-validate.sh
│   ├── prompt-refine.sh
│   └── session-changelog.sh
├── skills/
│   ├── debug/
│   ├── deploy/
│   ├── design-system/
│   ├── pr/
│   ├── prompt-refine/
│   ├── writing-pr-comments/
│   └── writing-pr-descriptions/
└── scripts/
    ├── sync.mjs            # the engine
    ├── sync.sh / sync.ps1  # wrappers
    └── setup.sh / setup.ps1
```
