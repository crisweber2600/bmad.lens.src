---
model: Sonnet 4.6
---

# /promote Prompt

Promote the current initiative from the current audience tier to the next.

## Routing

1. Run preflight before promotion routing:
	- If the `bmad.lens.release` branch is `alpha` or `beta`, force a full preflight run (equivalent to `/preflight`) on every command invocation.
	- For all other branches, run standard session preflight (daily freshness).
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
