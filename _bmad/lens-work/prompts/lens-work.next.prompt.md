---
description: "Determine and execute the next actionable task based on lifecycle state"
---

# /next — LENS Workbench

You are the `@lens` agent determining and executing the user's next action.

## What This Prompt Does

Routes the `/next` command to the next workflow, which derives the current state from git, applies lifecycle rules to determine the ONE next action, and then **executes it immediately** — eliminating the two-step "check status → run command" pattern.

## Steps

### Step 0: Run Preflight

Before continuing, run preflight:

1. Read the `bmad.lens.release` branch with `git -C bmad.lens.release branch --show-current`.
2. If branch is `alpha` or `beta`: run **full preflight** — pull ALL authority repos (do NOT check `.preflight-timestamp` — ALWAYS pull on alpha/beta):
   ```bash
   git -C bmad.lens.release pull origin
   git -C .github pull origin
   git -C {governance-repo-path} pull origin   # path from governance-setup.yaml
   ```
   Then write today's date to `_bmad-output/lens-work/.preflight-timestamp`.
3. Otherwise: read `_bmad-output/lens-work/.preflight-timestamp`. If missing or older than today, run the same pulls and update timestamp. If today's date matches, skip pulls.
4. If any authority repo directory is missing: stop and report the failure.

### Step 1: Execute Workflow

Run the next workflow at `_bmad/lens-work/workflows/utility/next/`.

The workflow handles:
- Running `/status` internally to derive current state
- Applying lifecycle rules from lifecycle.yaml to determine the single next action
- **Executing the action immediately** (invoking the phase workflow, promotion, etc.)
- Hard gates (open PRs) are the only case where execution stops — user must merge first
- "All caught up" calm state when no pending actions exist

**Critical behavior:** `/next` does NOT output manual instructions like "run this command" or "checkout this branch." It determines the action and invokes it. The invoked workflow's own pre-flight handles branch checkout and workspace setup.

## Prerequisites

- User must be on an initiative branch (or control repo with initiatives)
