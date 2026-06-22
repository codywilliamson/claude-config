#!/usr/bin/env bash
# claude statusline — parse json without jq using bash builtins
# segments: dir · branch · model · cost · elapsed · commits today · context bar+mood
# portable: posix-ish bash, $HOME paths, lf line endings (see .gitattributes) — works in git bash on windows

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
cost=$(get_json "total_cost_usd")
dur_ms=$(get_json "total_duration_ms")

# nerd font glyphs
ICON_DIR=$''
ICON_BRANCH=$''
ICON_MODEL=$''
ICON_COST=$''
ICON_TIME=$''
ICON_COMMIT=$''
SEP=$''

# colors
RESET="\033[0m"
DIM="\033[2;37m"
BLUE="\033[1;34m"
CYAN="\033[0;36m"
MAGENTA="\033[0;35m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"

sep() { printf " ${DIM}${SEP}${RESET} "; }

# normalize backslashes to forward slashes (windows)
cwd=$(echo "$cwd" | tr '\\' '/' | sed 's|//\+|/|g')
home=$(echo "$HOME" | tr '\\' '/' | sed 's|//\+|/|g')

# shorten home prefix to ~, then truncate long paths
if [[ "$cwd" == "$home"* ]]; then
  display_dir="~${cwd#$home}"
else
  display_dir="${cwd:-(unknown)}"
fi

# ellipsis for deep paths — keep last 2 segments
stripped="${display_dir#\~/}"
stripped="${stripped#/}"
IFS='/' read -ra parts <<< "$stripped"
if [ "${#parts[@]}" -gt 2 ]; then
  display_dir="…/${parts[-2]}/${parts[-1]}"
fi

# git branch + commits made today (bounded, unlike LOC churn)
branch=""
commits_today=0
if [ -n "$cwd" ] && git -C "$cwd" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
  commits_today=$(git -C "$cwd" --no-optional-locks rev-list --count --since=midnight HEAD 2>/dev/null || echo 0)
fi

# format elapsed time from ms → 12s / 3m / 1h2m
fmt_elapsed() {
  local ms=$1 s
  s=$(( ms / 1000 ))
  if [ "$s" -lt 60 ]; then
    printf '%ds' "$s"
  elif [ "$s" -lt 3600 ]; then
    printf '%dm' "$(( s / 60 ))"
  else
    printf '%dh%dm' "$(( s / 3600 ))" "$(( (s % 3600) / 60 ))"
  fi
}

# mood emoji that heats up as the context window fills
ctx_mood() {
  local pct=$1
  if   [ "$pct" -ge 90 ]; then printf '🔥'
  elif [ "$pct" -ge 75 ]; then printf '😰'
  elif [ "$pct" -ge 60 ]; then printf '😅'
  elif [ "$pct" -ge 40 ]; then printf '🙂'
  else printf '😎'; fi
}

# 10-cell context bar, color-ramped by pressure
ctx_bar() {
  local pct=$1 filled i bar="" color
  filled=$(( (pct + 5) / 10 ))
  [ "$filled" -gt 10 ] && filled=10
  [ "$filled" -lt 0 ] && filled=0
  for ((i=0; i<10; i++)); do
    if [ "$i" -lt "$filled" ]; then bar+="▓"; else bar+="░"; fi
  done
  if [ "$pct" -ge 80 ]; then color="$RED"
  elif [ "$pct" -ge 50 ]; then color="$YELLOW"
  else color="$GREEN"; fi
  printf "${color}%s %d%%${RESET} %s" "$bar" "$pct" "$(ctx_mood "$pct")"
}

# build output
out=""
out+="${BLUE}${ICON_DIR} ${display_dir}${RESET}"

if [ -n "$branch" ]; then
  out+="$(sep)${CYAN}${ICON_BRANCH} ${branch}${RESET}"
fi

if [ -n "$model" ]; then
  out+="$(sep)${MAGENTA}${ICON_MODEL} ${model}${RESET}"
fi

# cost — only when we actually have a number
if [ -n "$cost" ]; then
  cost_fmt=$(printf '%.2f' "$cost" 2>/dev/null)
  [ -n "$cost_fmt" ] && out+="$(sep)${YELLOW}${ICON_COST} \$${cost_fmt}${RESET}"
fi

# elapsed
if [ -n "$dur_ms" ] && [ "$dur_ms" -gt 0 ] 2>/dev/null; then
  out+="$(sep)${DIM}${ICON_TIME} $(fmt_elapsed "$dur_ms")${RESET}"
fi

# commits today — only when non-zero
if [ "${commits_today:-0}" -gt 0 ] 2>/dev/null; then
  out+="$(sep)${GREEN}${ICON_COMMIT} ${commits_today}${RESET}"
fi

# context bar + mood
if [ -n "$used" ]; then
  out+="$(sep)$(ctx_bar "${used%.*}")"
fi

printf '%b\n' "$out"
