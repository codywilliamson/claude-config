#!/usr/bin/env bash
# claude statusline — parse json without jq using bash builtins

input=$(cat)

# lightweight json value extraction (no jq needed)
get_json() {
  local key="$1"
  # match "key": "value" or "key": number
  echo "$input" | grep -o "\"$key\"[[:space:]]*:[[:space:]]*[\"0-9][^,}]*" | head -1 | sed 's/.*:[[:space:]]*"\{0,1\}//;s/"\{0,1\}[[:space:]]*$//'
}

cwd=$(get_json "current_dir")
model=$(get_json "display_name")
used=$(get_json "used_percentage")

# normalize backslashes to forward slashes (windows)
cwd="${cwd//\\//}"
home="${HOME//\\//}"

# shorten home prefix to ~, then truncate long paths
if [[ "$cwd" == "$home"* ]]; then
  display_dir="~${cwd#$home}"
else
  display_dir="${cwd:-(unknown)}"
fi

# ellipsis for deep paths — keep last 2 segments
IFS='/' read -ra parts <<< "$display_dir"
if [ "${#parts[@]}" -gt 3 ]; then
  display_dir="…/${parts[-2]}/${parts[-1]}"
fi

# git branch
branch=""
if [ -n "$cwd" ] && git -C "$cwd" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
fi

# build output
out=""
out+="\033[1;34m${display_dir}\033[0m"

if [ -n "$branch" ]; then
  out+=" \033[0;36m(${branch})\033[0m"
fi

if [ -n "$model" ]; then
  out+=" \033[0;35m${model}\033[0m"
fi

if [ -n "$used" ]; then
  used_int=${used%.*}
  if [ "${used_int:-0}" -ge 80 ]; then
    out+=" \033[0;33mctx:${used}%\033[0m"
  else
    out+=" \033[0;32mctx:${used}%\033[0m"
  fi
fi

printf '%b\n' "$out"
