# Compliance Check Workflow

**Phase:** Governance
**Purpose:** Run constitution compliance checks at PR gates.
**Trigger:** Invoked by phase-lifecycle (before phase PR) and audience-promotion (before promotion PR).

## Overview

This workflow resolves the constitutional requirements for an initiative and evaluates compliance against current artifacts. Results are formatted for embedding in PR descriptions.

## Steps

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

### Step 1: Resolve Constitution

Invoke the constitution skill `resolve-constitution` with the current initiative's domain, service, and repo context.

**Input:**
- Domain and service from initiative config
- Repo from governance repo structure (if Level 4 exists)

**Output:** Resolved constitution with all merged requirements

### Step 2: Evaluate Compliance

Invoke the constitution skill `check-compliance` with:
- Resolved constitution
- Current phase
- Artifacts path for this initiative

### Step 3: Process Results

For each compliance check result:

| Status | Action |
|--------|--------|
| PASS | Include as ✅ in report |
| FAIL (hard gate) | **BLOCK** — do not create PR, report error |
| FAIL (informational) | Include as ⚠️ warning in report |
| NOT-APPLICABLE | Include as ⬜ N/A in report |

### Step 4: Format for PR Body

Generate the compliance section for the PR description:

```markdown
### Constitution Compliance

| Requirement | Status | Details |
|-------------|--------|---------|
| PRD required | ✅ PASS | prd.md exists and is non-empty |
| UX design required | ✅ PASS | ux-design.md exists and is non-empty |
| Architecture required | ⬜ N/A | Not required for this phase |

**Overall:** ✅ PASS — All requirements satisfied
```

### Hard Gate Failure

If any hard-gate requirement fails, the PR is BLOCKED:

```
❌ Constitution Compliance FAILED — PR Cannot Be Created

## Hard Gate Failures
- **PRD required:** prd.md is missing from phases/businessplan/
- **UX design required:** ux-design.md is empty

Fix these issues and try again. Hard gate failures must be resolved
before the PR can be created.
```

## Integration Points

### Phase-Lifecycle (Story 4.1)

Compliance check runs BEFORE phase PR creation:
1. Run compliance check
2. If hard gate failure → block with error, do NOT create PR
3. If all pass or informational-only → create PR with compliance section in body

### Audience-Promotion (Story 7.1)

Compliance check runs as part of pre-promotion gate checks:
1. Run compliance check for ALL phases in current audience
2. Results embedded in promotion PR body
3. Hard gate failures block promotion
