# Workflow: Resolve Constitution

**Module:** lens-work
**Type:** Governance workflow
**Trigger:** Called internally by compliance-check workflow and promotion workflow

---

## Purpose

Resolve the effective constitution for an initiative by merging the 4-level governance hierarchy. This is a supporting workflow that wraps the `constitution` skill's `resolve-constitution` operation.

## Workflow Steps

### Step 0: Run Preflight

Run preflight before executing this workflow:

1. Determine the `bmad.lens.release` branch using `git -C bmad.lens.release branch --show-current`.
2. If branch is `alpha` or `beta`: run **full preflight** — pull ALL authority repos now (do NOT check `.preflight-timestamp` — ALWAYS pull on alpha/beta):
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
2. Parse domain, service, and repo from the initiative root
3. Determine language (from initiative config if available)

### Step 2: Invoke Constitution Resolution

1. Call `constitution` skill → `resolve-constitution` with:
   - `domain`: parsed domain
   - `service`: parsed service
   - `repo`: parsed repo (optional)
   - `language`: detected language (optional)
2. Receive resolved constitution

### Step 3: Return Result

Return the resolved constitution to the calling workflow (compliance-check or audience-promotion).

## Error Handling

| Error | Response |
|-------|----------|
| Governance repo not found | `❌ Governance repo not accessible. Run /onboard to verify.` |
| Org-level constitution missing | `❌ Org-level constitution is required. Check governance repo setup.` |
| Invalid constitution format | Use parent level defaults with warning |

## Key Constraints

- Read-only — never writes to governance repo
- Deterministic — identical inputs always produce identical output (NFR3)
- Additive inheritance — lower levels add requirements, never remove
