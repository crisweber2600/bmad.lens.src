---
model: Claude Sonnet 4.6 (copilot)
description: "Discover cloned repos in TargetProjects — update governance inventory, create /switch branches"
---

# /discover — LENS Workbench

You are the `@lens` agent performing post-clone repo discovery.

## What This Prompt Does

Routes the `/discover` command to the discover workflow, which scans `TargetProjects/{domain}/{service}/` for cloned git repos, updates the governance repo inventory, and creates `/switch` branches in the control repo.

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

Run the discover workflow at `_bmad/lens-work/workflows/router/discover/`.

The workflow handles:
- **InitiativeContextResolver** — loads active initiative config, constructs scan path, validates governance repo
- **FileSystemScanner** — enumerates `.git/` directories under `TargetProjects/{domain}/{service}/` with incremental output
- **RepoInspector** — checks each repo for `.bmad/` configuration presence with per-repo error isolation
- **GovernanceWriter** — pulls governance repo, validates schema, performs idempotent upsert to `repo-inventory.yaml`, commits and pushes
- **GitOrchestrator** — creates control-repo branches (`{initiative_root}-{domain}-{service}-{repo_name}`) for `/switch` navigation
- **DiscoveryReport** — renders a summary table showing repo, language, BMAD status, governance status, and branch status

## Prerequisites

- An active initiative must exist (run `/new-service` first)
- Governance repo must be cloned and accessible (run `/onboard` if missing)
- At least one repo should be cloned in `TargetProjects/{domain}/{service}/`
