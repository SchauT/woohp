---
name: git-commit-and-push
description: 'Review git changes, split work into coherent commits, use conventional commits by default, and push to origin only after explicit user approval. Use for commit hygiene, PR preparation, and safe publication of local branch changes.'
argument-hint: 'Describe the goal, any commit scope preferences, and whether push is expected now.'
user-invocable: true
---

# Git Commit and Push

## What This Skill Does

This skill performs a safe, repeatable git publication workflow:

1. Review and summarize current local changes.
2. Propose a coherent commit split by concern.
3. Stage and create commits one-by-one with clear messages.
4. Ask for explicit user confirmation before any push.
5. Push and report the exact result.

## When to Use

Use this skill when the user asks to:

- Check pending changes before publishing.
- Split work into multiple logical commits.
- Keep commit history clean and review-friendly.
- Push safely with a final human confirmation gate.

## Inputs to Collect

Before committing, gather:

- Desired commit scopes or ticket prefixes if needed.
- Target branch if push is requested.
- Whether unrelated modified files must be excluded.

Defaults:

- Commit style: conventional commits
- Push remote: `origin`
- Split strategy: group by subject as cleanly as possible, including hunk-level splits when useful

If the user did not specify scopes, branch expectations, or exclusions, ask concise clarifying questions.

## Procedure

1. Inspect working tree and diff.
2. Build a proposed commit plan.
3. Validate plan with the user.
4. Create commits by logical unit.
5. Re-check git status and commit list.
6. Ask explicit confirmation for push.
7. Push and report outcome.

## Detailed Execution Guide

### 1) Inspect and Classify Changes

- Run status and diff inspection.
- Identify change clusters (feature, fix, refactor, docs, chore, formatting, dependency bump).
- Detect risky content:
  - secrets
  - generated files
  - unrelated noise

If risky content exists, stop and ask how to handle it.

### 2) Propose Commit Split

Produce a concise plan:

- Commit N title
- Files included
- Rationale (why grouped together)

Quality bar for a valid split:

- Each commit compiles conceptually on its own.
- Commit boundaries are intention-based, not file-count based.
- No mixed unrelated concerns in one commit.
- If one file mixes multiple subjects, split by hunk when practical.

If no meaningful split exists, propose a single commit and explain why.

### 3) Confirm Plan

Ask user confirmation before staging/committing:

- "Do you approve this commit split plan?"

Only proceed after explicit approval.

### 4) Create Commits Safely

For each planned commit:

- Stage only the files/hunks for that unit.
- Commit with conventional commit style unless the user explicitly asked for something else.
- Show short commit result (hash + title).

If staging cannot isolate a commit cleanly, pause and ask whether to:

- adjust split,
- include extra hunks,
- or postpone a file to a later commit.

### 5) Validate Before Push

After all commits:

- Show `git status --short` result summary.
- Show recent commit list (for example last 5 commits).
- Confirm there is nothing unintended left staged.

### 6) Push Approval Gate (Mandatory)

Never push automatically.

Ask a direct confirmation that includes the branch name:

- "Commits are ready. I am about to push to `origin/<branch>`. Do you want me to push now?"

Only push after an explicit yes.

### 7) Push and Report

On approval:

- Push to `origin` on the confirmed branch.
- Report success with branch and remote.
- If push fails, report error and propose next safe action.

## Completion Checklist

This skill is complete only if all conditions are true:

- Changes were reviewed and summarized.
- Commit split was proposed and user-approved.
- Commits were created coherently with clear messages.
- Post-commit status was verified.
- Push happened only after explicit confirmation, or was intentionally skipped.
- Final report includes what was committed and push outcome.

## Output Format

Use this structure in the final response:

1. Change review summary.
2. Commit plan accepted.
3. Commits created (hash + message).
4. Remaining local changes (if any).
5. Push decision and result.
