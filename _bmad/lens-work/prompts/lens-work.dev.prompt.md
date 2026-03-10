---
---

# /dev Prompt — Epic-Level Implementation Loop

Route to the dev phase workflow via the @lens phase router.
Orchestrates the full implementation cycle for an epic: iterates all stories, implements each with per-task commits, runs adversarial review after each story, fixes issues, then continues to the next story.

## Implementation Target — NOT bmad.lens.release

**⚠️ CRITICAL:** `bmad.lens.release` is a **READ-ONLY authority repo**. It contains BMAD framework code (agents, workflows, lifecycle definitions). It is **NEVER** the implementation target.

The implementation target is the **TargetProject repo** — resolved from `initiative.target_repos[0].local_path` in the initiative config. All code changes, file creation, commits, and PRs go to the TargetProject repo. If you find yourself writing files inside `bmad.lens.release/`, STOP — you are in the wrong repo.

## Inputs

- **Epic number** (required): The epic to implement (e.g., `1`, `2`). All stories belonging to this epic will be discovered and implemented in order.
- **Special instructions** (optional): Freeform guidance that applies to ALL story implementations in this epic. Examples: "Use the repository pattern for data access", "Prioritize performance over readability", "All new endpoints must include OpenAPI annotations". These instructions are injected into implementation guidance for every story.

## Execution

1. **Authority Repo Health Check** (read-only — NO writes to these repos):
   1. Read the `bmad.lens.release` branch with `git -C bmad.lens.release branch --show-current`. This is a health check only — `bmad.lens.release` is NOT the implementation target.
   2. If branch is `alpha` or `beta`: pull ALL authority repos to refresh cached framework code (do NOT check `.preflight-timestamp` — ALWAYS pull on alpha/beta):
      ```bash
      git -C bmad.lens.release pull origin
      git -C .github pull origin
      git -C {governance-repo-path} pull origin   # path from governance-setup.yaml
      ```
      Then write today's date to `_bmad-output/lens-work/.preflight-timestamp`.
   3. Otherwise: read `_bmad-output/lens-work/.preflight-timestamp`. If missing or older than today, run the same pulls and update timestamp. If today's date matches, skip pulls.
   4. If any authority repo directory is missing: stop and report the failure.
2. Load `lifecycle.yaml` from the lens-work module (read from `bmad.lens.release` — read-only)
3. Invoke phase routing for `dev`:
   - Validate predecessor `sprintplan` PR is merged
   - Validate audience level is `base` (promotion from large required)
   - Create phase branch `{initiative-root}-dev`
4. Execute `workflows/router/dev/workflow.md` with parameters:
   - `epic_number`: the epic number provided by the user
   - `special_instructions`: the optional special instructions provided by the user (empty string if none)

## Write Scope — Target Repo Only (NOT bmad.lens.release)

During `/dev`, ALL implementation writes (file creation, modification, commits) are **strictly scoped to the TargetProject repo folder** resolved from `initiative.target_repos[0].local_path`. The agent MUST NOT modify files in:
- `bmad.lens.release/` (read-only framework — NEVER an implementation target)
- The control repo (bmad.lens.bmad) except `_bmad-output/` state tracking
- The governance repo
- `.github/` adapter layer

**Dev Write Guard:** Before implementing any task, the workflow runs a hard gate (Step 3.Nc) that verifies the working directory is inside the TargetProject repo. If the working directory resolves to `bmad.lens.release/` or any other non-target path, implementation is **BLOCKED**. The guard also rejects any `target_path` that contains `bmad.lens.release`.

## Epic-Level Story Loop

The dev workflow will:
1. Discover all story files matching the epic number
2. Sort stories by story order
3. Display the story list and confirm before proceeding
4. For each story:
   - Load story file and run constitution/pre-implementation gates
   - **Create epic branch** (`feature/{epic-key}`) in target repo if not exists
   - **Create story branch** (`feature/{epic-key}-{story-key}`) from epic branch
   - Implement all tasks (each task gets its own commit with multi-line message including Story/Task/Epic metadata)
   - **Push after every commit** — no local-only commits allowed
   - Run adversarial code review
   - If issues found: fix and re-review (max 2 passes)
   - **Auto-create PR** from story branch → epic branch (only after review gate passes)
   - Mark story done and commit state
5. After all stories: run epic completion gate, retrospective, auto-create epic PR → develop/main, update state
