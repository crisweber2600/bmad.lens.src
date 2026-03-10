---
name: discover
description: "Discover cloned repos under TargetProjects and build per-repo result set"
agent: "@lens"
trigger: /discover command
aliases: [/disc]
category: router
phase_name: discover
display_name: Discover
imports: lifecycle.yaml
---

# /discover — Repo Discovery Workflow

**Purpose:** Given an active initiative, resolve the scan path from the initiative's domain and service, enumerate all cloned git repos under that path, inspect each for BMAD configuration presence, and yield a structured per-repo result set for downstream processing (GovernanceWriter, GitOrchestrator, ReportRenderer).

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

**Story:** 1-1 — Load initiative config and resolve scan path.

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

**Story:** 1-2 — Enumerate TargetProjects for git repos with incremental output.

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
- Each discovered repo is announced **immediately** as it is found (incremental output, not batched at the end) — this is an AR-3 compliance requirement

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

Pass the `discovered_repos` list (array of absolute directory paths) to Step 3.

```yaml
discovered_repos:
  - path: "{scan_path}/{repo_name_1}"
    repo_name: "{repo_name_1}"
  - path: "{scan_path}/{repo_name_2}"
    repo_name: "{repo_name_2}"
```

---

## Step 3: RepoInspector

**Story:** 1-3 — Detect BMAD configuration presence per discovered repo.

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
- `language` field is set to `"unknown"` at MVP (enriched by E5 LanguageDetector when enabled)
- **Per-repo error isolation (NFR-4):** An error inspecting one repo (permissions, broken symlink, etc.) must NOT abort inspection of remaining repos. The error is logged to the repo's result record and the pipeline continues.
- `governance_status` and `branch_status` start as `"pending"` — updated by E2 GovernanceWriter and E3 GitOrchestrator respectively

### 3b. Emit Result Set

The `repo_results` array is the shared data structure passed through all subsequent steps (GovernanceWriter in E2, GitOrchestrator in E3, ReportRenderer in E4/E5).

```yaml
repo_results:
  - repo_name: "RepoA"
    path: "TargetProjects/{domain}/{service}/RepoA"
    has_bmad: true
    language: "unknown"
    error: null
    governance_status: "pending"
    branch_status: "pending"
  - repo_name: "RepoB"
    path: "TargetProjects/{domain}/{service}/RepoB"
    has_bmad: false
    language: "unknown"
    error: null
    governance_status: "pending"
    branch_status: "pending"
```

Output summary:
```
📋 Inspection Complete
   Repos discovered:  {count}
   BMAD configured:   {bmad_count}
   Errors:            {error_count}
```

Pass `repo_results` to downstream epics (E2: GovernanceWriter, E3: GitOrchestrator).

---

## Pipeline Data Contract

The result set produced by this workflow (E1) is consumed by:

| Consumer | Epic | Fields Used |
|----------|------|-------------|
| GovernanceWriter | E2 | `repo_name`, `path`, `has_bmad`, `language`, `domain`, `service` |
| GitOrchestrator | E3 | `repo_name`, `initiative_root`, `domain`, `service` |
| ReportRenderer | E4/E5 | All fields |

**RepoResult schema:**
```yaml
repo_name: string         # directory basename
path: string              # full path from workspace root
has_bmad: boolean         # .bmad/ directory present
language: string          # "unknown" at MVP; enriched by E5
error: string | null      # null = no error; string = error message
governance_status: string # "pending" → "Updated" | "Skipped" | "❌ Failed"
branch_status: string     # "pending" → "Created" | "Exists" | "❌ Failed"
```
