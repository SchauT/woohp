---
description: "Use when the user indicates end-of-session intent: wrap-up, finalization, done for today, before closing, or preparing the final handoff. Run session-doc-sync to prevent documentation drift before finishing."
name: Session Close-Out
---

# Session Close-Out

When the user intent indicates session end or final wrap-up, run a documentation sync pass before finalizing.

## Mandatory Flow

1. Invoke the session documentation workflow from the skill `session-doc-sync`.
2. Apply only justified doc updates based on durable session knowledge.
3. Summarize what changed in docs and why.
4. If no doc update is needed, explicitly state why.
5. Invoke `git-commit-and-push` to review all resulting changes, split into coherent commits, and ask for explicit push confirmation.

## Guardrails

- Prefer updating existing docs over creating new docs.
- Keep AGENTS concise.
- Keep detailed runbooks in docs.
- Do not invent runbook content not supported by session changes.
- Never push automatically: push only after explicit user approval through the `git-commit-and-push` workflow.
