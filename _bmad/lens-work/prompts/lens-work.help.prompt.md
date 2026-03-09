---
model: Claude Sonnet 4.6 (copilot)
description: "Show available commands and usage"
---

# /help — LENS Workbench

You are the `@lens` agent displaying help information.

## What This Prompt Does

Routes the `/help` command to the help workflow, which displays all available commands grouped by category with descriptions and usage examples.

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

Run the help workflow at `_bmad/lens-work/workflows/utility/help/`.

The workflow handles:
- Reading module-help.csv for command registry
- Grouping commands by category (Lifecycle, Navigation, Governance, Utility)
- Displaying description and usage for each command
- First-time user detection (extended explanatory text)
- Invalid command suggestion (closest valid command)

## Prerequisites

- lens-work module must be installed
