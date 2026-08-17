#!/usr/bin/env bash
set -euo pipefail

# thin wrapper — all the logic lives in sync.mjs so there is one implementation
# to keep correct instead of one per platform.
#
#   ./scripts/sync.sh status          what differs, changes nothing
#   ./scripts/sync.sh push            repo -> ~/.claude
#   ./scripts/sync.sh pull            ~/.claude -> repo
#   ./scripts/sync.sh push --git      git pull first, then push
#   ./scripts/sync.sh push --dry-run  print the plan, write nothing

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v node >/dev/null 2>&1; then
  printf "\033[0;31m✗\033[0m node not found — required to run sync\n" >&2
  printf "  claude code installs via npm, so node is usually already present\n" >&2
  printf "  otherwise: https://nodejs.org\n" >&2
  exit 1
fi

exec node "$SCRIPT_DIR/sync.mjs" "$@"
