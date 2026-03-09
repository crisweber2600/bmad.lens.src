# /switch — Switch Initiative Workflow

**Phase:** Utility
**Purpose:** Safely switch to a different initiative's branch with dirty directory handling.

## Pre-conditions

- Control repo is a git repository
- At least one initiative exists (branches present)

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

### Step 1: Parse Arguments

If `/switch {initiative-name}` was provided:
- Store `{initiative-name}` as the target root.
- Proceed to Step 3.

If `/switch` was provided with no argument:
- Proceed to Step 2.

### Step 2: List All Initiative Roots

List all initiative roots by parsing branch names:

```bash
git branch --list | sed -E 's/-(small|medium|large|base)(-.*)?$//' | sort -u
```

Filter out non-initiative branches (main, develop, etc.).

Present as a numbered list:

```
📋 Active Initiatives:

1. foo-bar-auth
2. foo-car-api
3. baz-widget

Select initiative [1-3]:
```

Wait for user selection. Store selected root as `{initiative-root}`.

**Empty state:** If no initiative branches found:
```
ℹ️ No active initiatives found.
Run `/new-domain` or `/new-service` to create one.
```

### Step 3: Check for Uncommitted Changes

Using the git-orchestration skill, check for dirty working directory:

```bash
git status --porcelain
```

**If dirty (uncommitted changes):**

```
⚠️ Uncommitted changes detected on current branch `{current-branch}`:

{file-list}

Choose an action:
[c] Commit changes before switching
[s] Stash changes (restore later with `git stash pop`)
[a] Abort switch

Never silently discards work.
```

Wait for user response:

| Choice | Action |
|--------|--------|
| `c` | Prompt for commit message → `git add -A && git commit -m "{message}"` → continue |
| `s` | `git stash push -m "lens-switch: {current-branch}"` → continue |
| `a` | Abort switch, remain on current branch |

**If clean:** Proceed to Step 4.

### Step 4: Determine Target Branch

Determine which branch to checkout for the target initiative, using this priority:

1. **Active phase branch** — if an open PR exists from `{root}-{audience}-{phase}` → `{root}-{audience}`, checkout the phase branch (work in progress).

2. **Highest audience branch** — if no active phase branch, checkout the highest audience branch that exists:
   - `{root}-base` > `{root}-large` > `{root}-medium` > `{root}-small`

3. **User-specified phase** — if user provided `{root}-{phase}`, checkout `{root}-{audience}-{phase}` directly.

**Multiple candidates:**
```
📋 Multiple branches found for `{root}`:

1. foo-bar-auth-small-techplan (active phase — open PR)
2. foo-bar-auth-small
3. foo-bar-auth-medium

Select branch [1-3]:
```

**New initiative (no phase started):**
- Checkout `{root}-small`
- Next action recommendation: `/preplan` (or track's start_phase)

### Step 5: Execute Checkout

```bash
git checkout {target-branch}
```

### Step 6: Load Initiative Config

Read the initiative config from the now-checked-out branch:

```bash
cat _bmad-output/lens-work/initiatives/{domain}/[{service}/]{feature}.yaml
```

Parse: initiative name, domain, service, track, language, created date.

### Step 7: Display Context Header

```
✅ Switched to initiative `{initiative-root}`
🏷️ Track: {track}
📋 Phase: {current-phase}
👥 Audience: {audience}

▶️ {next-action-recommendation}
```

Where `{next-action-recommendation}` is derived from lifecycle state:
- Phase in progress → "Continue working on `/{phase}`"
- Phase complete, no PR → "Create PR for `{phase}`"
- Between phases → "Run `/{next-phase}` to start the next phase"
- Track complete → "Run `/promote` to promote to `{next-audience}`"

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Dirty working directory | Prompt: commit, stash, or abort — **never silently discard** |
| Initiative branch deleted | Report error: "Initiative `{name}` not found." Suggest `git branch --list`. |
| Multiple checkout candidates | Present options as numbered list |
| New initiative (no phase started) | Checkout `{root}-small`, recommend `/{start-phase}` |
| User specifies non-existent branch | Report error with available branches for that initiative |

## NFR Compliance

- **NFR2:** Consistent working tree state on every switch — no partial state or stale configs. Branch IS the state.
