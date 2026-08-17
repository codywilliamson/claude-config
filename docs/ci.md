# What CI Checks

Cloning a config repo means letting someone else's shell scripts run on every prompt you type, and someone else's markdown into your model's context. That deserves more than a green check on "it parses".

Every check is a plain script in `scripts/` with no dependencies. You can read them and run them locally before trusting any of it:

```bash
node scripts/test-sync.mjs      # the sync engine's behaviour
node scripts/lint-skills.mjs    # frontmatter and context cost
node scripts/scan-content.mjs   # injection, shell patterns, permissions
```

## The sync engine can delete your files

This gets the most coverage, because it is the only thing here that writes into your home directory.

The suite runs against throwaway home directories, and most of it tests restraint rather than function. A symlinked skill survives a push. A skill you keep on one machine survives a push. A hook you deleted comes back instead of vanishing. Repeated pushes converge instead of accumulating hooks. A settings key the repo's base does not define is preserved rather than dropped.

It runs on Linux, macOS and Windows. That matrix is not ceremony — the first time it ran, it caught two Windows-only failures that the Linux job passed clean. Where a runner cannot create symlinks, that test skips itself and says so rather than reporting a false pass.

## Markdown here becomes instructions

`scan-content.mjs` looks for invisible Unicode, which is the failure mode human review cannot catch. A payload in the Unicode Tag block (`U+E0000`–`U+E007F`) renders as nothing at all in every editor and diff viewer, yet is still a distinct sequence of tokens to the model. Zero-width characters and bidirectional overrides work the same way.

When the scanner finds tag-block characters it decodes them, so a finding reports what the hidden text actually said instead of just flagging that something is there.

It also looks for instruction-override phrasing in anything loaded into a model's context, and for `curl | bash`-shaped patterns in the shell that Claude Code executes on session events.

Each rule runs only against the files that carry that risk. Shell patterns are checked in shell scripts, injection phrasing in the markdown that reaches a model, invisible Unicode everywhere. Because the scoping is by risk rather than by exception list, no file is exempt from its own rules.

Background reading: [Hidden Unicode instructions in agent skills](https://embracethered.com/blog/posts/2026/scary-agent-skills/) and the [CSA research note on Unicode instruction injection](https://labs.cloudsecurityalliance.org/research/csa-research-note-unicode-instruction-injection-ai-skills-20/).

## settings.json decides what runs without asking

The same scanner enforces policy on the permission surface. It rejects a `bypassPermissions` default, allow rules that pre-approve an entire tool with no argument filter, and hook commands that are not `$HOME`-relative — an absolute path in a shared config is either broken on the next machine or pointing somewhere it should not.

## Skills and agents

`lint-skills.mjs` validates frontmatter against Claude Code's real field lists. Skills and agents have genuinely different schemas: `color` is valid on an agent and not on a skill, agents take `tools` where skills take `allowed-tools`. An unknown key is almost always a typo, and it fails silently at runtime rather than erroring, so it is worth catching here.

### Context budget

The same script reports what this config costs you in context.

Skill names and descriptions load into the system prompt on **every** session, whether or not the skill ever fires. Bodies load only on invocation. So a bloated description is a tax on every single turn, while a long body mostly is not — which is the argument for moving reference material out of a skill body into files it can read on demand.

The linter fails when a description exceeds the length at which Claude Code truncates the listing, and prints current totals so you can watch the trend rather than trusting a number written down somewhere.

## Everything else

Shellcheck over the shell scripts, PSScriptAnalyzer over the PowerShell, gitleaks across the full history, and [zizmor](https://docs.zizmor.sh) auditing the workflows themselves at its pedantic setting. Commit messages are linted against Conventional Commits by [commit-guard](https://github.com/codywilliamson/commit-guard).

Every action is pinned to a commit SHA with its version in a trailing comment, and every workflow starts from `permissions: {}` so each job has to ask for what it needs. Pinning means an upstream tag cannot be moved under you; the cost is that updates become explicit, which is the point.

One check exists purely because this repo got it wrong. An unanchored `debug/` in `.gitignore` also matched `skills/debug/`, so that skill sat untracked and invisible to anyone cloning while working perfectly on the machine that wrote it. CI now fails if a skill exists on disk without being tracked by git.

## What is deliberately not here

Dependency and container scanning. There is no dependency tree to scan — no lockfile, no `package.json`, no images — and secret scanning is already covered by gitleaks. Adding a vulnerability scanner would spend minutes to confirm that an empty set is still empty.

The real attack surface here is prompt injection and hook execution, which is what the checks above target.
