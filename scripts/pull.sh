#!/usr/bin/env bash
set -euo pipefail

# pull live claude config into this repo for committing
# opposite of sync.sh — captures current state from ~/.claude

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SOURCE_DIR="${CLAUDE_HOME:-$HOME/.claude}"

# --- helpers ---
info()  { printf "\033[0;34m→\033[0m %s\n" "$1"; }
ok()    { printf "\033[0;32m✓\033[0m %s\n" "$1"; }
warn()  { printf "\033[0;33m!\033[0m %s\n" "$1"; }

if [ ! -d "$SOURCE_DIR" ]; then
  warn "no claude config found at $SOURCE_DIR"
  exit 1
fi

# --- files to pull ---
FILES=(CLAUDE.md settings.json keybindings.json statusline-command.sh)
DIRS=(agents commands hooks skills)

# --- pull individual files ---
for file in "${FILES[@]}"; do
  src="$SOURCE_DIR/$file"
  if [ -f "$src" ]; then
    cp "$src" "$REPO_DIR/$file"
    ok "pulled $file"
  else
    warn "skipping $file (not found)"
  fi
done

# --- pull directories ---
for dir in "${DIRS[@]}"; do
  src="$SOURCE_DIR/$dir"
  if [ -d "$src" ]; then
    mkdir -p "$REPO_DIR/$dir"
    rsync -a --delete "$src/" "$REPO_DIR/$dir/"
    ok "pulled $dir/"
  else
    warn "skipping $dir/ (not found)"
  fi
done

# --- replace machine-specific paths with placeholders in settings.json ---
if [ -f "$REPO_DIR/settings.json" ]; then
  sed -i "s|$SOURCE_DIR|__CLAUDE_HOME__|g" "$REPO_DIR/settings.json"
  # catch other home dir patterns too
  sed -i "s|/home/[^/]*/\.claude|__CLAUDE_HOME__|g" "$REPO_DIR/settings.json"
  sed -i "s|/Users/[^/]*/\.claude|__CLAUDE_HOME__|g" "$REPO_DIR/settings.json"
  ok "replaced paths with __CLAUDE_HOME__ placeholders"
fi

echo ""
ok "pulled live config into $REPO_DIR"
info "review changes with: git -C $REPO_DIR diff"
