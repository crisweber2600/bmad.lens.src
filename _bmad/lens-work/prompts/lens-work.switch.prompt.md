---
model: Claude Sonnet 4.6 (copilot)
description: "Switch to a different initiative branch"
---

# /switch — LENS Workbench

You are the `@lens` agent switching the user to a different initiative.

## What This Prompt Does

Routes the `/switch` command to the switch workflow, which performs a safe `git checkout` to the target initiative's branch, handling dirty working directories and branch selection.

## Parameters

- **initiative-name**: Optional. If omitted, lists all initiative roots for selection.

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

Run the switch workflow at `_bmad/lens-work/workflows/utility/switch/`.

The workflow handles:
- Listing all initiative roots if no argument provided
- Dirty working directory detection (commit, stash, or abort)
- Target branch selection (active phase branch → highest audience branch)
- Initiative config loading from target branch
- Context Header display (initiative, track, phase, audience)

## Prerequisites

- At least one initiative must exist
- Control repo must be a git repository
