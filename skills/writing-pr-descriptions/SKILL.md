---
name: writing-pr-descriptions
description: Write a pull request description or title. Use this whenever the user asks you to write, draft, or improve a PR description, MR description, or PR title, or asks you to "write up this change" for review, or hands you a diff or branch and asks what to put in the PR body. Also use it when generating a PR description as part of a larger workflow such as opening a PR with gh.
---

# Writing PR descriptions

The reviewer has the diff. They do not need you to narrate it, and a description that lists what changed file by file is worse than an empty one, because it costs reading time and adds no information the diff lacks.

What the reviewer does not have is everything that lives in your head: why this change exists, what you considered and rejected, which part you are least sure about, and how to convince yourself it works. That is the entire job of the description.

## The four things

**Why this exists.** The problem, the bug, the request. One or two sentences. Link the ticket if there is one, but the description should still make sense to someone who does not open it.

**What to look at hardest.** Point the reviewer at the risky part. "The retry logic in `PaymentWorker.cs` is the part I'd want a second set of eyes on" saves more reviewer attention than any summary. If you rewrote something subtle, or made a call that could reasonably have gone the other way, say so and say why.

**How to verify.** The actual command, the actual scenario, the actual thing to click. Not "tested locally." A reviewer who can reproduce your verification in thirty seconds reviews differently than one who has to trust you.

**Risk and scope.** What could break, what is deliberately out of scope, whether it needs a migration, a flag, a specific deploy order, or a follow-up ticket. Anything that changes how this should be merged belongs here.

Not every PR needs all four. A one-line typo fix needs the first and nothing else. Use judgment, and let the risk of the change set the length.

## What to leave out

A file-by-file walkthrough. The diff is right there and it is more accurate than your summary.

A bulleted "Changes" list that restates commit messages. Same problem.

An opener that names the document ("This PR adds..."). Start with the content.

Checklists nobody fills in, emoji section headers, and template boilerplate carried over unedited. If your team's template has fields that do not apply, delete them rather than writing "N/A" six times.

Praise for your own change. "Significantly improves performance" is a claim for the verification section with a number attached, not an adjective.

## Title

One line, imperative mood, names the change and its object. Include the ticket key if the team uses them.

Bad: `Bug fixes and improvements`
Bad: `PROJ-441`
Better: `PROJ-441: key the login rate limiter on session, not request body`

The title should let someone scanning a merge log a year from now understand what happened.

## Example

Bad:

> This PR adds rate limiting.
>
> Changes:
> - Added RateLimiter.cs
> - Modified LoginController.cs
> - Updated appsettings.json
> - Added tests

Better:

> Login has no throttle, so credential stuffing against `/api/login` is currently free. This adds a fixed-window limiter at 5 attempts per minute.
>
> The key is the authenticated session where one exists and the source IP where it doesn't. That's the part worth a close look: keying on anything from the request body would let an attacker rotate the key and walk straight through.
>
> To verify: `dotnet test --filter RateLimit`, or hit `/api/login` six times with a bad password and check for a 429 on the sixth.
>
> Counter is in-process, so with more than one instance the effective limit is 5 per instance. Fine for now at one instance, tracked in PROJ-455 for the Redis-backed version before we scale out.

The second version is longer and saves the reviewer more time than it costs, because every sentence is something they cannot get from the diff.

## Voice

Plain words, short paragraphs, no bold for emphasis. Bullets only when the content is genuinely a list, which for a PR description is rare.

Never write a sentence whose only job is to announce or label another sentence.

Avoid: em and en dashes, "not just X but Y" framing, hedging filler, corporate vocab, hype, and closing summaries.
