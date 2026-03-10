# /discover Workflow

**Phase:** Router
**Purpose:** Post-clone repo detection — scan TargetProjects for cloned repos, update governance inventory, create `/switch` branches.
**Agent:** @lens
**Audience:** dev (execution phase)

> **Sequential processing rationale (TD-006):** Sequential chosen over parallel — ≤10 repos at agent pace never approaches the 1-hour budget (NFR-1); simpler error isolation; deterministic user prompts for governance conflicts.

## Pre-conditions

- User is authenticated and onboarded
- Initiative exists with `current_phase: complete` and `lifecycle_status: ready-for-execution`
- Governance repo is cloned and accessible
- At least one repo is expected to be cloned in `TargetProjects/{domain}/{service}/`

## Steps

### Step 0: Run Preflight

Run preflight before executing this workflow:

1. Determine the `bmad.lens.release` branch using `git -C bmad.lens.release branch --show-current`.
2. If branch is `alpha` or `beta`: run **full preflight** — pull ALL authority repos now (do NOT check `.preflight-timestamp` — ALWAYS pull on alpha/beta):
   ```bash
   git -C bmad.lens.release pull origin
   git -C .github pull origin
   git -C {governance_repo_path} pull origin   # path from governance-setup.yaml
   ```
   Then write today's date to `_bmad-output/lens-work/.preflight-timestamp`.
3. Otherwise: read `_bmad-output/lens-work/.preflight-timestamp`. If missing or older than today, run the same three `git pull` commands above and update the timestamp. If today's date matches, skip pulls.
4. If any authority repo directory is missing: stop and return the preflight failure message.

---

### Step 1: InitiativeContextResolver (S1.1)

Resolve the active initiative's domain and service to determine the scan path and governance repo.

#### 1.1 Load Active Initiative Config

1. Identify the active initiative. The initiative slug is derived from the current lens-work state:
   - Read `_bmad-output/lens-work/initiatives/` to find the active initiative directory
   - Load: `_bmad-output/lens-work/initiatives/{domain}/{service}/repodiscovery.yaml`
   - Parse the YAML and extract: `domain`, `service`, `initiative_root`

2. **If initiative config is missing or malformed:**
   ```
   ❌ No active initiative found. Run `/new-service` first.
   ```
   **→ STOP. Do not continue.**

#### 1.2 Construct Scan Path

```
scan_path = TargetProjects/{domain}/{service}/
```

Verify the scan path directory exists. If not:
```
❌ Scan path not found: TargetProjects/{domain}/{service}/
Run `/new-service` to set up the target project structure.
```
**→ STOP.**

#### 1.3 Load Governance Repo Path

1. Check for `_bmad-output/lens-work/governance-setup.yaml`
   - If present: read `governance_repo_path` field
2. If `governance-setup.yaml` is missing: check `_bmad-output/lens-work/personal/profile.yaml` for governance path
3. If governance path is still not found, scan `TargetProjects/` for a directory containing `repo-inventory.yaml` as a fallback

4. Validate: the resolved governance directory exists AND contains a `.git/` subdirectory

5. **If governance repo path is missing or directory does not exist:**
   ```
   ❌ Governance repo not found. Run `/onboard` to configure the governance path.
   ```
   **→ STOP.**

#### 1.4 Output

```
✅ Initiative context resolved
   Domain:     {domain}
   Service:    {service}
   Scan path:  TargetProjects/{domain}/{service}/
   Governance: {governance_repo_path}
```

**Resolver result:** `{ domain, service, scan_path, governance_repo_path, initiative_root }`

---

### Step 2: FileSystemScanner (S1.2)

Enumerate all direct child directories of the scan path that contain a `.git/` directory.

#### 2.1 Scan for Git Repos

1. List all immediate child directories of `{scan_path}`
2. For each child directory: check if `{child}/.git/` exists (directory, not file)
3. Add matching directories to the discovered repos list
4. **Non-git subdirectories are silently skipped** (no output, no error)

#### 2.2 Incremental Output (AR-3)

As each repo is discovered, output immediately (do NOT batch):

```
✓ discovered: {repo_name}
```

#### 2.3 Handle Empty Scan

If zero repos found on first scan:

```
No repos found in {scan_path}.
Clone your repos to `{scan_path}` and reply **done** when ready.
```

**Wait for user response.**

On "done" signal: re-scan the same path.

If still zero:
```
No repos found. Did you clone them to the right folder?
Expected: {scan_path}
```
**→ EXIT cleanly (not an error — user may not have cloned yet).**

#### 2.4 Output

List of absolute directory paths, one per discovered repo.

---

### Step 3: RepoInspector (S1.3)

Inspect each discovered repo for BMAD configuration presence.

#### 3.1 Inspect Each Repo

For each `repo_dir` in the discovered repos list:

1. Check for presence of `.bmad/` directory at `{repo_dir}/.bmad/`
2. Set `has_bmad: true` if `.bmad/` directory exists, `has_bmad: false` otherwise
3. **Error accessing repo_dir** (permissions, broken symlink, etc.):
   - Log error to the repo's result record
   - **Continue pipeline for remaining repos** (NFR-4: per-repo error isolation)

#### 3.2 Build Result Set

For each repo, construct a result object:

```yaml
repo_name: "{directory_name}"
path: "{absolute_path}"
has_bmad: true|false
language: "unknown"   # Placeholder — enriched by LanguageDetector (E5/NTH) when enabled
error: null|"{error_message}"
governance_status: "pending"
branch_status: "pending"
```

**Pipeline continues for ALL repos regardless of individual inspection failures.**

---

### Step 4: GovernanceWriter — Pull Gate (S2.1)

Pull the governance repo before performing any writes.

#### 4.1 Pull Governance Repo

Execute:
```bash
git -C {governance_repo_path} pull origin
```

#### 4.2 Handle Pull Failure

If `git pull` fails:

```
❌ Governance pull failed — inventory not updated. Fix connectivity and retry.
```

**→ Skip ALL governance writes for this run.** Mark all repos as `governance_status: "pull failed"`.

**→ Continue to Step 7 (Branch Management)** — governance failure does not block branch creation.

#### 4.3 Confirm Pull Success

```
✅ Governance repo pulled successfully
```

---

### Step 5: GovernanceWriter — Schema Validation + Idempotent Upsert (S2.2, S2.3)

Validate the governance inventory schema, then upsert entries for each discovered repo.

#### 5.1 Read Current Inventory

Read `{governance_repo_path}/repo-inventory.yaml`.

**If file does not exist:** Initialize with empty valid schema:
```yaml
# repo-inventory.yaml — governed by lens-governance
repos: []
```

#### 5.2 Validate Schema

Validate `repo-inventory.yaml` has the expected structure:
- Top-level `repos` key (array)
- Each entry has fields: `name`, `domain`, `service`, `language`, `bmad_configured`, `discovered_at`

**If current file has a different schema** (e.g., the legacy `matched`/`missing`/`extra` format):
- Inform the user of the schema difference:
  ```
  ⚠️ repo-inventory.yaml uses a different schema than expected.
  Current: {describe current structure}
  Expected: flat `repos:` array with per-repo entries
  
  Options:
  [M]igrate — Convert existing entries to new schema (preserves data)
  [S]kip — Skip governance writes for this run
  ```
- On **M**: Extract repo entries from current format, convert to new schema, proceed with upsert
- On **S**: Mark all repos as `governance_status: "skipped (schema)"`, continue to Step 7

#### 5.3 Idempotent Upsert

For each discovered repo in the result set:

1. Check if `repo_name` already exists in the inventory `repos` array
2. **If existing entry found:**
   ```
   Repo "{repo_name}" already in inventory. Update? [Y/N]
   ```
   - **Y** → Overwrite entry with latest discovered data
   - **N** → Skip; mark as `governance_status: "skipped (user)"`
3. **If new entry:** Insert without prompt

Entry fields to write:
```yaml
- name: "{repo_name}"
  path: "TargetProjects/{domain}/{service}/{repo_name}"
  domain: "{domain}"
  service: "{service}"
  language: "unknown"
  bmad_configured: true|false
  discovered_at: "{ISO-8601 timestamp}"
```

**Per-repo failure:** If upserting a single repo fails, log the error to that repo's result record and continue with remaining repos.

---

### Step 6: GovernanceWriter — Commit + Push (S2.4)

Commit and push all governance inventory changes.

#### 6.1 Commit Changes

```bash
cd {governance_repo_path}
git add repo-inventory.yaml
git commit -m "[{initiative_id}] /discover: update repo-inventory ({N} entries) — {ISO-8601-timestamp}"
```

Where:
- `{initiative_id}` = initiative root (e.g., `bmad-lens-repodiscovery`)
- `{N}` = number of repos added or updated
- `{ISO-8601-timestamp}` = current UTC timestamp

#### 6.2 Push to Remote

```bash
git -C {governance_repo_path} push origin
```

**If push fails:**
```
❌ Push failed — governance inventory updated locally but not pushed.
Run `/discover` again to retry push.
```
Mark all repos in this batch as `governance_status: "push failed"`.

**If push succeeds:**
Mark updated repos as `governance_status: "updated"`.

---

### Step 7: GitOrchestrator — Create /switch Branches (S3.1)

Create a control-repo branch for each discovered repo using the standard naming schema.

#### 7.1 Branch Naming Convention

```
{initiative_root}-{domain}-{service}-{repo_name}
```

Example: `bmad-lens-repodiscovery-bmad-lens-NorthStarET.Lms`

#### 7.2 Create Branches

For each discovered repo:

1. Construct branch name: `{initiative_root}-{domain}-{service}-{repo_name}`
2. Check if branch already exists:
   ```bash
   git branch --list "{branch_name}"
   ```
3. **If branch already exists:** Skip with notice:
   ```
   Branch already exists: {branch_name}
   ```
   Mark as `branch_status: "exists"`.

4. **If branch does not exist:** Create from current initiative root branch:
   ```bash
   git branch {branch_name} {initiative_root}-base
   ```
   Mark as `branch_status: "created"`.

5. **Push branch to remote:**
   ```bash
   git push origin {branch_name}
   ```
   **If push fails:** Mark as `branch_status: "push failed"` — non-fatal, continue.

**Per-repo:** Branch creation failure for one repo does NOT abort remaining repos.

---

### Step 8: Discovery Report (S4.2)

Render the final discovery report table after all repos are processed.

#### 8.1 Report Table

```
📋 Discovery Report

| Repo | Language | BMAD | Governance | Branch |
|------|----------|------|------------|--------|
```

For each repo in the result set, add a row:

| Column | Values |
|---|---|
| Repo | `{repo_name}` — prefix with ⚠️ if any error occurred |
| Language | `unknown` (MVP — enriched by E5 LanguageDetector when enabled) |
| BMAD | ✅ if `has_bmad: true`, ❌ if `has_bmad: false` |
| Governance | `updated` / `skipped (user)` / `skipped (schema)` / `failed` / `pull failed` / `push failed` |
| Branch | branch name / `exists` / `push failed` / `failed` |

#### 8.2 Summary

```
{n} repo(s) discovered and registered.
```

#### 8.3 What Next Nudge

```
## What Next?
You can now use `/switch` to navigate to any discovered repo.
```

---

## Error Handling

| Failure Point | Handling | User Visible |
|---|---|---|
| Initiative config missing/malformed | Hard stop with actionable message | Yes — "Run `/new-service` first" |
| Scan path does not exist | Hard stop with actionable message | Yes — "Run `/new-service`" |
| Governance repo missing | Hard stop with actionable message | Yes — "Run `/onboard`" |
| Governance `git pull` fails | Skip governance writes; continue with branches | Yes — report table |
| Governance schema mismatch | Prompt user: Migrate or Skip | Yes — interactive |
| Governance `git push` fails | Report ❌; inventory updated locally | Yes — report table |
| Single repo inspection error | Log to result; continue pipeline | Yes — ⚠️ in report |
| Branch creation fails | Log to result; continue remaining repos | Yes — report table |
| Zero repos found (after re-scan) | Clean exit with friendly message | Yes |

**Principle:** No silent failures. Every failure is represented in the discovery report or in preflight output.

---

## NTH Extension Points (E5 — deferred)

The following extension points are architecturally defined but **not active at MVP**. When enabled via lifecycle config flags, they integrate into the pipeline at the indicated positions:

| Extension | Insert After | Purpose |
|---|---|---|
| **LanguageDetector** (S5.1) | Step 3 (RepoInspector) | Detect primary language per repo; populate `language` field in result set |
| **ContextGenerator** (S5.2) | Step 7 (Branch Management) | Delegate `project-context.md` generation per repo |
| **StateManager** (S5.3) | Step 7 (Branch Management) | Update initiative config `language` field if consensus detected |

These extensions follow the same per-repo error isolation pattern: failure is non-fatal, logged to result, pipeline continues.
