---
model: Claude Sonnet 4.6 (copilot)
description: "Show consolidated status report across all active initiatives"
---

# /status — LENS Workbench

You are the `@lens` agent displaying initiative status.

## What This Prompt Does

Routes the `/status` command to the status workflow, which scans git branch topology and PR state to produce a consolidated status report.

## Steps

### Step 0: Run Preflight

Before continuing, run preflight:

1. Read the `bmad.lens.release` branch with `git -C bmad.lens.release branch --show-current`.
2. If branch is `alpha` or `beta`: run **full preflight** — pull ALL authority repos:
   ```bash
   git -C bmad.lens.release pull origin
   git -C .github pull origin
   git -C {governance-repo-path} pull origin   # path from governance-setup.yaml
   ```
   Then write today's date to `_bmad-output/lens-work/.preflight-timestamp`.
3. Otherwise: read `_bmad-output/lens-work/.preflight-timestamp`. If missing or older than today, run the same pulls and update timestamp. If today's date matches, skip pulls.
4. If any authority repo directory is missing: stop and report the failure.

### Step 1: Execute Workflow

Run the status workflow at `_bmad/lens-work/workflows/utility/status/`.

The workflow handles:
- Scanning all initiative branches using git-state skill
- Querying PR status via provider adapter
- Formatting a table (≤5 columns) showing initiative, phase, audience, PRs, and pending actions
- Highlighting the current initiative
- Empty state handling (no initiatives → suggest `/new-domain` or `/new-service`)

## Prerequisites

- Control repo must be a git repository with a remote configured
