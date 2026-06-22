# claude-config

portable [claude code](https://docs.anthropic.com/en/docs/claude-code) config — settings, commands, agents, hooks, and skills synced across machines.

```
…/dev/claude-config (master) Opus 4.6 ctx:16%
```

## what's in the box

| path | what it does |
|------|-------------|
| `CLAUDE.md` | global instructions — code style, git conventions, debugging workflow |
| `settings.json` | model, permissions, hooks, statusline config (uses `$HOME` for portability) |
| `keybindings.json` | keyboard shortcuts |
| `statusline-command.sh` | renders path, branch, model, session cost/time, commits today, and a context bar with mood emoji |
| `commands/gac.md` | `/gac` — analyzes changes and creates conventional commits |
| `skills/deploy/` | `/deploy` — pre-deploy validation (typecheck, lint, test, build, push) |
| `skills/pr/` | `/pr` — creates well-structured pull requests from branch history |
| `skills/prompt-refine/` | `/prompt-refine` — audit prompt refinement hook log, tune heuristics |
| `skills/wiki/` | `/wiki` — persistent knowledge base using the karpathy llm wiki pattern |
| `skills/design-system/` | `/design-system` — curated UI design systems (stripe, supabase, resend, spotify) |
| `agents/code-reviewer.md` | code review agent — design principles, bug detection, security |
| `agents/code-simplifier.md` | refactoring agent — DRY/KISS cleanup, comment pruning |
| `hooks/prompt-refine.sh` | detects typo-heavy prompts via aspell and nudges claude to interpret before acting |
| `hooks/pre-commit-validate.sh` | blocks commits if typecheck/build fails (TS, Go, C#) |
| `hooks/file-size-watchdog.sh` | warns when writing files over 500 lines (1000 for markup/config) |
| `hooks/session-changelog.sh` | logs session summary (branch, commits, dirty files) on stop |
| `scripts/setup.sh` | first-time setup — detects os, finds obsidian vault, generates env, syncs (linux/mac/wsl) |
| `scripts/setup.ps1` | first-time setup (windows/powershell) |
| `scripts/sync.sh` | push config from repo to `~/.claude` (linux/mac/wsl) |
| `scripts/sync.ps1` | push config from repo to `~/.claude` (windows/powershell) |
| `scripts/pull.sh` | pull live config from `~/.claude` back into repo |

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

setup detects your os, finds your obsidian vault (for the wiki skill), generates a `.env.local`, and runs the first sync.

### prerequisites

- **required:** git, claude code cli
- **recommended:** node, pnpm, rsync (linux/mac), aspell (for prompt refinement hook)

install aspell if you want the prompt refinement hook:
```bash
# linux (debian/ubuntu):
sudo apt install aspell aspell-en

# macos:
brew install aspell

# windows (msys2):
pacman -S mingw-w64-x86_64-aspell
```

### updating

```bash
# capture changes from ~/.claude back into the repo:
bash ~/dev/claude-config/scripts/pull.sh

# apply repo changes to ~/.claude:
bash ~/dev/claude-config/scripts/sync.sh
```

## customizing

1. fork this repo
2. edit `CLAUDE.md` with your preferences
3. update `settings.json` — paths use `$HOME` which bash resolves at runtime
4. add commands in `commands/`, skills in `skills/`, agents in `agents/`
5. run `sync.sh`

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
│   ├── deploy/
│   ├── design-system/
│   ├── pr/
│   ├── prompt-refine/
│   └── wiki/
└── scripts/
    ├── setup.sh / setup.ps1
    ├── sync.sh / sync.ps1
    └── pull.sh
```
