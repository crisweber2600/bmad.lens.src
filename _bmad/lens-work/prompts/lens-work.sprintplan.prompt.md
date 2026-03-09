---
model: Sonnet 4.6
---

# /sprintplan Prompt

Route to the sprintplan phase workflow via the @lens phase router.

1. Run preflight before routing:
   - If the `bmad.lens.release` branch is `alpha` or `beta`, force a full preflight run (equivalent to `/preflight`) on every command invocation.
   - For all other branches, run standard session preflight (daily freshness).
2. Load `lifecycle.yaml` from the lens-work module
3. Invoke phase routing for `sprintplan`:
   - Validate predecessor `devproposal` PR is merged
   - Validate audience level is `large` (promotion from medium required)
   - Create phase branch `{initiative-root}-large-sprintplan`
4. Execute `workflows/router/sprintplan/workflow.md`
