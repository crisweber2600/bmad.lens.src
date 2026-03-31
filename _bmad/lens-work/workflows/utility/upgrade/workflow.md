---
name: upgrade
description: Migrate a v2 control repo to v3 — rename audience branches to milestone branches and write LENS_VERSION
agent: "@lens"
trigger: /lens-upgrade command
category: utility
phase_name: utility
display_name: Lens Upgrade
entryStep: './steps/step-01-detect.md'
---

# /lens-upgrade — Migrate Control Repo to v3

**Goal:** Detect the current LENS schema version, compute a branch rename plan from `lifecycle.yaml` migration descriptors, confirm with the user, apply renames locally, write `LENS_VERSION`, and commit.

**Your Role:** Operate as a safe, confirmed migration helper. Show every change before applying it. Never auto-rename remote branches — output the push commands instead.

---

## WORKFLOW ARCHITECTURE

This workflow uses **step-file architecture**:

- Step 1 detects the current version state and loads migration descriptors.
- Step 2 scans local branches and computes the rename plan.
- Step 3 presents the plan, confirms with the user, and applies renames.
- Step 4 writes `LENS_VERSION`, commits, and reports completion.

State persists through `detected_version`, `target_version`, `migration`, `branch_scan`, `rename_plan`, `phase_branch_notes`, and `renames_applied`.

---

## EXECUTION

Read fully and follow: `{entryStep}`

### Step Map

1. `step-01-detect.md` — Version detection and migration descriptor load
2. `step-02-plan-renames.md` — Branch scan and rename plan computation
3. `step-03-confirm-and-apply.md` — Display plan, confirm, apply local renames
4. `step-04-write-version.md` — Write LENS_VERSION, commit, report
