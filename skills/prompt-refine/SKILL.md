---
name: prompt-refine
description: Audit the prompt refinement hook log — review trigger history, analyze false positives/negatives, and tune heuristics
---

# Prompt Refine Audit

Audit and tune the `UserPromptSubmit` prompt-refine hook.

## Files

- **Log:** `~/.claude/logs/prompt-refine.log`
- **Hook:** `~/.claude/hooks/prompt-refine.sh` (active)
- **Source:** `~/dev/claude-config/hooks/prompt-refine.sh` (repo)

## Workflow

### Step 1: Read the log

Read `~/.claude/logs/prompt-refine.log`. If it doesn't exist or is empty, tell the user no prompts have been evaluated yet.

### Step 2: Summarize

Present a summary table:

| Metric | Value |
|--------|-------|
| Total prompts evaluated | count of `---` entries |
| Triggered (YES) | count |
| Not triggered (no) | count |
| Skipped (aspell missing) | count |
| Trigger rate | percentage |
| Current threshold | read from hook script (the `0.15` value on the `NEEDS_REFINE` line) |

### Step 3: Flag issues

Scan for these problems:

**False positives** (triggered but shouldn't have):
- Triggered entries where most "misspelled" words are proper nouns, tech terms, or common informal words (e.g., `dont`, `bc`, `im`, `hm`, `ok`, `wanna`, `gonna`, `repo`, `env`, `config`, `api`, `cli`, `pr`, `ui`, `ux`, `db`, `ts`, `js`, `css`, `html`, `json`, `yaml`, `npm`, `pnpm`, `vps`, `ssh`, `mcp`, `lsp`)
- Entries where the prompt is clearly understandable despite typo count

**False negatives** (didn't trigger but should have):
- Non-triggered entries where the prompt text has obvious garbled words or unclear intent

**aspell gaps:**
- Any `SKIP (aspell not found)` entries — means aspell isn't installed on that machine

### Step 4: Recommend fixes

Based on the analysis, suggest concrete changes:

- **Threshold too low (too many false positives):** suggest raising the `0.15` value
- **Threshold too high (missing messy prompts):** suggest lowering it
- **Tech terms triggering aspell:** suggest adding a personal wordlist at `~/.aspell.en.pws` with commonly flagged terms. Generate the wordlist content based on the most frequently flagged non-typo words in the log.
- **aspell missing:** provide install command for the detected platform:
  - Linux: `sudo apt install aspell aspell-en` or `sudo dnf install aspell aspell-en`
  - macOS: `brew install aspell`
  - Windows: `pacman -S mingw-w64-x86_64-aspell` (MSYS2) or note Git Bash limitation

### Step 5: Apply fixes (only if user approves)

If the user wants changes applied:

1. Edit the threshold in `~/dev/claude-config/hooks/prompt-refine.sh` (the source)
2. Write/update `~/.aspell.en.pws` if adding a personal wordlist (format below)
3. Copy the updated hook to `~/.claude/hooks/prompt-refine.sh`
4. Confirm changes with a quick test: run the hook against a sample messy and clean prompt

**aspell personal wordlist format** (`~/.aspell.en.pws`):
```
personal_ws-1.1 en 0
dont
bc
im
api
cli
```

## Rules

- Never delete or truncate the log without asking
- Show actual log entries when discussing false positives/negatives so the user can judge
- Always edit the source file in `~/dev/claude-config/` first, then copy to `~/.claude/`
- When changing the threshold, explain the tradeoff (sensitivity vs noise)
- If the log is very large (>500 entries), summarize and show only the most recent 20 + any flagged issues
