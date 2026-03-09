# Workflow: Cross-Initiative Sensing

**Module:** lens-work
**Type:** Governance workflow
**Trigger:** Called by audience-promotion workflow and `/sense` command

---

## Purpose

Orchestrate cross-initiative overlap detection using the sensing skill. This governance workflow wraps the sensing skill for use in promotion gates and on-demand checks.

## Workflow Steps

### Step 0: Run Preflight

Run preflight before executing this workflow:

1. Determine the `bmad.lens.release` branch using `git -C bmad.lens.release branch --show-current`.
2. If branch is `alpha` or `beta`: run **full preflight** — pull ALL authority repos now:
   ```bash
   git -C bmad.lens.release pull origin
   git -C .github pull origin
   git -C {governance-repo-path} pull origin   # path from governance-setup.yaml
   ```
   Then write today's date to `_bmad-output/lens-work/.preflight-timestamp`.
3. Otherwise: read `_bmad-output/lens-work/.preflight-timestamp`. If missing or older than today, run the same three `git pull` commands above and update the timestamp. If today's date matches, skip pulls.
4. If any authority repo directory is missing: stop and return the preflight failure message.

### Step 1: Determine Initiative Context

1. Use `git-state` skill → `current-initiative` to get the initiative root
2. Parse domain, service, and feature from the initiative root

### Step 2: Run Sensing Scan

1. Invoke `sensing` skill → `scan-initiatives` with:
   - `current_domain`: parsed domain
   - `current_service`: parsed service
   - `current_feature`: parsed feature
2. Receive sensing report with overlap analysis

### Step 3: Check Constitution Gate Mode

1. Invoke `constitution` skill → `resolve-constitution` for this initiative
2. Check `sensing_gate_mode` in resolved constitution:
   - `informational` (default): sensing results are advisory
   - `hard`: sensing overlaps block promotion

### Step 4: Return Result

Return the sensing report and gate mode to the calling workflow:

```yaml
sensing_result:
  report: {sensing_report}
  gate_mode: informational | hard
  has_overlaps: true | false
  blocks_promotion: false  # true only if gate_mode=hard AND has_overlaps=true
```

## Error Handling

| Error | Response |
|-------|----------|
| Not on initiative branch | `❌ Not on an initiative branch.` |
| No remote branches | Return empty report with warning |
| Constitution unavailable | Default to informational gate mode |

## Key Constraints

- Read-only — scans branches, never modifies anything
- Deterministic — same branch state produces same report
- Gate mode determined by constitution, not by this workflow
