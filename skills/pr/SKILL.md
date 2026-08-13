---
name: pr
description: Use when creating a pull request, preparing a branch for review, or when the user says "pr" or "pull request"
---

# PR

Create a pull request from the current branch's commit history.

This skill owns the git and gh mechanics. The wording of the title and body is owned by the `writing-pr-descriptions` skill, so read that before writing either one. Do not use a section template here; that skill decides what the body contains based on the change.

## Workflow

### Step 1: Assess branch state

Run in parallel:

- `git status`, check for uncommitted changes
- `git log --oneline main..HEAD` (or the appropriate base branch), see all commits
- `git diff main..HEAD --stat`, see files changed
- Check if the branch is pushed to remote

### Step 2: Clean up

- Commit any uncommitted changes if relevant to the PR
- Push to remote with `-u` if needed

### Step 3: Analyze changes

Review every commit on the branch, not just the latest. You need the why behind the change, which usually is not in the diff. If the branch touches something risky or you made a judgment call that could have gone the other way, note it now so it lands in the body.

### Step 4: Create the PR

Follow `writing-pr-descriptions` for the title and body, then:

```bash
gh pr create --title "$TITLE" --body "$BODY"
```

Write `$BODY` to a temp file and pass `--body-file` instead when it contains backticks or `$`, since heredoc quoting gets ugly fast.

## Rules

- Never force push without asking
- Return the PR URL when done
