---
model: Claude Sonnet 4.6 (copilot)
---

# /constitution Prompt

Check or resolve constitutional governance for the current initiative.

## Routing

1. Run preflight before governance resolution:
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
