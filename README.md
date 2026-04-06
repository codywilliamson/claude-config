# claude-config

portable [claude code](https://docs.anthropic.com/en/docs/claude-code) config — settings, commands, agents, hooks, and skills synced across machines.

```
…/dev/claude-config (master) Opus 4.6 ctx:16%
```

## what's in the box

| path | what it does |
|------|-------------|
| `CLAUDE.md` | global instructions — code style, git conventions, debugging workflow |
| `settings.json` | model, permissions, hooks, statusline config (uses `__CLAUDE_HOME__` placeholders) |
| `keybindings.json` | keyboard shortcuts |
| `statusline-command.sh` | renders path, git branch, model, and context usage in the statusline |
| `commands/gac.md` | `/gac` — analyzes changes and creates conventional commits |
| `skills/deploy/` | `/deploy` — pre-deploy validation (typecheck, lint, test, build, push) |
| `skills/pr/` | `/pr` — creates well-structured pull requests from branch history |
| `skills/wiki/` | `/wiki` — persistent knowledge base using the karpathy llm wiki pattern |
| `skills/design-system/` | `/design-system` — curated UI design systems (stripe, supabase, resend, spotify) |
| `agents/code-reviewer.md` | code review agent — design principles, bug detection, security |
| `agents/code-simplifier.md` | refactoring agent — DRY/KISS cleanup, comment pruning |
| `hooks/pre-commit-validate.sh` | blocks commits if typecheck/build fails (TS, Go, C#) |
| `scripts/setup.sh` | first-time setup — detects os, finds obsidian vault, generates env, syncs (linux/mac/wsl) |
| `scripts/setup.ps1` | first-time setup (windows/powershell) |
| `scripts/sync.sh` | push config from repo to `~/.claude` (linux/mac/wsl) |
| `scripts/sync.ps1` | push config from repo to `~/.claude` (windows/powershell) |
| `scripts/pull.sh` | pull live config from `~/.claude` back into repo |

## statusline

```
…/dev/claude-config (master) Opus 4.6 ctx:16%
│                    │        │        └─ context window usage (yellow at 80%+)
│                    │        └─ current model
│                    └─ git branch
└─ truncated working directory (last 2 segments)
```

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
3. update `settings.json` — use `__CLAUDE_HOME__` for any paths
4. add commands in `commands/`, skills in `skills/`, agents in `agents/`
5. run `sync.sh`

`settings.json` uses `__CLAUDE_HOME__` wherever it references `~/.claude` — sync scripts replace this with your actual path at install time.

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
│   └── pre-commit-validate.sh
├── skills/
│   ├── deploy/
│   ├── design-system/
│   ├── pr/
│   └── wiki/
└── scripts/
    ├── setup.sh / setup.ps1
    ├── sync.sh / sync.ps1
    └── pull.sh
```
