#!/bin/bash
# session changelog — logs a summary when claude stops
# cross-platform: linux, macos, windows (git bash / msys2)
# deduplicates by session_id so multiple stop events don't spam

LOG_DIR="$HOME/.claude/logs"
LOG_FILE="$LOG_DIR/session-changelog.log"
mkdir -p "$LOG_DIR" 2>/dev/null

INPUT=$(cat 2>/dev/null || true)
[ -z "$INPUT" ] && exit 0

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)

# deduplicate — skip if this session already logged
if [ -f "$LOG_FILE" ] && grep -q "session: ${SESSION_ID:0:12}" "$LOG_FILE" 2>/dev/null; then
  exit 0
fi

WORK_DIR="${CWD:-$(pwd)}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# git info (skip if not a repo)
BRANCH=""
CHANGED_FILES=""
UNCOMMITTED="0"
RECENT_COMMITS=""
if git -C "$WORK_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
  BRANCH=$(git -C "$WORK_DIR" branch --show-current 2>/dev/null || true)
  CHANGED_FILES=$(git -C "$WORK_DIR" diff --stat HEAD 2>/dev/null | tail -1 | tr -d ' ')
  UNCOMMITTED=$(git -C "$WORK_DIR" status --short 2>/dev/null | wc -l | tr -d ' ')
  RECENT_COMMITS=$(git -C "$WORK_DIR" log --oneline --since="1 hour ago" --author="$(git -C "$WORK_DIR" config user.name 2>/dev/null || true)" 2>/dev/null | head -5)
fi

{
  echo "--- $TIMESTAMP | session: ${SESSION_ID:0:12} ---"
  echo "dir: $WORK_DIR"
  [ -n "$BRANCH" ] && echo "branch: $BRANCH"
  [ -n "$CHANGED_FILES" ] && echo "uncommitted: $CHANGED_FILES"
  [ "${UNCOMMITTED:-0}" -gt 0 ] 2>/dev/null && echo "dirty files: $UNCOMMITTED"
  if [ -n "$RECENT_COMMITS" ]; then
    echo "commits:"
    echo "$RECENT_COMMITS" | sed 's/^/  /'
  fi
  echo ""
} >> "$LOG_FILE" 2>/dev/null

exit 0
