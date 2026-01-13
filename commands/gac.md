---
allowed-tools: Bash(git add:*), Bash(git commit:*), Bash(git status:*), Bash(git diff:*), Bash(git log:*)
argument-hint: [optional custom instructions]
description: Git Add & Commit - analyze all changes and create comprehensive commit message
---

## Current Git State

**Status:**
!`git status`

**All Changes (staged and unstaged):**
!`git diff HEAD`

**Recent Commits (for style reference):**
!`git log -5 --oneline`

## Your Task

Analyze the changes shown above and create a comprehensive git commit following this workflow:

1. **Analyze changes thoroughly:**
   - Review all modified files and their diffs
   - Identify the primary purpose (feat, fix, refactor, chore, docs, style, test, perf)
   - Group changes into logical themes

2. **Create a structured commit message using this format:**
   ```
   <type>: <summary in imperative mood>

   - <detail 1>
   - <detail 2>
   - <detail 3>

   Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
   ```

3. **Commit format guidelines:**
   - **Type:** feat | fix | refactor | chore | docs | style | test | perf
   - **Summary:** Brief, imperative mood (50 chars max)
   - **Details:** Bullet points explaining what/why (not how)
   - Use `-` prefix for bullet points
   - Skip details for trivial changes
   - Be specific about files/features affected

4. **Example format:**
   ```
   feat: implement WordPress publishing with job queue

   - Add WordPress REST API client with auth
   - Create background job processor for scheduled posts
   - Add publish job admin UI and status tracking
   - Update content workflow to support WP integration

   Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
   ```

5. **Execute the commit:**
   - Add all relevant untracked files: `git add <files>`
   - Commit using HEREDOC format: `git commit -m "$(cat <<'EOF' ...)"`
   - Run `git status` after to verify

6. **Additional considerations:**
   - $ARGUMENTS (if provided, use as additional context or instructions for the commit message)
   - Do not commit files that likely contain secrets (.env, credentials.json, etc.)
   - Warn if such files are staged

7. **After committing:**
   - Show a summary of what was committed
   - Display the final git status
