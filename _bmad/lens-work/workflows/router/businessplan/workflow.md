# /businessplan Workflow

**Phase:** Router
**Purpose:** Execute the businessplan phase — produce PRD and UX design artifacts.
**Primary Agent:** John (PM)
**Supporting Agent:** Sally (UX Designer)
**Audience:** small
**Predecessor:** preplan (must be complete — PR merged)

## Pre-conditions

- User is authenticated and onboarded
- Initiative exists with a track that includes `businessplan`
- Preplan phase PR is merged (predecessor enforcement)
- Current branch is on the initiative's `small` audience

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

### Step 1: Phase Router Validation

Invoke the @lens phase router:

1. Read `lifecycle.yaml` to confirm `businessplan` is valid for this track
2. Derive current initiative and audience from branch via git-state
3. Check predecessor: preplan PR is merged (via provider-adapter `query-pr`)
4. If preplan not complete:
   ```
   ❌ Phase `businessplan` requires `preplan` to be complete.
      Run `/preplan` first, then create a PR to merge it.
   ```
5. If valid: create phase branch `{initiative-root}-small-businessplan` using git-orchestration

### Step 2: Load Preplan Artifacts

Load preplan artifacts from `phases/preplan/` as input context:

- `product-brief.md` — informs PRD scope
- `research.md` — informs market and domain context

### Step 3: Delegate to PM Agent (PRD)

Delegate PRD production to John (PM agent). PRD is produced first because it informs UX design decisions.

```
## PRD — Generating...
```

| Artifact | Path | Required |
|----------|------|----------|
| PRD | `phases/businessplan/prd.md` | Yes |

### Step 4: Delegate to UX Designer Agent

Delegate UX design to Sally (UX designer agent). Uses the PRD as input context.

```
## UX Design — Generating...
```

| Artifact | Path | Required |
|----------|------|----------|
| UX Design | `phases/businessplan/ux-design.md` | Yes |

### Step 5: Progress Markers (Batch Mode)

```
## PRD — Generating...
{PRD content}
## PRD — Complete ✅

## UX Design — Generating...
{UX design content}
## UX Design — Complete ✅
```

### Step 6: Commit Artifacts

Using git-orchestration skill:

1. Stage all artifacts in `phases/businessplan/`
2. Commit: `[BUSINESSPLAN] {initiative-root} — PRD and UX design complete`
3. Push to remote

### Step 7: Report Completion

```
✅ BusinessPlan phase complete

## Artifacts Produced
- prd.md ✅
- ux-design.md ✅

## Next Step
BusinessPlan artifacts are committed and pushed. Your PR will be created
automatically for review. Then run `/techplan` to continue.
```

## Multi-Agent Delegation

This phase uses **sequential delegation**:
1. PRD (John/PM) — produced first
2. UX Design (Sally/UX) — uses PRD as input context

The UX design MUST reference and align with the PRD. Sally reads `prd.md` before producing the UX design.
