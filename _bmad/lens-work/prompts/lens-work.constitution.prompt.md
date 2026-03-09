# /constitution Prompt

Check or resolve constitutional governance for the current initiative.

## Routing

1. Run preflight before governance resolution:
	- If the `bmad.lens.release` branch is `alpha` or `beta`, force a full preflight run (equivalent to `/preflight`) on every command invocation.
	- For all other branches, run standard session preflight (daily freshness).
2. Use `git-state` skill → `current-initiative` to confirm on an initiative branch
3. If not on an initiative branch: `❌ Not on an initiative branch. Use /switch to select an initiative first.`
4. Parse domain and service from the current initiative root
5. Execute `workflows/governance/resolve-constitution/workflow.md`
6. Display the resolved constitution for the current initiative

## Error Handling

| Condition | Response |
|-----------|----------|
| Not on an initiative branch | `❌ Not on an initiative branch. Use /switch to select an initiative first.` |
| Governance repo not accessible | `❌ Governance repo not accessible. Run /onboard to verify.` |
