---
name: pr
description: Use when creating a pull request, preparing a branch for review, or when the user says "pr" or "pull request"
---

# PR

Create a well-structured pull request from the current branch's commit history.

## Workflow

### Step 1: Assess Branch State

Run in parallel:
- `git status` — check for uncommitted changes
- `git log --oneline main..HEAD` (or appropriate base branch) — see all commits
- `git diff main..HEAD --stat` — see files changed
- Check if branch is pushed to remote

### Step 2: Clean Up

- Commit any uncommitted changes if relevant to the PR
- Push to remote with `-u` if needed

### Step 3: Analyze Changes

Review ALL commits on the branch (not just the latest). Understand:
- What was added/changed/fixed
- Why the changes were made
- What areas of the codebase are affected

### Step 4: Create PR

```bash
gh pr create --title "short title under 70 chars" --body "$(cat <<'EOF'
## Summary
- bullet points covering what and why

## Changes
- key changes grouped logically

## Test plan
- [ ] how to verify this works
EOF
)"
```

## Rules

- Title: short, imperative, under 70 chars
- Body: focus on **why**, not **what** (the diff shows what)
- Always include a test plan
- Never force push without asking
- Return the PR URL when done
