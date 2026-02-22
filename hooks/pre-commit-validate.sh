#!/bin/bash
# pre-commit validation hook for claude code
# blocks git commits if type checking / linting fails

COMMAND=$(echo "$TOOL_INPUT" | jq -r '.command // empty')

# only run on git commit commands
if ! echo "$COMMAND" | grep -qE 'git\s+commit'; then
  exit 0
fi

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$REPO_ROOT" ]; then
  exit 0
fi

ERRORS=""

# typescript / javascript — prefer project scripts, fallback to tsc
if [ -f "$REPO_ROOT/tsconfig.json" ]; then
  if [ -f "$REPO_ROOT/package.json" ] && jq -e '.scripts.typecheck' "$REPO_ROOT/package.json" > /dev/null 2>&1; then
    echo "running typecheck script..." >&2
    OUTPUT=$(cd "$REPO_ROOT" && pnpm run typecheck 2>&1)
    if [ $? -ne 0 ]; then
      ERRORS="${ERRORS}typescript typecheck failed:\n${OUTPUT}\n\n"
    fi
  else
    echo "running tsc --noEmit..." >&2
    OUTPUT=$(cd "$REPO_ROOT" && npx tsc --noEmit --pretty 2>&1)
    if [ $? -ne 0 ]; then
      ERRORS="${ERRORS}typescript type check failed:\n${OUTPUT}\n\n"
    fi
  fi
fi

# go
if [ -f "$REPO_ROOT/go.mod" ]; then
  echo "running go vet..." >&2
  OUTPUT=$(cd "$REPO_ROOT" && go vet ./... 2>&1)
  if [ $? -ne 0 ]; then
    ERRORS="${ERRORS}go vet failed:\n${OUTPUT}\n\n"
  fi
fi

# c#
if compgen -G "$REPO_ROOT/*.sln" > /dev/null 2>&1 || compgen -G "$REPO_ROOT/**/*.csproj" > /dev/null 2>&1; then
  echo "running dotnet build..." >&2
  OUTPUT=$(cd "$REPO_ROOT" && dotnet build --no-restore --nologo -v quiet 2>&1)
  if [ $? -ne 0 ]; then
    ERRORS="${ERRORS}c# build failed:\n${OUTPUT}\n\n"
  fi
fi

if [ -n "$ERRORS" ]; then
  echo "pre-commit validation failed:" >&2
  echo -e "$ERRORS" >&2
  exit 1
fi

exit 0
