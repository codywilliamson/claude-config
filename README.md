# claude-config

portable [claude code](https://docs.anthropic.com/en/docs/claude-code) configuration — sync settings, commands, agents, hooks, skills, and statusline across machines.

```
…/dev/claude-config (master) Opus 4.6 ctx:16%
```

## what's in the box

| path | what it does |
|------|-------------|
| `CLAUDE.md` | global instructions loaded into every session — code style, git conventions, debugging workflow |
| `settings.json` | model, permissions, plugins, hooks, statusline config (uses `__CLAUDE_HOME__` placeholders) |
| `keybindings.json` | custom keyboard shortcuts |
| `statusline-command.sh` | bash script that renders a statusline with truncated path, git branch, model, and context usage |
| `commands/gac.md` | `/gac` slash command — analyzes all changes and creates conventional commits |
| `skills/deploy/` | `/deploy` — pre-deploy validation (typecheck, lint, test, build, push) |
| `skills/pr/` | `/pr` — creates well-structured pull requests from branch history |
| `agents/code-reviewer.md` | code review agent — design principles, bug detection, security |
| `agents/code-simplifier.md` | refactoring agent — DRY/KISS cleanup, comment pruning |
| `hooks/pre-commit-validate.sh` | pre-commit hook — blocks commits if typecheck/build fails (supports TS, Go, C#) |
| `scripts/sync.sh` | push config from repo to `~/.claude` (linux/mac/wsl) |
| `scripts/sync.ps1` | push config from repo to `~/.claude` (windows/powershell) |
| `scripts/pull.sh` | pull live config from `~/.claude` back into repo |

## statusline

the statusline script shows a compact info bar at the bottom of claude code:

```
…/dev/claude-config (master) Opus 4.6 ctx:16%
│                    │        │        └─ context window usage (yellow at 80%+)
│                    │        └─ current model
│                    └─ git branch
└─ truncated working directory
```

works on linux, mac, and windows (handles backslash paths). long paths are shortened with ellipsis — only the last 2 directory segments are shown.

## setup

### first time

```bash
# clone
git clone https://github.com/codywilliamson/claude-config.git ~/dev/claude-config

# sync to ~/.claude
# linux/mac/wsl:
bash ~/dev/claude-config/scripts/sync.sh

# windows (powershell):
~/dev/claude-config/scripts/sync.ps1
```

the sync script:
1. copies all config files to `~/.claude`
2. replaces `__CLAUDE_HOME__` placeholders with your actual path
3. fixes any hardcoded paths from other machines
4. installs plugins (if `claude` cli is available)

### updating

after making changes in `~/.claude` and want to capture them:

```bash
bash ~/dev/claude-config/scripts/pull.sh
# review changes, then commit
```

after pulling changes from the repo:

```bash
bash ~/dev/claude-config/scripts/sync.sh
```

## customizing

### fork and personalize

1. fork this repo
2. edit `CLAUDE.md` with your preferences
3. update `settings.json` — use `__CLAUDE_HOME__` for any paths
4. add your own commands in `commands/`, skills in `skills/`, agents in `agents/`
5. run the sync script

### path placeholders

`settings.json` uses `__CLAUDE_HOME__` wherever it references `~/.claude`. the sync scripts replace this with the actual path at install time, so the same config works across machines.

## structure

```
claude-config/
├── CLAUDE.md                  # global instructions
├── settings.json              # settings with __CLAUDE_HOME__ placeholders
├── keybindings.json           # keyboard shortcuts
├── statusline-command.sh      # statusline renderer
├── agents/
│   ├── code-reviewer.md       # code review agent
│   └── code-simplifier.md     # DRY/KISS refactoring agent
├── commands/
│   └── gac.md                 # /gac — git add & commit
├── hooks/
│   └── pre-commit-validate.sh # typecheck/build gate
├── skills/
│   ├── deploy/SKILL.md        # /deploy
│   └── pr/SKILL.md            # /pr
└── scripts/
    ├── sync.sh                # repo → ~/.claude (bash)
    ├── sync.ps1               # repo → ~/.claude (powershell)
    └── pull.sh                # ~/.claude → repo (bash)
```
