# How Syncing Works

The repo and `~/.claude` hold the same shape, and `scripts/sync.mjs` moves files between them. There is one implementation rather than one per platform, because the two things that break portability — path handling and symlink support — break quietly, and a second implementation just doubles the places they can hide.

```bash
./scripts/sync.sh status    # what differs, in both directions. Writes nothing
./scripts/sync.sh push      # repo -> ~/.claude
./scripts/sync.sh pull      # ~/.claude -> repo, then review with git diff
```

Use `scripts/sync.ps1` on Windows. Add `--git` to `push` to run `git pull --ff-only` first, `--dry-run` to print the plan without writing, and `--no-plugins` to skip the plugin install pass.

## The ownership rule

Sync owns named entries and nothing else. It builds that list from the repo side: every top-level entry inside the mirrored directories, plus the root config files. If the repo doesn't have it, sync doesn't know it exists.

That single rule is what makes the tool safe to run on a machine it has never seen. Symlinked skills, skills you keep on one machine only, and every runtime and cache directory Claude Code maintains are all invisible to it, so none of them can be deleted.

Inside an owned entry, it mirrors exactly. Renaming a file within a skill propagates rather than leaving the old copy behind, and a stale file that no longer exists in the repo is removed from that entry. The blast radius is the entry, never the directory above it.

Symlinks are skipped in both directions. On push they cannot be clobbered by a real directory; on pull they cannot leak a machine-specific absolute path into a repo that other machines will clone.

### The tradeoff

Deleting a skill from the repo does **not** delete it from `~/.claude` on your other machines. A removed entry is no longer owned, so sync stops considering it. `status` will not mention it either. Remove those by hand when you retire something.

This is the deliberate cost of never deleting what you did not ask about, and it is the right trade for a tool that writes into your home directory.

## settings.json is generated, not copied

Copying `settings.json` between machines is what made this painful before. Every sync overwrote whatever the other machine had configured — its local hooks, its model choice, its plugin set.

Now the live file is built from two pieces:

```
repo settings.json          Shared base, committed
  +  settings.local.json    Machine-only, gitignored, lives in ~/.claude
  =  ~/.claude/settings.json  Generated on every push
```

Objects merge deeply and local scalars win. Hook arrays concatenate, so the repo's hooks and the machine's hooks both run instead of one silently replacing the other.

The live file is rebuilt from base plus overlay every time rather than patched in place. That is why running `push` ten times is indistinguishable from running it once — there is no accumulated state to drift.

### The first push on a new machine

Your machine already has a `settings.json` before sync ever runs. The first push splits it: anything the repo's base does not explain becomes your overlay.

Before writing, it checks that merging the split back preserves everything you had. The check is coverage, not equality — the merged result is allowed to contain *more* than you started with, since gaining the repo's hooks is the point, but it may never contain less. If anything would be lost it refuses and tells you where to look.

### Why pull leaves settings alone

Pull does not send settings back to the repo. Deciding which live key is shared and which is machine-only is exactly the guess that caused the original damage, so it reports the drift and lets you place each key yourself.

Put anything true of only one machine in `~/.claude/settings.local.json`. Sync never overwrites it and git never sees it.

## Adding a new machine

```bash
git clone https://github.com/codywilliamson/claude-config.git ~/dev/claude-config
bash ~/dev/claude-config/scripts/setup.sh    # or scripts/setup.ps1 on Windows
```

After that, `./scripts/sync.sh push --git` is the whole routine: pull the latest config, apply it, keep your local overrides.

See [ci.md](ci.md) for the checks that keep this trustworthy.
