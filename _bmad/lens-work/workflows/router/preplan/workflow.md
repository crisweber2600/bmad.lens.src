# /preplan Workflow

**Phase:** Router
**Purpose:** Execute the preplan phase — produce product briefs, research, and competitive analysis artifacts.
**Agent:** Mary (Analyst)
**Audience:** small

## Pre-conditions

- User is authenticated and onboarded
- Initiative exists with a track that includes `preplan`
- No predecessor phase required (preplan is the first phase)
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

1. Read `lifecycle.yaml` to confirm `preplan` is valid for this track
2. Derive current initiative and audience from branch via git-state
3. Validate no predecessor is required (preplan is always the first phase)
4. If valid: create phase branch `{initiative-root}-small-preplan` using git-orchestration
5. If track doesn't include preplan: report error with valid phases for this track

### Step 2: Prepare Initiative Context

Load the initiative config from `_bmad-output/lens-work/initiatives/{domain}/{service}/{feature}.yaml`:

- Initiative root, domain, service, feature
- Track type and enabled phases
- Any previous artifacts from earlier sessions

### Step 3: Delegate to Analyst Agent

Delegate artifact production to Mary (analyst agent):

```
## Product Brief — Generating...
```

**Artifacts to produce:**

| Artifact | Path | Required |
|----------|------|----------|
| Product Brief | `phases/preplan/product-brief.md` | Yes |
| Research | `phases/preplan/research.md` | Yes |
| Brainstorm | `phases/preplan/brainstorm.md` | Optional |

All artifacts are saved to: `_bmad-output/lens-work/initiatives/{domain}/{service}/phases/preplan/`

### Step 4: Progress Markers (Batch Mode)

Display batch progress markers per UX spec:

```
## Product Brief — Generating...
{artifact content}
## Product Brief — Complete ✅

## Research Report — Generating...
{artifact content}
## Research Report — Complete ✅
```

### Step 5: Commit Artifacts

Using git-orchestration skill:

1. Stage all artifacts in `phases/preplan/`
2. Commit with message: `[PREPLAN] {initiative-root} — preplan artifacts complete`
3. Push to remote (reviewable checkpoint)

### Step 6: Report Completion

```
✅ PrePlan phase complete

## Artifacts Produced
- product-brief.md ✅
- research.md ✅
- brainstorm.md ✅ (if produced)

## Next Step
The preplan artifacts are committed and pushed. When ready, your PR will be
created automatically for review. Then run `/businessplan` to continue.
```

## Error Handling

| Error | Response |
|-------|----------|
| Track doesn't include preplan | `❌ Track '{track}' does not include preplan. Valid phases: {phases}` |
| Not on initiative branch | `❌ Not on an initiative branch. Use /switch or /new-domain first.` |
| Already on a phase branch | `⚠️ Already on phase branch {branch}. Complete current phase first.` |
