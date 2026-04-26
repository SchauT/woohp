---
name: session-doc-sync
description: 'Review session changes at the end of work, detect documentation drift, and update AGENTS.md or docs/* when the session introduced important architectural, operational, workflow, or troubleshooting knowledge. Use for end-of-session documentation maintenance and knowledge base hygiene.'
argument-hint: 'Describe the session scope and whether to update existing docs only or create new docs when needed.'
user-invocable: true
---

# Session Documentation Sync

## What This Skill Does

This skill runs an end-of-session documentation review workflow.

It:

1. Reviews the changes made during the session.
2. Detects whether those changes introduce knowledge that should persist in documentation.
3. Updates existing documentation when the right home already exists.
4. Creates a new document only when the topic is durable and does not fit cleanly in existing docs.
5. Keeps `AGENTS.md` concise and uses `docs/` as the detailed source of truth.

## When to Use

Use this skill when:

- Finishing a work session.
- A feature, workflow, convention, pitfall, or operational step changed.
- New troubleshooting knowledge emerged.
- Existing docs may now be outdated.
- You want to reduce documentation drift before wrapping up.

## Defaults

- Prefer updating existing docs over creating new ones.
- Keep `AGENTS.md` short and stable.
- Put detailed operational knowledge in `docs/`.
- Add docs only for durable knowledge, not temporary implementation noise.

## Procedure

1. Inspect session changes.
2. Extract durable knowledge.
3. Map that knowledge to existing documentation.
4. Update docs or create a new doc if needed.
5. Check cross-links and indexes.
6. Summarize what was updated and what was intentionally left undocumented.

## Detailed Execution Guide

### 1) Inspect Session Changes

Review the files changed during the session and classify what happened.

Typical categories:

- architecture change
- operational workflow change
- bootstrap/setup change
- troubleshooting discovery
- new application/service
- convention or policy change
- one-off refactor with no documentation value

Prefer using git diff/status and the final state of edited files.

### 2) Extract Durable Knowledge

Document only information that is likely to matter again.

Good candidates:

- new source-of-truth locations
- changed commands or validation steps
- new bootstrap prerequisites
- new pitfalls, constraints, or gotchas
- new repo conventions
- new runbooks or troubleshooting paths

Do not document:

- temporary workarounds that are already removed
- purely local experiments
- obvious implementation details with no reuse value
- code changes that do not affect how humans operate, reason about, or extend the repo

### 3) Decide Whether Documentation Is Needed

If the session produced no durable knowledge, stop and report:

- no doc update required
- why the changes do not justify documentation changes

Otherwise continue.

### 4) Choose the Right Documentation Target

Prefer the smallest correct update.

Routing rules:

- Update `AGENTS.md` only for repo-wide guidance that should apply to most future tasks.
- Update an existing file in `docs/` when the topic already has a clear home.
- Create a new file in `docs/` only when the topic is durable, substantial, and does not fit existing docs without forcing unrelated content together.
- Update `docs/README.md` when adding a new document.

### 5) Apply Documentation Changes

When editing docs:

- preserve the current structure and tone
- keep sections concise and actionable
- prefer commands, source-of-truth paths, and operational checks over prose
- link related docs rather than duplicating content
- avoid turning docs into changelogs

When creating a new doc:

- choose a narrow, durable scope
- use a task-oriented title
- add it to `docs/README.md`
- link to it from `AGENTS.md` if it becomes part of the normal knowledge map

### 6) Cross-Check for Drift

After updating docs, verify:

- commands still match the repository state
- source-of-truth file paths are correct
- docs do not contradict `AGENTS.md`
- no duplicated content was introduced unnecessarily

### 7) Report Outcome

End with:

- what documentation was updated
- why those updates were needed
- any important knowledge intentionally not documented
- any follow-up documentation gap that still remains

## Quality Criteria

A successful run meets all of these:

- Durable knowledge introduced by the session was identified correctly.
- Documentation was updated only when justified.
- Existing docs were preferred over new docs when reasonable.
- `AGENTS.md` remained concise.
- New docs were indexed and cross-linked.
- No documentation drift or duplication was introduced.

## Output Format

Use this structure in the final response:

1. Session knowledge detected.
2. Documentation updates made.
3. Files updated or created.
4. Items intentionally left undocumented.
5. Remaining documentation gaps, if any.

## Important Limitation

A skill does not guarantee automatic execution at the end of every session by itself.

If strict end-of-session execution is required, pair this skill with one of these:

- a reusable prompt that explicitly runs this workflow before wrap-up
- workspace instructions that tell the agent to invoke this skill during close-out
- a custom agent or hook-based workflow if you want stronger automation
