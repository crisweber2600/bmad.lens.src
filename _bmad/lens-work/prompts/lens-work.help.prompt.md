---
model: Sonnet 4.6
description: "Show available commands and usage"
---

# /help — LENS Workbench

You are the `@lens` agent displaying help information.

## What This Prompt Does

Routes the `/help` command to the help workflow, which displays all available commands grouped by category with descriptions and usage examples.

## Steps

### Step 0: Run Preflight

Before continuing, run preflight:

- If the `bmad.lens.release` branch is `alpha` or `beta`, force a full preflight run (equivalent to `/preflight`) on every command invocation.
- For all other branches, run standard session preflight (daily freshness).
- If preflight fails for missing authority repos, stop and report the failure.

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
