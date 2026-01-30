#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCE_DIR="$REPO_ROOT"
TARGET_DIR="${CLAUDE_HOME:-$HOME/.claude}"

mkdir -p "$TARGET_DIR"

rsync -a \
  --exclude ".git/" \
  --exclude "scripts/" \
  --exclude ".credentials.json" \
  --exclude "history.jsonl" \
  --exclude "stats-cache.json" \
  --exclude "cache/" \
  --exclude "debug/" \
  --exclude "downloads/" \
  --exclude "file-history/" \
  --exclude "paste-cache/" \
  --exclude "plans/" \
  --exclude "projects/" \
  --exclude "session-env/" \
  --exclude "shell-snapshots/" \
  --exclude "statsig/" \
  --exclude "telemetry/" \
  --exclude "todos/" \
  --exclude "ide/" \
  "$SOURCE_DIR/" "$TARGET_DIR/"

echo "Synced $SOURCE_DIR -> $TARGET_DIR"
