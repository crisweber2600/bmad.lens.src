---
name: discover
description: "Discover cloned repos under TargetProjects, inspect for BMAD config, update governance inventory, create /switch branches"
agent: "@lens"
trigger: /discover command
aliases: [/disc]
category: router
phase_name: discover
display_name: Discover
imports: lifecycle.yaml
---

# /discover — Repo Discovery Workflow

**Purpose:** Given an active initiative, resolve the scan path from the initiative's domain and service, enumerate all cloned git repos under that path, inspect each for BMAD configuration presence, update the governance repo's `repo-inventory.yaml`, create `/switch` branches in the control repo, and yield a structured per-repo result set for downstream processing (ReportRenderer).

**Covers:** `/discover`

---

## Prerequisites

- [x] Active initiative exists (`_bmad-output/lens-work/initiatives/{domain}/{service}/{feature}.yaml`)
- [x] Initiative config contains `domain` and `service` fields
- [x] Governance repo path is resolvable (via `governance-setup.yaml`, `profile.yaml`, or directory scan)
- [x] User has cloned target repos into `TargetProjects/{domain}/{service}/`

---

## Step 0: Run Preflight

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

---

## Step 1: InitiativeContextResolver

**Epic:** E1 — Load initiative config and resolve scan path.

Resolve the active initiative's domain, service, governance path, and compute the scan path for repo discovery.

### 1a. Load Initiative Config

Load the active initiative config from the two-file state system:

```yaml
state = load("_bmad-output/lens-work/state.yaml")
initiative = load("_bmad-output/lens-work/initiatives/${state.active_initiative}.yaml")
```

Extract required fields:
- `domain` — the organizational domain (e.g., `bmad`)
- `service` — the service within the domain (e.g., `lens`)
- `initiative_root` — the full initiative root identifier

**Gate:** If the initiative config file is missing or does not contain `domain` and `service` fields:
```
❌ No active initiative found. Run `/new-service` first.
```
Hard stop — exit workflow.

### 1b. Construct Scan Path

Derive the scan path from the resolved domain and service:

```yaml
scan_path = "TargetProjects/${domain}/${service}/"
```

**Gate:** If `scan_path` directory does not exist on the filesystem:
```
❌ Scan path does not exist: TargetProjects/{domain}/{service}/
   Create this directory and clone your repos there, then run /discover again.
```
Hard stop — exit workflow.

### 1c. Resolve Governance Repo Path

Resolve the governance repo path using a three-level fallback chain:

1. **`governance-setup.yaml`** — read `governance_repo_path` field if file exists
2. **`profile.yaml`** — read `governance_repo_path` field from `_bmad-output/lens-work/personal/profile.yaml`
3. **Directory scan** — search for a directory containing `repo-inventory.yaml` under common governance paths:
   - `TargetProjects/{domain}/lens-governance/`
   - `TargetProjects/lens/lens-governance/`

**Gate:** If governance repo path cannot be resolved or the resolved directory does not exist:
```
❌ Governance repo not found. Run `/onboard` to configure the governance path.
```
Hard stop — exit workflow.

### 1d. Output Resolver Result

Emit the structured resolver result for downstream steps:

```yaml
resolver_result:
  domain: {domain}
  service: {service}
  scan_path: "TargetProjects/{domain}/{service}/"
  governance_repo_path: {governance_repo_path}
  initiative_root: {initiative_root}
```

Output to user:
```
✅ Initiative context resolved
   Domain:     {domain}
   Service:    {service}
   Scan path:  TargetProjects/{domain}/{service}/
   Governance: {governance_repo_path}
```

---

## Step 2: FileSystemScanner

**Epic:** E1 — Enumerate TargetProjects for git repos with incremental output.

Scan the resolved `scan_path` for all immediate child directories that contain a `.git/` directory.

### 2a. Enumerate Git Repos

Walk the immediate children of `scan_path`:

```
for each child_dir in list_directories(scan_path):
    if directory_exists(child_dir + "/.git/"):
        append child_dir to discovered_repos
        output: "✓ discovered: {basename(child_dir)}"   # incremental — AR-3
```

**Rules:**
- Immediate children only — do NOT recurse into subdirectories
- Predicate: `{child_dir}/.git/` must be a directory (not a file)
- Non-git subdirectories are **silently skipped** — no output, no error
- Each discovered repo is announced **immediately** as it is found (incremental output, not batched at the end) — AR-3 compliance

### 2b. Handle Empty Scan Result

If zero repos are discovered on the first scan:

```
No repos found in TargetProjects/{domain}/{service}/.

Clone your repos to `TargetProjects/{domain}/{service}/` and reply **done** when ready.
```

Wait for user signal.

**On "done" signal:** Re-scan using the same logic from Step 2a.

If re-scan still finds zero repos:
```
No repos found. Did you clone them to the right folder? Expected: TargetProjects/{domain}/{service}/
```

Exit workflow cleanly (exit 0 — not an error). Having no repos is a valid state.

### 2c. Emit Discovered Repo List

Pass the `discovered_repos` list (array of directory paths) to Step 3.

```yaml
discovered_repos:
  - path: "{scan_path}/{repo_name_1}"
    repo_name: "{repo_name_1}"
  - path: "{scan_path}/{repo_name_2}"
    repo_name: "{repo_name_2}"
```

---

## Step 3: RepoInspector

**Epic:** E1 — Detect BMAD configuration presence per discovered repo.

For each discovered repo directory, inspect for BMAD configuration presence and build the per-repo result set.

### 3a. Inspect Each Repo

For each `repo_dir` in the `discovered_repos` list:

```
for each repo in discovered_repos:
    try:
        has_bmad = directory_exists(repo.path + "/.bmad/")

        repo_result = {
            repo_name: repo.repo_name,
            path: repo.path,
            has_bmad: has_bmad,
            language: "unknown",
            error: null,
            governance_status: "pending",
            branch_status: "pending"
        }
    catch (error):
        # NFR-4: Per-repo error isolation — continue pipeline for remaining repos
        repo_result = {
            repo_name: repo.repo_name,
            path: repo.path,
            has_bmad: false,
            language: "unknown",
            error: error.message,
            governance_status: "pending",
            branch_status: "pending"
        }
        log: "⚠️ Error inspecting {repo.repo_name}: {error.message}"

    append repo_result to repo_results
```

**Rules:**
- Top-level `.bmad/` directory check only — does not recurse into `.bmad/`
- `language` field is `"unknown"` at MVP (enriched by E5 LanguageDetector when enabled)
- **Per-repo error isolation (NFR-4):** An error inspecting one repo must NOT abort inspection of remaining repos. The error is logged to the repo's result record and the pipeline continues.
- `governance_status` and `branch_status` start as `"pending"` — updated by Step 4 (GovernanceWriter) and Step 5 (GitOrchestrator) respectively

### 3b. Emit Result Set

```
📋 Inspection Complete
   Repos discovered:  {count}
   BMAD configured:   {bmad_count}
   Errors:            {error_count}
```

Pass `repo_results` to Step 4 (GovernanceWriter).

---

## Step 4: GovernanceWriter

**Epic:** E2 — Governance Integration. Update `repo-inventory.yaml` in the governance repo with discovered repo entries, with idempotency and zero-data-loss guarantees.

### 4a. Pull Governance Repo (NFR-3 — Mandatory Gate)

**HARD GATE:** Pull the governance repo BEFORE any read or write operation. This is a non-negotiable ordering constraint.

```bash
git -C {governance_repo_path} pull origin
```

**Gate:** If `git pull` fails:
```
❌ Failed to pull governance repo at {governance_repo_path}.
   Governance writes aborted — continuing with branch creation (Step 5).
   Run `/discover` again after fixing the governance repo.
```
- Set ALL repos in `repo_results` to `governance_status: "❌ Pull Failed"`
- **Skip ALL remaining governance operations** (Steps 4b–4f)
- Continue to Step 5 (GitOrchestrator) — governance pull failure does NOT abort the entire pipeline

### 4b. Read Existing Inventory

Read `repo-inventory.yaml` from the governance repo:

```yaml
inventory_path = "{governance_repo_path}/repo-inventory.yaml"
```

- If file exists: parse YAML and extract the `repos` section
- If file does not exist: initialize with empty structure:
  ```yaml
  # repo-inventory.yaml — governed by lens-governance
  repos: []
  ```

### 4c. Validate Schema (AR-5)

Before writing, validate the existing `repo-inventory.yaml` structure:

**Required schema:**
```yaml
repos:               # MUST be present (array or object with matched/missing/extra sections)
```

**Validation rules:**
- `repos` key must exist at the top level
- If `repos` is an array: each entry must have at minimum a `name` field
- If `repos` is an object with `matched`/`missing`/`extra` sections (legacy format): read entries from `repos.matched` array

**Gate:** If schema validation fails:
```
❌ repo-inventory.yaml has invalid schema.
   Expected: top-level `repos` key with array entries (each having `name` field)
   Found: {actual structure description}

   Fix the schema manually or back up and recreate the file.
   Governance writes aborted for this run.
```
- Set ALL repos to `governance_status: "❌ Schema Invalid"`
- Skip remaining governance operations
- Continue to Step 5

### 4d. Process Each Repo Entry (Per-Repo Isolation)

For each `repo_result` in `repo_results`:

```
for each repo in repo_results:
    if repo.error != null:
        # Skip repos that failed inspection — do not write errored entries
        repo.governance_status = "Skipped (inspection error)"
        continue

    try:
        # Normalize inventory access — handle both array and legacy object formats
        existing_entries = normalize_inventory(inventory)

        # Check if repo already exists in inventory by name
        existing = find_entry(existing_entries, where: entry.name == repo.repo_name)

        if existing != null:
            # NFR-2: Idempotency — prompt user before overwriting
            ask: |
                Repo "{repo.repo_name}" already exists in repo-inventory.yaml.

                Existing entry:
                  name: {existing.name}
                  domain: {existing.domain || "N/A"}
                  language: {existing.language || "N/A"}
                  bmad_configured: {existing.bmad_configured || "N/A"}

                Update with new discovery data? [Y/N]

            if user_response == "N" or user_response == "no":
                repo.governance_status = "Skipped"
                continue
            else:
                # Update existing entry in place
                update_entry(existing_entries, repo.repo_name, new_entry)
                repo.governance_status = "Updated"
        else:
            # New entry — append
            append_entry(existing_entries, new_entry)
            repo.governance_status = "Updated"

    catch (error):
        # Per-repo error isolation — failure on one repo does NOT abort remaining
        repo.governance_status = "❌ Failed"
        log: "⚠️ GovernanceWriter error for {repo.repo_name}: {error.message}"
        continue
```

**New entry schema:**
```yaml
- name: {repo.repo_name}
  path: {repo.path}
  language: {repo.language}
  bmad_configured: {repo.has_bmad}
  domain: {domain}           # from resolver_result
  service: {service}         # from resolver_result
  discovered_at: {ISO8601}   # current timestamp
```

### 4e. Write Updated Inventory

After processing all repos, write the updated inventory back to `repo-inventory.yaml`.

**Format decision:** Write using a flat `repos` array structure (the canonical v2 format):

```yaml
# repo-inventory.yaml — governed by lens-governance
repos:
  - name: "RepoA"
    path: "TargetProjects/domain/service/RepoA"
    language: "unknown"
    bmad_configured: true
    domain: "bmad"
    service: "lens"
    discovered_at: "2026-03-10T00:00:00Z"
  - name: "RepoB"
    path: "TargetProjects/domain/service/RepoB"
    language: "unknown"
    bmad_configured: false
    domain: "bmad"
    service: "lens"
    discovered_at: "2026-03-10T00:00:00Z"
```

**Rules:**
- Preserve any existing entries from OTHER domains/services that the user chose NOT to update
- Only modify entries that were newly discovered or explicitly approved for update
- Maintain YAML formatting consistency (2-space indent, quoted strings for values with special chars)

### 4f. Commit and Push Governance Update

After writing the updated `repo-inventory.yaml`:

```bash
cd {governance_repo_path}
git add repo-inventory.yaml
git commit -m "[discover] Add/update repos for {domain}/{service}"
git push origin
```

**Commit message:** `[discover] Add/update repos for {domain}/{service}` — includes initiative context for traceability.

**Push failure handling (non-fatal):**
If `git push` fails:
```
❌ Failed to push governance update to remote.
   Local commit preserved — run `/discover` again to retry the push.
```
- Set ALL repos processed in this batch to `governance_status: "❌ Push Failed"`
- Do NOT report success for any repo in this batch
- Continue to Step 5 — push failure does not abort the pipeline

**Push success:**
```
✅ Governance inventory updated
   Updated: {updated_count} repo(s)
   Skipped: {skipped_count} repo(s)
   Failed:  {failed_count} repo(s)
```

---

## Step 5: GitOrchestrator

**Epic:** E3 — Control Repo Branch Management. Create a control-repo branch per discovered repo to enable `/switch` navigation.

For each discovered repo, create a branch in the **control repo** (the BMAD.Lens workspace root) that enables the `/switch` command to navigate to that repo. Branch creation is idempotent and per-repo isolated.

### 5a. Resolve Control Repo Path

The control repo is the workspace root directory (the parent of `TargetProjects/`). All branch operations target this repo's git state.

```yaml
control_repo_path = workspace_root   # the BMAD.Lens directory
```

Verify the control repo is a valid git repository:

```bash
git -C {control_repo_path} rev-parse --is-inside-work-tree
```

**Gate:** If the control repo is not a git repository:
```
❌ Control repo at {control_repo_path} is not a git repository.
   Branch creation aborted — discovery results are still valid.
```
- Set ALL repos to `branch_status: "❌ No Control Repo"`
- Skip remaining branch operations
- Continue to pipeline completion

### 5b. Resolve Initiative Root Branch

Determine the base branch from which `/switch` branches are created:

```yaml
initiative_root_branch = resolver_result.initiative_root   # e.g., "bmad-lens-repodiscovery"
```

Verify the initiative root branch exists:

```bash
git -C {control_repo_path} rev-parse --verify "refs/heads/{initiative_root_branch}"
```

If the branch does not exist locally, attempt to fetch and track it:

```bash
git -C {control_repo_path} fetch origin "{initiative_root_branch}"
git -C {control_repo_path} branch "{initiative_root_branch}" "origin/{initiative_root_branch}"
```

**Gate:** If the initiative root branch cannot be resolved:
```
❌ Initiative root branch "{initiative_root_branch}" not found locally or on remote.
   Branch creation aborted — discovery results are still valid.
```
- Set ALL repos to `branch_status: "❌ Root Branch Missing"`
- Skip remaining branch operations
- Continue to pipeline completion

### 5c. Create Branches Per Repo (Per-Repo Isolation)

For each `repo_result` in `repo_results`:

```
for each repo in repo_results:
    if repo.error != null:
        # Skip repos that failed inspection — do not create branches for errored entries
        repo.branch_status = "Skipped (inspection error)"
        continue

    try:
        # Construct branch name from naming schema
        branch_name = "{initiative_root_branch}-{domain}-{service}-{repo.repo_name}"

        # Check if branch already exists (local or remote)
        local_exists = git -C {control_repo_path} rev-parse --verify "refs/heads/{branch_name}" 2>/dev/null
        remote_exists = git -C {control_repo_path} rev-parse --verify "refs/remotes/origin/{branch_name}" 2>/dev/null

        if local_exists or remote_exists:
            # Idempotent — branch already exists, skip without error
            output: "ℹ️ Branch already exists: {branch_name}"
            repo.branch_status = "Exists"
            continue

        # Create branch from initiative root
        git -C {control_repo_path} branch "{branch_name}" "{initiative_root_branch}"
        output: "✓ Branch created: {branch_name}"

        # Push branch to remote
        git -C {control_repo_path} push origin "{branch_name}"
        repo.branch_status = "Created"

    catch (error):
        # Per-repo error isolation — failure on one repo does NOT abort remaining
        repo.branch_status = "❌ Failed"
        log: "⚠️ GitOrchestrator error for {repo.repo_name}: {error.message}"
        continue
```

**Branch naming schema:**
```
{initiative_root_branch}-{domain}-{service}-{repo_name}
```

Example: `bmad-lens-repodiscovery-bmad-lens-bmad.lens.src`

**Rules:**
- Branch is created from `{initiative_root_branch}` — NOT from HEAD, master, or any other ref
- **Idempotent:** If the branch already exists (locally or on remote), skip with an informational notice — no error raised
- **Per-repo isolation:** A failure creating or pushing a branch for one repo does NOT abort branch creation for remaining repos
- Branch name uses hyphens as separators; repo names with dots are preserved as-is (no character substitution)

### 5d. Handle Push Failures (Non-Fatal)

If `git push` fails for a specific branch:

```
⚠️ Branch created locally but push failed: {branch_name}
   Run `/discover` again to retry the push.
```
- Set that repo's `branch_status` to `"❌ Push Failed"`
- Continue processing remaining repos — push failure is non-fatal

### 5e. Output Branch Summary

After processing all repos:

```
✅ /switch branches processed
   Created: {created_count}
   Existing: {existing_count}
   Skipped:  {skipped_count}
   Failed:   {failed_count}
```

**SC-3 Validation:** After Step 5 completes, the `/switch` command should successfully resolve all discovered repos via the created branches.

---

## Pipeline Data Contract

The result set produced by this workflow is consumed by downstream epics:

| Consumer | Epic | Fields Used |
|----------|------|-------------|
| ReportRenderer | E4/E5 | All fields |

**RepoResult schema:**
```yaml
repo_name: string         # directory basename
path: string              # full path from workspace root
has_bmad: boolean         # .bmad/ directory present
language: string          # "unknown" at MVP; enriched by E5
error: string | null      # null = no error; string = error message
governance_status: string # "pending" → "Updated" | "Skipped" | "❌ Failed" | "❌ Pull Failed" | "❌ Schema Invalid" | "❌ Push Failed"
branch_status: string     # "pending" → "Created" | "Exists" | "Skipped (inspection error)" | "❌ Failed" | "❌ Push Failed" | "❌ No Control Repo" | "❌ Root Branch Missing"
```

### Idempotency Guarantee (SC-4)

Running `/discover` twice with the same set of repos produces the same `repo-inventory.yaml` state after the user confirms each conflict prompt. No data is silently overwritten, no entries are duplicated, and no entries are lost. Branch creation is idempotent — existing branches are skipped without error.

### Error Isolation Summary

| Failure Point | Impact | Pipeline Continues? |
|---------------|--------|---------------------|
| Governance pull fails | All governance writes aborted | Yes — skip to Step 5 |
| Schema validation fails | All governance writes aborted | Yes — skip to Step 5 |
| Single repo write fails | That repo marked failed | Yes — next repo processed |
| Commit fails | All repos marked failed | Yes — skip to Step 5 |
| Control repo not found | All branch creation aborted | Yes — proceed to report |
| Root branch missing | All branch creation aborted | Yes — proceed to report |
| Single branch creation fails | That repo marked failed | Yes — next repo processed |
| Single branch push fails | That repo marked push-failed | Yes — next repo processed |
