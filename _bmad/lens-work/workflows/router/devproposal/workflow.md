# /devproposal Workflow

**Phase:** Router
**Purpose:** Execute the devproposal phase — produce epics, stories, and implementation proposals.
**Agent:** John (PM)
**Audience:** medium (requires promotion from small)
**Predecessor:** techplan (must be complete — PR merged)

## Pre-conditions

- User is authenticated and onboarded
- Initiative exists with a track that includes `devproposal`
- Techplan phase PR is merged (predecessor enforcement)
- Initiative has been promoted to medium audience (`{root}-medium` branch exists)

## Steps

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

### Step 1: Phase Router Validation

Invoke the @lens phase router:

1. Read `lifecycle.yaml` to confirm `devproposal` is valid for this track
2. Derive current initiative and audience from branch via git-state
3. Check predecessor: techplan PR is merged
4. Check audience level: current audience must be `medium`
5. If still on small audience:
   ```
   ❌ Phase `devproposal` requires `medium` audience.
      Current audience: small
      Run `/promote` to promote from small → medium first.
   ```
6. If valid: create phase branch `{initiative-root}-medium-devproposal` using git-orchestration

### Step 2: Load Planning Artifacts

Load all prior phase artifacts as input context:

- `phases/preplan/product-brief.md` — original vision
- `phases/preplan/research.md` — domain research
- `phases/businessplan/prd.md` — requirements
- `phases/businessplan/ux-design.md` — UX specifications
- `phases/techplan/architecture.md` — technical design

### Step 3: Delegate to PM Agent

Delegate epic and story production to John (PM agent):

```
## Implementation Proposal — Generating...
```

| Artifact | Path | Required |
|----------|------|----------|
| Epics & Stories | `phases/devproposal/epics.md` | Yes |

All artifacts saved to: `_bmad-output/lens-work/initiatives/{domain}/{service}/phases/devproposal/`

### Step 4: Commit Artifacts

Using git-orchestration skill:

1. Stage all artifacts in `phases/devproposal/`
2. Commit: `[DEVPROPOSAL] {initiative-root} — epics and stories complete`
3. Push to remote

### Step 5: Report Completion

```
✅ DevProposal phase complete

## Artifacts Produced
- epics.md ✅

## Next Step
DevProposal artifacts are committed and pushed. Your PR will be created
automatically. After it merges, run `/promote` to advance to large audience,
then `/sprintplan` to continue.
```

## Notes

- devproposal is the ONLY phase in medium audience
- After devproposal PR merges → user runs `/promote` to advance to large
- Epics and stories inform the sprintplan phase (next audience)
