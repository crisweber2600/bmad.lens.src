# /devproposal Prompt

Route to the devproposal phase workflow via the @lens phase router.

1. Run preflight before routing:
   - If current branch is `alpha` or `beta`, force a full preflight run (equivalent to `/preflight`) on every command invocation.
   - For all other branches, run standard session preflight (daily freshness).
2. Load `lifecycle.yaml` from the lens-work module
3. Invoke phase routing for `devproposal`:
   - Validate predecessor `techplan` PR is merged
   - Validate audience level is `medium` (promotion from small required)
   - Create phase branch `{initiative-root}-medium-devproposal`
4. Execute `workflows/router/devproposal/workflow.md`
