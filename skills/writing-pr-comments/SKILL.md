---
name: writing-pr-comments
description: Write review comments on a pull request or diff. Use this whenever the user asks you to review a PR and leave comments, write review feedback, comment on a diff, or phrase a piece of code review feedback they're unsure how to word. Also use it when reviewing code as part of a larger workflow where the output is comments left on specific lines rather than a written report.
---

# Writing PR comments

A review comment is a quick message, not a document. Someone is going to read it on a phone between meetings and reply in a sentence. Anything that reads like a writeup gets skimmed, and a comment that gets skimmed did nothing.

## Lowercase, always

Every comment is lowercase regardless of length or severity. This is not a stylistic flourish, it sets the temperature of the thread. A capitalized, well-punctuated paragraph about someone's code reads as a formal finding, and formal findings get defensive replies. Lowercase reads as a colleague leaning over.

This holds even for the serious ones. Especially for the serious ones.

## Ask, don't assert

Default to a question. The reviewer almost always has less context than the author, so a question is the accurate form of the comment, not the polite one. You genuinely do not know whether `TrialEndsAt` is stored UTC. Asking gets you an answer; asserting gets you a correction and a slightly worse working relationship.

> is TrialEndsAt utc? DateTime.Now would put anything expiring in the last few hours of the day in the wrong bucket

A plain statement is fine when the thing is flatly true and you are not guessing.

> this catch swallows the exception and returns null, then line 88 dereferences it

Both are short. Neither has a preamble.

## Don't write the fix

Say what looks wrong and stop. The author knows the codebase, they will find a better fix than you would, and a proposed solution turns a ten second read into a paragraph they now have to evaluate and respond to. It also anchors them to your approach when theirs is probably better.

The one exception is a literal one-line change, where a GitHub suggestion block resolves in a click. That is faster than any reply. Anything longer than one line goes back to describing the problem.

Bad:

> Consider extracting this into a separate `TrialExpiryQuery` class and injecting an `IClock` so the date logic is testable. You could then...

Better:

> hard to test this with the date logic inline. worth pulling out?

## Length

One or two sentences is the norm. Most comments should land under 25 words.

Go longer only when the point is broader than a line: an architectural concern, a pattern repeating across files, something that needs context to even make sense as a question. Those are rare, and when you write one, it should be visibly different from the others, which is what tells the author it matters.

Never pad a short point to seem thorough.

## Formatting

None. No bold, no headers, no bullet lists, no emoji, no severity taxonomy.

The one label worth keeping is `nit:`, lowercase, because it is the only signal that saves the author real work. It tells them they can ignore this and you will not bring it up again. Everything else should be obvious from what the comment says: a comment describing data loss reads as urgent without being labeled urgent.

> nit: string concat here loses the structured logging

## One comment, one thing

Two concerns in one thread means the author replies to the first and the second disappears. Separate comments, separate lines, even when they are related.

## What not to comment on

Anything the linter or formatter owns. If it is not enforced and you keep bringing it up, write the rule instead of the comment.

Code the diff did not touch, unless it is genuinely dangerous, and then say it is pre-existing so the author knows it is not on them.

Anything that would not change what they do. A comment that exists to show you read the code is a tax on someone else's afternoon.

## Approving

An approval does not need a comment. When you leave one, say what you actually looked at.

> looked hard at the retry path and the timeout math, skimmed the fixtures

That tells the author exactly how much the approval is worth. "lgtm" does not.

## Examples

Same PR, seven comments, the whole review:

> is TrialEndsAt utc? DateTime.Now would put anything expiring in the last few hours of the day in the wrong bucket

> if ToListAsync throws, does anything restart this? looks like it'd fall out of ExecuteAsync and the service just goes quiet

> the 24h delay drifts by however long the loop takes, so the window slides later each day. does a deploy at the wrong time mean a cohort never gets queried?

> what stops this double-sending if a pod restarts mid-run?

> does TrialEndsAt get cleared when someone converts to paid? wondering if this emails people who already gave us money

> should ct go into SendAsync? on shutdown this walks the whole list first

> nit: string concat here loses the structured logging

Seven comments, roughly 110 words total. Every one is a question or a flat observation, none proposes a fix, none is capitalized, and the nit is visibly the nit.

## Before posting

1. Is every comment lowercase?
2. Would each one change what the author does? Cut the rest.
3. Any comment over two sentences? Justify it or cut it down.
4. Any comment proposing a fix longer than one line? Replace it with the problem.
5. Any formatting beyond `nit:` and a code reference? Remove it.
