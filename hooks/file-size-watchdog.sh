#!/bin/bash
# file size watchdog — warns when writing large files
# 500 lines for code, 1000 for markup/config/data
# cross-platform: linux, macos, windows (git bash / msys2)

INPUT=$(cat 2>/dev/null) || exit 0

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty' 2>/dev/null)

# skip if no file path or content
if [ -z "$FILE_PATH" ] || [ -z "$CONTENT" ]; then
  exit 0
fi

LINE_COUNT=$(echo "$CONTENT" | wc -l | tr -d ' ')

# determine threshold based on file extension
EXT="${FILE_PATH##*.}"
EXT=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')

case "$EXT" in
  html|htm|svg|xml|md|mdx|json|yaml|yml|css|scss|less|csv|sql|lock)
    THRESHOLD=1000
    FILE_TYPE="markup/config"
    ;;
  *)
    THRESHOLD=500
    FILE_TYPE="code"
    ;;
esac

if [ "$LINE_COUNT" -gt "$THRESHOLD" ]; then
  REASON="file is $LINE_COUNT lines ($FILE_TYPE threshold: $THRESHOLD). consider splitting — $(basename "$FILE_PATH")"
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "$REASON"
  }
}
EOF
  exit 0
fi

exit 0
