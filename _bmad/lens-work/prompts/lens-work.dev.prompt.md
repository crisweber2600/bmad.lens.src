---
---

# /dev Prompt — Epic-Level Implementation Loop

Route to the dev phase workflow via the @lens phase router.
Orchestrates the full implementation cycle for an epic: iterates all stories, implements each with per-task commits, runs adversarial review after each story, fixes issues, then continues to the next story.

## Inputs

- **Epic number** (required): The epic to implement (e.g., `1`, `2`). All stories belonging to this epic will be discovered and implemented in order.
- **Special instructions** (optional): Freeform guidance that applies to ALL story implementations in this epic. Examples: "Use the repository pattern for data access", "Prioritize performance over readability", "All new endpoints must include OpenAPI annotations". These instructions are injected into implementation guidance for every story.

## Execution

1. Run preflight before routing:
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
2. Load `lifecycle.yaml` from the lens-work module
3. Invoke phase routing for `dev`:
   - Validate predecessor `sprintplan` PR is merged
   - Validate audience level is `base` (promotion from large required)
   - Create phase branch `{initiative-root}-dev`
4. Execute `workflows/router/dev/workflow.md` with parameters:
   - `epic_number`: the epic number provided by the user
   - `special_instructions`: the optional special instructions provided by the user (empty string if none)

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
