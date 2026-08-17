---
name: writing-technical-docs
description: Write or revise technical documentation — READMEs, architecture docs, runbooks, API docs, onboarding guides, design docs, explainers. Use this whenever the user asks you to document something, write a README, explain how a system works in written form, write a runbook or onboarding guide, or clean up docs that already exist. Also use it when they ask you to "write this up" for other engineers, or complain that a doc reads like a reference dump when they wanted a walkthrough.
---

# Writing technical docs

Most bad technical docs are a blend of two document types that should have stayed separate. An explanation with a config table stapled to the end. A reference page with a tutorial preamble. A runbook that pauses to explain architecture. The blend fails because the two halves want opposite shapes, and the reader is in exactly one mode at a time.

So the first decision is which of four documents you are writing, and the answer determines the format. Do not blend. If the material genuinely needs two, write two and link them.

## Pick the type first

**Explanation.** The reader wants to understand why the system is the way it is. This is narrative prose with a through-line, in the order someone actually hits the concepts. Headings are rare and only when the piece genuinely turns. No tables, no bullet inventories. This is the type most often written wrong as a reference dump, and when someone says "walk me through how X works," this is what they want.

**Tutorial.** The reader is learning by doing and has never done this before. Numbered steps, one path, no alternatives or asides. Every step ends in something the reader can see, so they know it worked. Never mention what else they could have done; that is what breaks tutorials.

**How-to.** The reader is competent and has a specific goal. State the goal in the first line, then the steps to reach it. Alternatives are fine here because the reader can evaluate them. Shorter and blunter than a tutorial.

**Reference.** The reader knows what they want and is looking it up. Tables, lists, exhaustive coverage, consistent structure per entry, no narrative. Optimize for scanning and for ctrl-F. Prose here is a defect.

When the request is ambiguous, explanation is the right default, because it is the type people ask for and receive least often.

## Headings name things, not positions

Every heading should name a task or a thing. "Introduction," "Overview," "Getting Started," "Conclusion," "Additional Notes," and "Miscellaneous" are position labels, and a reader scanning a table of contents learns nothing from them.

Bad: `## Overview` / `## Getting Started` / `## Advanced Usage`

Better: `## What the scheduler guarantees` / `## Running your first job` / `## Backfilling a failed window`

If a section genuinely has no nameable subject, it probably has no reason to exist.

## Code examples

Every example should be complete enough to paste and run. A snippet missing its imports, its config, or its surrounding function costs the reader more time than no snippet at all, because they now have to reconstruct the context you had and did not write down.

Show real values, not placeholders, wherever a real value is safe. `timeout: 30` teaches more than `timeout: <your-timeout>`.

Show one failure alongside the success. What the error looks like when it goes wrong is the part readers actually search for, and it is almost always missing.

Complete does not mean whole. Show the smallest fragment that carries the point, not the entire method it lives in. Pasting a 40 line handler to demonstrate a backoff calculation buries the four lines that matter, and the reader has to do the extraction you skipped. One example per concept. When a doc has more code than prose, it has quietly become a reference, and if reference is the right type then commit to it and drop the narrative.

## Say what breaks

A doc that only describes the happy path is a marketing page. The valuable content is the constraints: what this does not handle, where it degrades, what happens under concurrency, what the limits are, what you must not do.

Put those where they bite rather than in a "Limitations" section at the bottom that nobody reaches.

## Prerequisites

Only list a prerequisite that genuinely blocks. A list of eight prerequisites where two matter trains the reader to skip the list, and then they miss the two.

## Voice

Plain words, short clauses, varied sentence length. Break paragraphs more often than feels necessary; dense blocks are the failure mode in technical writing more than any word choice.

Never write a sentence whose only job is to announce or label another sentence. That rules out reframe openers ("the thing most people miss is"), topic labels ("Now, determinism."), retroactive pointers ("That's replay."), and previews ("One thing that bites people later"). Fold the transition into the sentence doing the work, or delete it and open the paragraph with its first real claim.

Avoid: em and en dashes, "not just X but Y" framing, triads built for rhythm, hedging filler ("it's worth noting", "importantly"), corporate vocab (leverage, robust, seamless, comprehensive, dive into, unpack), bold for emphasis, hype, and closing summary sections.

Second person for instructions ("you call", "run this"). Present tense. Active voice, so the reader knows who does what: "the scheduler retries the job" beats "the job is retried."

## Length

Answer what the doc is for and stop. Adjacent material appended out of a completeness reflex is what turns a walkthrough into a wall. When something real gets cut, link it or name it in one line rather than covering it.

An explanation should be readable in one sitting, which in practice means roughly 400 to 700 words. Past that, one of two things has happened: the doc is covering two subjects and should be split, or reference material has crept in and should be pulled into its own page and linked. Both are structural problems, and neither gets fixed by tightening sentences.

Tutorials and how-tos run as long as the task takes. Reference runs as long as the surface. Only explanation has a natural ceiling, and it is the type most likely to blow through it.

## Before delivering

1. Which of the four types is this? Does the format match, or did two types get blended?
2. Does every heading name a task or a thing?
3. Can every code example be pasted and run as written?
4. Is there at least one failure mode documented next to the thing that fails?
5. Any sentence whose only job is to introduce the next one?
6. Read the longest paragraph. Should it be two or three?
