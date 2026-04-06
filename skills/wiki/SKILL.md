---
name: wiki
description: Use whenever the user mentions knowledge base, wiki, notes, research, learning, collecting information, or wants to save/organize information they've found. Also use when user asks to "add to wiki", "search my notes", "what do my notes say", "explore connections", "find contradictions", or any operation that manages persistent knowledge across sessions. This is your persistent memory layer.
version: 1.0.0
---

# LLM Wiki Skill

A persistent, compounding knowledge base system based on Andrej Karpathy's "LLM Wiki" pattern. This skill maintains a vault of concept articles, entity profiles, and synthesis pieces that grow across sessions while staying cleanly separated from hand-written notes.

## Configuration

Set `WIKI_VAULT_PATH` in your project or global CLAUDE.md to point to your Obsidian vault:

```
WIKI_VAULT_PATH=~/dev/notes/ShockBirds Vault
```

If not set, look for an Obsidian vault (a directory containing `.obsidian/`) in common locations: `~/notes/`, `~/Documents/`, `~/dev/notes/`. Ask the user if none found.

## Overview

The wiki is an Obsidian vault subdirectory at:
```
$WIKI_VAULT_PATH/wiki/
├── index.md           # Content-oriented catalog
├── log.md             # Chronological operation log
├── schema.md          # Conventions and taxonomy
├── raw/               # Immutable source material (user-added)
└── [topic pages]      # LLM-generated concept articles
```

The vault may already have its own folder structure (e.g. `_inbox/`, `projects/`, `research/`, etc.) — the wiki/ subfolder keeps LLM-managed content cleanly separated.

## Core Concepts

**Three layers:**
1. **raw/** — Immutable source material. User adds URLs, PDFs, articles, pasted text here. Files named like `source-name.md` or `2026-04-05-topic.md`.
2. **wiki/** — LLM-generated markdown pages with Obsidian wikilinks `[[Page Name]]`, tags in frontmatter, and YAML metadata. One concept per page, ~200-500 words.
3. **SKILL.md** — This file documents conventions and the schema.

**Key design:**
- Use Obsidian wikilinks `[[Page Name]]` not markdown links — essential for graph view
- Every wiki page has YAML frontmatter with `created`, `updated`, `tags`, `sources`, `related`
- Pages are focused — one concept per page, cross-reference aggressively
- User's existing vault folders (projects/, developer/, work/, etc.) are READ-ONLY — reference via wikilinks, never write to them
- wiki/ folder is the LLM's exclusive domain

## Page Format

Every wiki page (except index.md, log.md, schema.md) starts with frontmatter:

```yaml
---
created: 2026-04-05
updated: 2026-04-05
tags: [concept, typescript, architecture]
sources: ["[[raw/source-name]]"]
related: ["[[Other Page]]", "[[Another Page]]"]
---

# Page Title

Content starts here...
```

**Frontmatter fields:**
- `created` — ISO date of creation (immutable)
- `updated` — ISO date of last update
- `tags` — array of strings for Obsidian filtering (lowercase, hyphenated)
- `sources` — array of wikilinks to raw/ pages that informed this page
- `related` — array of wikilinks to other wiki pages for navigation

## Core Operations

### 1. Ingest (`/wiki ingest` or "add this to my wiki")

Process new sources from raw/ folder or direct input (URLs, text, PDFs). Create or update 5-15 wiki pages depending on richness.

**Steps:**
1. If user provides a source directly (URL, text, PDF path), save it to `raw/` with descriptive name. If already in raw/, use it.
2. Read the source material thoroughly.
3. Extract 5-15 core concepts, entities, relationships, and facts.
4. For each concept, create a wiki page (or update existing if it covers the same concept).
5. Use wikilinks `[[Concept Name]]` to cross-reference between pages and sources.
6. Add entry to `log.md` with format: `## [2026-04-05] ingest | Source Title`
7. Update `index.md` if new categories or pages warrant inclusion.
8. Confirm with user: list the pages created/updated and key concepts extracted.

**Example page from URL ingest:**

Create `wiki/reactive-programming.md`:
```yaml
---
created: 2026-04-05
updated: 2026-04-05
tags: [concept, rxjs, programming, functional]
sources: ["[[raw/reactive-manifesto-article]]"]
related: ["[[Functional Programming]]", "[[Observable Pattern]]", "[[Error Handling]]"]
---

# Reactive Programming

Reactive programming is an event-driven programming paradigm where applications respond to data flow changes asynchronously...

[Page content, ~200-500 words]
```

### 2. Query (`/wiki query` or "what does my wiki say about X")

Search relevant pages, synthesize an answer from existing knowledge, and file valuable new findings back as wiki pages if they don't fit existing topics.

**Steps:**
1. Search wiki/ pages by keyword, wikilinks, tags, and Obsidian graph logic.
2. Identify 3-10 relevant pages.
3. Read and synthesize their content into a cohesive answer.
4. If the user's question surfaces a gap or new insight:
   - Create a new wiki page for the finding (or update existing), linked from query results.
   - Add to `log.md`: `## [2026-04-05] query | "What is X" → found Y, created Z`
5. Return the synthesized answer with citations to wiki pages used.

**Example workflow:**

Query: "what does my wiki say about error handling in typescript?"

```
Searched: tags: [typescript, error], wikilinks containing "error"
Found: [[Error Handling]], [[TypeScript Best Practices]], [[Try-Catch Patterns]]
Synthesized answer: [merged insights from all three pages]
Created new page: [[Error Boundary Strategies]] based on gap identified during synthesis
Logged: ## [2026-04-05] query | "error handling in typescript" → synthesized from 3 pages, created Error Boundary Strategies
```

### 3. Lint (`/wiki lint`)

Health-check the wiki for contradictions, orphaned pages, missing cross-references, thin articles that need expansion, broken wikilinks, and data gaps.

**Steps:**
1. List all pages in wiki/ (excluding index.md, log.md, schema.md).
2. For each page:
   - Check wikilinks: do all `[[links]]` point to existing pages?
   - Check tags: are they consistent with schema.md taxonomy?
   - Check sources: do all `[[raw/*]]` references exist?
   - Check word count: flag if <150 words (too thin), suggest expansion or merge.
   - Check related: are backlinks bidirectional? (if A links to B, should B link to A?)
3. Check for orphaned pages: pages with no incoming or outgoing wikilinks (except index/log/schema).
4. Check for duplicates: pages covering the same concept with different names.
5. Check frontmatter consistency: all required fields present?
6. Report findings: list broken wikilinks, orphaned pages, thin articles, contradictions.
7. Suggest fixes: merge thin articles, add missing cross-references, consolidate duplicates.
8. Add to log.md: `## [2026-04-05] lint | X broken links, Y orphaned pages, Z thin articles`

### 4. Reflect (`/wiki reflect`)

Discover non-obvious connections across articles, generate synthesis pieces that bridge related concepts, identify emergent patterns.

**Steps:**
1. Read all wiki pages (excluding index/log/schema).
2. Build a concept graph mentally: which ideas are connected? which are related but not yet linked?
3. Identify patterns: recurring themes, domain clusters, conceptual relationships.
4. Look for gaps: are there bridges between clusters that deserve a synthesis page?
5. Create 2-5 new synthesis pages that connect disparate ideas. Example:
   - "Type Safety and Error Handling" (connects [[TypeScript]], [[Error Handling]], [[Type Guards]])
   - "Reactive Patterns in Web Architecture" (connects [[Reactive Programming]], [[Event Driven Design]], [[Observable Pattern]])
6. Update related fields in existing pages to point to new synthesis pieces.
7. Add to log.md: `## [2026-04-05] reflect | Created 3 synthesis pages, identified 5 cross-cutting patterns`
8. Return summary of patterns discovered and new synthesis pieces created.

## Special Files

### wiki/index.md

Content-oriented catalog organized by category. Updated during ingest/reflect operations. Example structure:

```markdown
# Wiki Index

**Last updated:** 2026-04-05

## Programming & Architecture
- [[TypeScript]] — Type safety for JavaScript applications
- [[Reactive Programming]] — Event-driven programming paradigm
- [[Error Handling]] — Strategies for managing application faults

## Concepts
- [[Observable Pattern]] — Asynchronous data stream abstraction
- [[Functional Programming]] — Programming with pure functions and immutability

## Synthesis
- [[Type Safety and Error Handling]] — Bridges type systems and error management
- [[Reactive Patterns in Web Architecture]] — Connects reactive principles to application design
```

### wiki/log.md

Chronological record of all operations. Entries like:

```markdown
# Wiki Operation Log

## [2026-04-05] ingest | Reactive Manifesto article
- Processed 1 source
- Created 5 pages: Reactive Programming, Observable Pattern, Backpressure, Error Handling, Functional Programming
- Tags: [reactive, programming, async]

## [2026-04-04] query | "what is backpressure?"
- Searched: tags [async, reactive]
- Found 2 relevant pages, synthesized answer
- Logged location of answer in [[Backpressure]]

## [2026-04-03] reflect
- Identified 3 cross-cutting patterns: composition, async coordination, error propagation
- Created synthesis page: [[Async Error Propagation Patterns]]
- Updated 6 pages with new related links
```

### wiki/schema.md

Documents conventions, tag taxonomy, and page templates. Example:

```markdown
# Wiki Schema & Conventions

## Tag Taxonomy

**Domain tags** (pick 1-2):
- `concept` — abstract principle or pattern
- `tool` — specific library, framework, or technology
- `entity` — person, project, organization
- `pattern` — design pattern or architecture approach
- `technique` — specific method or practice

**Meta tags** (add as needed):
- `todo` — page needs expansion or clarification
- `wip` — work-in-progress, not complete
- `deprecated` — outdated or superseded concept
- `stub` — minimal content, should become fuller page

**Feature tags** (add all that apply):
- `typescript`, `javascript`, `react`, `node`, `async`, `reactive`, etc.

## Naming Conventions

- Page names are title-case, descriptive: `[[Type Safe Error Handling]]`, not `[[error handling types]]`
- Raw source files are kebab-case with date: `raw/2026-04-05-reactive-manifesto.md`
- Wikilinks use exact page name: `[[Reactive Programming]]` not `[[reactive programming]]`

## Page Guidelines

- **Scope:** One main concept per page
- **Length:** 200-500 words (thin articles <150 words should be merged or expanded)
- **Cross-references:** Every page should have 3-8 `[[related]]` links
- **Sources:** Always cite raw/ material or external sources
- **Updates:** Bump `updated` date when content changes, keep `created` immutable

## Frontmatter Template

```yaml
---
created: YYYY-MM-DD
updated: YYYY-MM-DD
tags: [domain-tag, feature-tag, meta-tag]
sources: ["[[raw/source-name]]"]
related: ["[[Page A]]", "[[Page B]]"]
---
```
```

## User Preferences

Based on CLAUDE.md:
- **Concise, no fluff** — Skip obvious observations, get to the point
- **Lowercase informal** — Comments and log entries are lowercase, minimal punctuation
- **DRY and KISS** — Keep pages focused, avoid bloat
- **Limited comments** — Only when necessary
- **Conventional commits** — Log entries follow pattern: `ingest | Title`, `query | Question`, `lint | Summary`, `reflect | Summary`

## Workflow Examples

### Example 1: Ingest a blog post

User: "Add this article to my wiki: https://example.com/reactive-programming-guide"

**Your steps:**
1. Save to `raw/2026-04-05-reactive-programming-guide.md` (fetch and parse URL, save content)
2. Extract concepts: Reactive Programming, Observable, Backpressure, Subject, Operator
3. Create wiki pages: `[[Reactive Programming]]`, `[[Observable Pattern]]`, `[[Backpressure]]`, `[[Subject]]`, `[[Operator Pattern]]`
4. Cross-link each page with wikilinks in body and `related` frontmatter
5. Update `index.md` with new programming/async category
6. Log entry: `## [2026-04-05] ingest | Reactive Programming Guide — Created 5 pages`
7. Confirm: "Ingested article as 5 wiki pages: [[Reactive Programming]], [[Observable Pattern]], [[Backpressure]], [[Subject]], [[Operator Pattern]]. Updated [[index]]. Log entry created."

### Example 2: Query the wiki

User: "what does my wiki say about error handling in typescript?"

**Your steps:**
1. Search pages with tags `[typescript]` and `[error]`
2. Find: `[[Error Handling]]`, `[[TypeScript Best Practices]]`, `[[Try-Catch Patterns]]`
3. Read and synthesize: create answer that weaves insights from all three
4. Check for gaps: notice "What about error recovery strategies?" — not covered well
5. Create new page: `[[Error Recovery Strategies]]`
6. Log: `## [2026-04-05] query | error handling in typescript — synthesized from 3 pages, created [[Error Recovery Strategies]]`
7. Return: synthesized answer with page citations + note about new synthesis page created

### Example 3: Lint the wiki

User: "lint the wiki"

**Your steps:**
1. Scan all pages
2. Find orphaned: `[[Observer Pattern Variants]]` — no backlinks, no related field populated
3. Find broken link: `[[Error Handling]]` links to `[[Non Existent Page]]`
4. Find thin: `[[Operator Pattern]]` is 120 words, should merge with `[[Function Operators]]` or expand
5. Find duplicate: `[[Async Coordination]]` and `[[Asynchronous Flow Control]]` cover same concept
6. Report:
   ```
   Lint Report
   - 1 broken link: [[Error Handling]] → [[Non Existent Page]]
   - 2 orphaned pages: [[Observer Pattern Variants]], [[Experimental API]]
   - 3 thin articles (<150 words): [[Operator Pattern]], [[Middleware]], [[Decorators]]
   - 1 duplicate concept: [[Async Coordination]] vs [[Asynchronous Flow Control]]
   - 2 missing backlinks: [[Functional Programming]] not linked from [[Higher Order Functions]]
   ```
7. Suggest fixes and ask which to apply
8. Log: `## [2026-04-05] lint | 1 broken link, 2 orphaned, 3 thin articles, 1 duplicate`

### Example 4: Reflect on the wiki

User: "reflect on the wiki, find connections"

**Your steps:**
1. Read all ~30 pages mentally
2. Identify patterns:
   - Many pages about async/reactive → opportunity for synthesis
   - TypeScript and error handling appear in 8 pages → gap for "Type-Driven Error Handling"
   - Observable, Promise, async/await all related → "Async Abstraction Levels"
3. Create synthesis pages:
   - `[[Async Abstraction Levels]]` — Compares Observable, Promise, async/await, generators
   - `[[Type-Driven Error Handling]]` — TypeScript's type system applied to error management
   - `[[Functional Composition in Async Code]]` — How functional patterns scale async operations
4. Update related fields in existing pages to link to syntheses
5. Log: `## [2026-04-05] reflect | Created 3 synthesis pages, linked 15 existing pages to new syntheses`
6. Return: "Discovered patterns: async abstraction spectrum, type safety in error paths, functional composition strategies. Created 3 synthesis pages connecting these ideas."

## Integration with Existing Vault

The wiki/ folder is isolated. Other folders in the vault (`developer/`, `projects/`, `work/`, `notes/`, etc.) are READ-ONLY:
- **Can:** Reference them via wikilinks `[[projects/Project Name]]` in wiki pages
- **Cannot:** Modify, create files in them
- When reflecting or querying, if relevant content exists in these folders, link to them but don't duplicate

## Starting a Fresh Wiki

If wiki/ doesn't exist yet:
1. Create folders: `mkdir -p "$WIKI_VAULT_PATH/wiki/raw"`
2. Create `wiki/index.md` — Start with empty catalog
3. Create `wiki/log.md` — Start with header `# Wiki Operation Log`
4. Create `wiki/schema.md` — Use the template above
5. Log: `## [2026-04-05] init | Wiki initialized`
6. Ready for ingest operations

## Summary

The wiki is a self-growing knowledge base that:
- **Grows with each session** — Ingest new sources, query for insights, reflect on patterns
- **Stays organized** — YAML frontmatter, Obsidian wikilinks, consistent naming
- **Compounds knowledge** — Each operation builds on previous ones, synthesis pages bridge concepts
- **Respects boundaries** — Isolated wiki/ folder, read-only access to user's existing notes
- **Stays actionable** — Short pages, focused topics, aggressive cross-linking, searchable via Obsidian

Use this skill whenever knowledge management, persistent memory, note organization, research synthesis, or learning compounding is the goal.
