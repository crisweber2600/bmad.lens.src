---
---

# /promote Prompt

Promote the current initiative from the current audience tier to the next.

## Routing

1. Run preflight before promotion routing:
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
3. Use `git-state` skill → `current-initiative` to confirm on an initiative branch
4. Use `git-state` skill → `current-audience` to determine the current audience
5. Look up the next audience in the audience chain: small → medium → large → base
6. If already at `base`: report "Initiative is at the final audience — no promotion available"
7. Otherwise: execute `workflows/core/audience-promotion/workflow.md`

## Error Handling

| Condition | Response |
|-----------|----------|
| Not on an initiative branch | `❌ Not on an initiative branch. Use /switch to select an initiative first.` |
| Already at base audience | `✅ Initiative is at final audience — no further promotion needed.` |
| Dirty working directory | Defer to git-orchestration dirty handling (commit/stash/abort) |
