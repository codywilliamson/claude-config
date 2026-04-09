#!/bin/bash
# prompt refinement hook — detects messy/typo-heavy prompts
# and asks claude to interpret before acting. no api calls,
# just local aspell + heuristics.
# cross-platform: linux, macos, windows (git bash / msys2)

set -o pipefail 2>/dev/null || true

LOG_DIR="$HOME/.claude/logs"
LOG_FILE="$LOG_DIR/prompt-refine.log"
mkdir -p "$LOG_DIR" 2>/dev/null

# claude code passes hook input via stdin as json
INPUT=$(cat 2>/dev/null || true)
[ -z "$INPUT" ] && exit 0

PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null || true)

# skip empty or unparseable prompts
[ -z "$PROMPT" ] && exit 0

WORD_COUNT=$(echo "$PROMPT" | wc -w | tr -d ' ')
[ "${WORD_COUNT:-0}" -lt 6 ] && exit 0

# skip prompts that are mostly code (backticks, indentation)
CODE_LINES=$(echo "$PROMPT" | grep -cE '^\s{4,}|^```|^`' 2>/dev/null || echo 0)
TOTAL_LINES=$(echo "$PROMPT" | wc -l | tr -d ' ')
if [ "${TOTAL_LINES:-1}" -gt 0 ]; then
  CODE_RATIO=$(awk "BEGIN {printf \"%.2f\", ${CODE_LINES:-0} / ${TOTAL_LINES:-1}}")
  if awk "BEGIN {exit !($CODE_RATIO > 0.5)}"; then
    exit 0
  fi
fi

# check for aspell — skip refinement if not installed
if ! command -v aspell &>/dev/null; then
  {
    echo "--- $(date '+%Y-%m-%d %H:%M:%S') ---"
    echo "triggered: SKIP (aspell not found) | words: $WORD_COUNT"
    echo "prompt: $PROMPT"
    echo ""
  } >> "$LOG_FILE" 2>/dev/null
  exit 0
fi

MISSPELLED=$(echo "$PROMPT" | aspell list --lang=en 2>/dev/null | wc -l | tr -d ' ')

if [ "${WORD_COUNT:-0}" -gt 0 ]; then
  TYPO_RATIO=$(awk "BEGIN {printf \"%.2f\", ${MISSPELLED:-0} / $WORD_COUNT}")
else
  TYPO_RATIO="0.00"
fi

# threshold: >15% of words misspelled = messy prompt
NEEDS_REFINE=$(awk "BEGIN {print ($TYPO_RATIO > 0.15) ? 1 : 0}")

# get the misspelled words for the log
if command -v paste &>/dev/null; then
  MISSPELLED_WORDS=$(echo "$PROMPT" | aspell list --lang=en 2>/dev/null | sort -u | paste -sd, -)
else
  MISSPELLED_WORDS=$(echo "$PROMPT" | aspell list --lang=en 2>/dev/null | sort -u | tr '\n' ',' | sed 's/,$//')
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
TRIGGERED=$( [ "$NEEDS_REFINE" -eq 1 ] && echo "YES" || echo "no" )
{
  echo "--- $TIMESTAMP ---"
  echo "triggered: $TRIGGERED | words: $WORD_COUNT | misspelled: ${MISSPELLED:-0} ($TYPO_RATIO) | flagged: [$MISSPELLED_WORDS]"
  echo "prompt: $PROMPT"
  echo ""
} >> "$LOG_FILE" 2>/dev/null

if [ "$NEEDS_REFINE" -eq 1 ]; then
  cat <<'HOOK_MSG'
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "The user's prompt appears to contain typos or unclear wording. Before acting on the request, briefly restate what you understand the user is asking in a single clear sentence (prefixed with '> '), then proceed with the task. Do not ask for clarification unless the intent is truly ambiguous — just interpret and go."
  }
}
HOOK_MSG
fi

exit 0
