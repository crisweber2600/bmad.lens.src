---
name: discover
description: "Discover cloned repos under TargetProjects, inspect for BMAD config, update governance inventory, create /switch branches, and report results"
agent: "@lens"
trigger: /discover command
aliases: [/disc]
category: router
phase_name: discover
display_name: Discover
imports: lifecycle.yaml
---

# /discover — Repo Discovery Workflow

**Purpose:** Given an active initiative, resolve the scan path from the initiative's domain and service, enumerate all cloned git repos under that path, inspect each for BMAD configuration presence, detect primary programming language, update the governance repo's `repo-inventory.yaml`, create `/switch` branches in the control repo, generate project context files, update initiative language, and produce a human-readable discovery report.

**Covers:** `/discover`

**Processing model:** Sequential per-repo processing. Rationale (TD-006 / AR-4): with ≤10 repos at agent-interactive pace, parallel processing never approaches the 1-hour session budget (NFR-1). Sequential flow yields simpler error isolation, deterministic output ordering, and easier debugging — the performance cost is negligible for the expected workload.

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
            context_status: "pending",
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
            context_status: "pending",
            governance_status: "pending",
            branch_status: "pending"
        }
        log: "⚠️ Error inspecting {repo.repo_name}: {error.message}"

    append repo_result to repo_results
```

**Rules:**
- Top-level `.bmad/` directory check only — does not recurse into `.bmad/`
- `language` field is `"unknown"` initially — enriched by Step 3.5 (LanguageDetector) if enabled
- **Per-repo error isolation (NFR-4):** An error inspecting one repo must NOT abort inspection of remaining repos. The error is logged to the repo's result record and the pipeline continues.
- `governance_status` and `branch_status` start as `"pending"` — updated by Step 4 (GovernanceWriter) and Step 5 (GitOrchestrator) respectively

### 3b. Emit Result Set

```
📋 Inspection Complete
   Repos discovered:  {count}
   BMAD configured:   {bmad_count}
   Errors:            {error_count}
```

Pass `repo_results` to Step 3.5 (LanguageDetector).

---

## Step 3.5: LanguageDetector

**Epic:** E5 — NTH Enhancements. Detect the primary programming language of each discovered repo.

For each repo in `repo_results`, detect the primary programming language using the priority order defined in `lifecycle.yaml`. This step enriches the `language` field from `"unknown"` to an actual language identifier. Detection failure is **never fatal** — the fallback is always `"unknown"` (AR-1 DoD, SC-5).

### 3.5a. Check Enable Flag

LanguageDetector is an NTH enhancement. Check whether it is enabled:

- If `lifecycle.yaml` contains `language_detection: disabled` or the `supported_languages` list is empty: skip this step entirely, leave all `language` fields as `"unknown"`, and proceed to Step 4.
- Otherwise (default): proceed with detection.

### 3.5b. Detect Language Per Repo

For each `repo_result` in `repo_results`:

```
for each repo in repo_results:
    if repo.error != null:
        # Skip repos that failed inspection
        continue

    try:
        language = detect_language(repo.path)
        repo.language = language
        output: "  🔍 {repo.repo_name}: {language}"
    catch (error):
        # AR-1 + SC-5: NEVER throw — fallback to "unknown"
        repo.language = "unknown"
        log: "⚠️ Language detection failed for {repo.repo_name}: {error.message} — defaulting to unknown"
```

**`detect_language(repo_dir)` priority order** (from `lifecycle.yaml` comments):

1. **Explicit override:** Read `{repo_dir}/.bmad/language` file. If it exists and contains a non-empty string matching `lifecycle.yaml.supported_languages`, return that value.

2. **Build file heuristics:** Check for known build files in the repo root:

   | Build File | Language |
   |---|---|
   | `package.json` | `typescript` (if `tsconfig.json` also present) or `javascript` |
   | `*.csproj` or `*.sln` | `csharp` |
   | `pyproject.toml` or `setup.py` or `requirements.txt` | `python` |
   | `go.mod` | `go` |
   | `pom.xml` or `build.gradle` | `java` |
   | `Cargo.toml` | `rust` |
   | `*.gemspec` | `ruby` |
   | `composer.json` | `php` |
   | `Package.swift` | `swift` |
   | `build.gradle.kts` | `kotlin` |
   | `CMakeLists.txt` or `Makefile` (with `.cpp`/`.cc`/`.h` files) | `cpp` |

   If multiple build files match different languages, pick the first match in the table order above.

3. **File extension frequency analysis:** Count source files by extension in the repo (excluding `node_modules/`, `.git/`, `vendor/`, `bin/`, `obj/`). Map extensions to languages:

   | Extension(s) | Language |
   |---|---|
   | `.ts`, `.tsx` | `typescript` |
   | `.js`, `.jsx`, `.mjs` | `javascript` |
   | `.cs` | `csharp` |
   | `.py` | `python` |
   | `.go` | `go` |
   | `.java` | `java` |
   | `.rs` | `rust` |
   | `.rb` | `ruby` |
   | `.php` | `php` |
   | `.kt`, `.kts` | `kotlin` |
   | `.swift` | `swift` |
   | `.cpp`, `.cc`, `.cxx`, `.h`, `.hpp` | `cpp` |

   Return the language with the highest file count. If tied, return the first alphabetically.

4. **Fallback:** Return `"unknown"`.

**Rules:**
- Never throws — all exceptions caught, fallback to `"unknown"` (AR-1 DoD)
- Return value must match an entry in `lifecycle.yaml.supported_languages` or be `"unknown"`
- If `.bmad/language` contains a value NOT in `supported_languages`, log a warning and proceed to build file heuristics
- Multi-language repos: note `"multi-language repo"` in detection log but return the dominant language

### 3.5c. Emit Language Summary

```
🔍 Language Detection Complete
   Detected:  {detected_count} repo(s)
   Unknown:   {unknown_count} repo(s)
```

Pass enriched `repo_results` to Step 4 (GovernanceWriter).

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
- Continue to Step 6 (DiscoveryReport)

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
- Continue to Step 6 (DiscoveryReport)

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

---

## Step 5.5: ContextGenerator

**Epic:** E5 — NTH Enhancements. Delegate `project-context.md` generation per discovered repo.

For each discovered repo, delegate context file generation to the `bmad-bmm-generate-project-context` workflow. This provides AI agents with initial codebase context from day one.

### 5.5a. Check Enable Flag

ContextGenerator is an NTH enhancement. It runs only when enabled:

- If `lifecycle.yaml` contains `context_generation: disabled`: skip this step entirely and proceed to Step 5.7.
- Otherwise (default): proceed with generation.

### 5.5b. Generate Context Per Repo

For each `repo_result` in `repo_results`:

```
for each repo in repo_results:
    if repo.error != null:
        # Skip repos that failed inspection
        repo.context_status = "Skipped (inspection error)"
        continue

    try:
        # Delegate to bmad-bmm-generate-project-context workflow
        result = invoke_workflow("bmad-bmm-generate-project-context", {
            repo_path: repo.path,
            domain: resolver_result.domain,
            service: resolver_result.service
        })

        if result.success:
            repo.context_status = "Generated"
            output: "✓ Context generated: {repo.repo_name}"
        else:
            repo.context_status = "❌ Failed"
            log: "⚠️ Context generation failed for {repo.repo_name}: {result.error}"

    catch (error):
        # Per-repo error isolation — non-fatal
        repo.context_status = "❌ Failed"
        log: "⚠️ ContextGenerator error for {repo.repo_name}: {error.message}"
        continue
```

**Rules:**
- Per-repo failure is **non-fatal** — failure for one repo does NOT abort remaining repos
- `project-context.md` is written to `{repo.path}/.bmad/` (or repo root per workflow contract)
- The `bmad-bmm-generate-project-context` workflow handle is resolved from module registry

### 5.5c. Output Context Summary

```
📝 Context Generation Complete
   Generated: {generated_count} repo(s)
   Skipped:   {skipped_count} repo(s)
   Failed:    {failed_count} repo(s)
```

---

## Step 5.7: StateManager — Language Update

**Epic:** E5 — NTH Enhancements. Update the initiative config's `language` field based on LanguageDetector results.

After all repos have been processed, determine whether a consensus language exists and update the initiative config accordingly.

### 5.7a. Check Prerequisites

- If LanguageDetector was skipped (Step 3.5 disabled): skip this step entirely.
- If all repos have `language: "unknown"`: skip — leave initiative config unchanged.

### 5.7b. Determine Consensus Language

```
# Collect detected languages (exclude "unknown")
detected_languages = [repo.language for repo in repo_results if repo.language != "unknown"]

if len(detected_languages) == 0:
    # All unknown — nothing to update
    skip to Step 6

# Count occurrences
language_counts = count_by_value(detected_languages)
top_language = max(language_counts, key=count)

if all values in detected_languages are the same:
    # Unanimous — update automatically
    consensus = top_language
    auto_update = true
else:
    # Mixed languages — prompt user
    ask: |
        Multiple languages detected across repos:
        {for lang, count in language_counts sorted by count desc:
            "  {lang}: {count} repo(s)"}

        Update initiative language to "{top_language}" (most common)? [Y/N]

    if user_response == "Y" or user_response == "yes":
        consensus = top_language
    else:
        consensus = null  # user declined
```

### 5.7c. Update Initiative Config

If `consensus` is determined:

```yaml
# Read initiative config
config = load("_bmad-output/lens-work/initiatives/{initiative_path}.yaml")

# Update language field
config.language = consensus

# Write back
save(config, "_bmad-output/lens-work/initiatives/{initiative_path}.yaml")

output: "✅ Initiative language updated to: {consensus}"
```

If user declined or no consensus:
```
output: "ℹ️ Initiative language left as: {current_value || 'unknown'}"
```

**Rules:**
- Never overwrites an explicitly set language without user confirmation
- The updated config is written to `_bmad-output/` (control repo state), not committed to git automatically
- Mixed-language scenarios always prompt — no silent majority-wins

---

## Step 6: DiscoveryReport

**Epic:** E4 + E5 — Produce a human-readable summary table of all discovery results, including NTH enrichments.

After all per-repo processing is complete (Steps 1–5.7), render a consolidated discovery report table and provide navigation guidance.

### 6a. Build Report Table

Construct a markdown table from the accumulated `repo_results`:

```markdown
## 📋 Discovery Report

| Repo | Language | BMAD | Context | Governance | Branch |
|------|----------|------|---------|------------|--------|
```

For each `repo_result` in `repo_results`:

```
for each repo in repo_results:
    # Determine row prefix — error rows get ⚠️
    prefix = ""
    if repo.error != null or repo.governance_status starts with "❌" or repo.branch_status starts with "❌":
        prefix = "⚠️ "

    # Format BMAD column
    bmad_display = repo.has_bmad ? "✅" : "❌"

    # Format Context column (NTH — E5)
    context_display = format_context_status(repo.context_status)  # "Generated" / "Skipped" / "Failed" / "N/A" (if disabled)

    # Format Governance column
    governance_display = format_governance_status(repo.governance_status)

    # Format Branch column
    branch_display = format_branch_status(repo)

    # Emit row
    output: "| {prefix}{repo.repo_name} | {repo.language} | {bmad_display} | {context_display} | {governance_display} | {branch_display} |"
```

**Column formatting rules:**

| Column | Values |
|--------|--------|
| Repo | Repo name; prefixed with ⚠️ if any error exists |
| Language | Detected language identifier or `unknown` (from LanguageDetector Step 3.5) |
| BMAD | ✅ if `.bmad/` present, ❌ otherwise |
| Context | `Generated` / `Skipped` / `Failed` / `N/A` (if ContextGenerator disabled) |
| Governance | `Updated` / `Skipped` / `Skipped (user)` / `Failed` / `Pull Failed` / `Schema Invalid` / `Push Failed` |
| Branch | Branch name if created, `Exists` if already present, `Failed` / `Push Failed` if error |

### 6b. Render Summary Counts

Below the table, display aggregate counts:

```
### Summary

- **Discovered:** {total_count} repo(s)
- **BMAD configured:** {bmad_count} repo(s)
- **Languages detected:** {language_detected_count} / unknown: {language_unknown_count}
- **Context generated:** {context_generated_count} / skipped: {context_skipped_count} / failed: {context_failed_count}
- **Governance updated:** {governance_updated_count} / skipped: {governance_skipped_count} / failed: {governance_failed_count}
- **Branches created:** {branch_created_count} / existing: {branch_existing_count} / failed: {branch_failed_count}
- **Errors:** {error_count} repo(s) had inspection errors
```

### 6c. Render Next Steps

After the summary, provide a "What next?" nudge:

```
### What next?

You can now use `/switch` to navigate to any discovered repo.

Other useful commands:
- `/status` — see current initiative state
- `/next` — get recommended next action
```

### 6d. Handle Empty Results

If `repo_results` is empty (zero repos discovered after Step 2b):

```
## 📋 Discovery Report

No repos were discovered in TargetProjects/{domain}/{service}/.

Clone your repos and run `/discover` again.
```

Skip the table and summary counts.

---

## Pipeline Data Contract

The result set produced by this workflow is the final output — there are no further downstream consumers at MVP.

**RepoResult schema:**
```yaml
repo_name: string         # directory basename
path: string              # full path from workspace root
has_bmad: boolean         # .bmad/ directory present
language: string          # detected language or "unknown" (from LanguageDetector)
error: string | null      # null = no error; string = error message
context_status: string    # "pending" → "Generated" | "Skipped" | "Skipped (inspection error)" | "❌ Failed" | "N/A" (if disabled)
governance_status: string # "pending" → "Updated" | "Skipped" | "Skipped (user)" | "Skipped (inspection error)" | "❌ Failed" | "❌ Pull Failed" | "❌ Schema Invalid" | "❌ Push Failed"
branch_status: string     # "pending" → "Created" | "Exists" | "Skipped (inspection error)" | "❌ Failed" | "❌ Push Failed" | "❌ No Control Repo" | "❌ Root Branch Missing"
```

### Idempotency Guarantee (SC-4)

Running `/discover` twice with the same set of repos produces the same `repo-inventory.yaml` state after the user confirms each conflict prompt. No data is silently overwritten, no entries are duplicated, and no entries are lost. Branch creation is idempotent — existing branches are skipped without error.

### Error Isolation Summary

| Failure Point | Impact | Pipeline Continues? |
|---------------|--------|---------------------|
| Initiative config missing | Workflow aborted | No — hard stop |
| Scan path missing | Workflow aborted | No — hard stop |
| Governance repo missing | Workflow aborted | No — hard stop |
| Zero repos found | Clean exit after user prompt | No — exit 0 |
| Governance pull fails | All governance writes aborted | Yes — skip to Step 5 |
| Schema validation fails | All governance writes aborted | Yes — skip to Step 5 |
| Single repo write fails | That repo marked failed | Yes — next repo processed |
| Governance commit fails | All repos marked failed | Yes — skip to Step 5 |
| Governance push fails | All repos marked push-failed | Yes — skip to Step 5 |
| Control repo not found | All branch creation aborted | Yes — skip to Step 6 |
| Root branch missing | All branch creation aborted | Yes — skip to Step 6 |
| Single branch creation fails | That repo marked failed | Yes — next repo processed |
| Single branch push fails | That repo marked push-failed | Yes — next repo processed |
| Language detection fails (single repo) | That repo stays `unknown` | Yes — next repo processed |
| Language detection fails (all repos) | All repos stay `unknown` | Yes — skip StateManager |
| ContextGenerator delegation fails (single repo) | That repo marked context-failed | Yes — next repo processed |
| ContextGenerator workflow not found | All repos marked N/A | Yes — skip to Step 5.7 |
| StateManager consensus declined | Initiative config unchanged | Yes — continue to Step 6 |
