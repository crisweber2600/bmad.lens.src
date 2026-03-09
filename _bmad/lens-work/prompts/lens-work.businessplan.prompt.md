---
model: Sonnet 4.6
---

# /businessplan Prompt

Route to the businessplan phase workflow via the @lens phase router.

1. Run preflight before routing:
   - If the `bmad.lens.release` branch is `alpha` or `beta`, force a full preflight run (equivalent to `/preflight`) on every command invocation.
   - For all other branches, run standard session preflight (daily freshness).
2. Load `lifecycle.yaml` from the lens-work module
3. Invoke phase routing for `businessplan`:
   - Validate predecessor `preplan` PR is merged
   - Check current track includes `businessplan` in its phases
   - Create phase branch `{initiative-root}-small-businessplan`
4. Execute `workflows/router/businessplan/workflow.md`
