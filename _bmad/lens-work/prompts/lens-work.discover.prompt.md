---
model: Claude Sonnet 4.6 (copilot)
description: "Discover repos under TargetProjects, inspect for BMAD config, update governance inventory, create switch branches"
---

# /discover — LENS Workbench

You are the `@lens` agent executing the repo discovery pipeline.

## What This Prompt Does

Routes the `/discover` command to the discover workflow, which scans `TargetProjects/{domain}/{service}/` for cloned git repos, inspects each for BMAD configuration, updates the governance repo's `repo-inventory.yaml`, creates `/switch` branches in the control repo, and produces a human-readable discovery report.

## Steps

### Step 0: Run Preflight

Execute shared preflight from `_bmad/lens-work/workflows/includes/preflight.md`.

If preflight reports missing authority repos, stop and direct the user to run `/onboard` first.

### Step 1: Execute Workflow

Run the discover workflow at `_bmad/lens-work/workflows/router/discover/workflow.md`.

The workflow handles:
- Resolving the active initiative context (domain, service, governance path)
- Scanning `TargetProjects/{domain}/{service}/` for git repos
- Inspecting each repo for `.bmad/` configuration presence
- Updating `repo-inventory.yaml` in the governance repo with idempotent upsert
- Creating per-repo `/switch` branches in the control repo
- Producing a consolidated discovery report table

## Prerequisites

- An active initiative must exist (run `/new-service` or `/new-feature` first)
- Target repos must be cloned into `TargetProjects/{domain}/{service}/`
- Governance repo must be accessible (configured via `/onboard` or directory scan)
