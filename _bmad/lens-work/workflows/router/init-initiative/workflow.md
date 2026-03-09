# /new-domain, /new-service, /new-feature — Init Initiative Workflow

**Phase:** Router
**Purpose:** Create a new initiative with proper branch topology, validated naming, and cross-initiative sensing.
**Covers:** `/new-domain`, `/new-service`, `/new-feature`

## Pre-conditions

- User is authenticated and onboarded (`profile.yaml` exists)
- Control repo is a git repository with a remote configured
- `lifecycle.yaml` is accessible in the lens-work module

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

### Step 1: Determine Scope and Collect Parameters

Read the command to determine scope. Each command ONLY collects the parameters for its scope level — do NOT collect parameters beyond what is listed:

| Command | Scope | Collected Parameters |
|---------|-------|---------------------|
| `/new-domain` | domain | domain name |
| `/new-service` | service | service name (domain from context or ask) |
| `/new-feature` | feature | feature name, track (domain + service from context or ask) |

**Collection rules per scope:**

**`/new-domain {name}`:**
1. Domain name — the provided argument (or ask if missing)
2. Do NOT collect track, service, or feature names
3. Domains are organizational containers with no lifecycle phases — track does not apply

**`/new-service {name}`:**
1. Domain — derive from current branch context, or ask if not on a domain branch
2. Service name — the provided argument (or ask if missing)
3. Do NOT collect track or feature name
4. Services are organizational containers with no lifecycle phases — track does not apply

**`/new-feature {name}`:**
1. Domain + Service — derive from current branch context, or ask if not available
2. Feature name — the provided argument (or ask if missing)
3. Track — present track options

Collect missing parameters from the user. **Track selection applies only to feature scope** (domain and service scopes skip this). Present track options from `lifecycle.yaml` for feature scope:

| Track | Description | Phases |
|-------|-------------|--------|
| `full` | Complete lifecycle — all phases, all audiences | preplan → businessplan → techplan → devproposal → sprintplan |
| `feature` | Known business context — skip research | businessplan → techplan → devproposal → sprintplan |
| `tech-change` | Pure technical change | techplan → sprintplan |
| `hotfix` | Urgent fix — minimal planning | techplan |
| `spike` | Research only — no implementation | preplan |
| `quickdev` | Rapid execution — delegates to target agents | devproposal |

### Step 2: Validate Names (Slug-Safe Enforcement)

Apply slug-safe validation to all name components (domain, service, feature):

**Rules:**
- Normalize each component by lowercasing and removing non-alphanumeric characters
- Resulting component must contain lowercase letters and digits only (`a-z0-9`)
- 2-50 characters length
- Must not conflict with reserved tokens: `small`, `medium`, `large`, `base`
- Must not conflict with phase names: `preplan`, `businessplan`, `techplan`, `devproposal`, `sprintplan`, `dev`

**Normalization examples:**
- `TheNext one` -> `thenextone`
- `My Feature!` -> `myfeature`

**If invalid after normalization:** Reject with explanation and suggest correction.
```
❌ Name "My Feature!" is not slug-safe.
  Suggested: "myfeature"
  Rules: lowercase alphanumeric only (a-z0-9), 2-50 chars.
```

### Step 3: Derive Initiative Root

The initiative root has a variable number of segments depending on scope:

| Scope | Initiative Root | Config Path |
|-------|-----------------|-------------|
| domain | `{domain}` | `_bmad-output/lens-work/initiatives/{domain}/initiative.yaml` |
| service | `{domain}-{service}` | `_bmad-output/lens-work/initiatives/{domain}/{service}/initiative.yaml` |
| feature | `{domain}-{service}-{feature}` | `_bmad-output/lens-work/initiatives/{domain}/{service}/{feature}.yaml` |

**Examples:**
- `/new-domain test` → root: `test`, config: `initiatives/test/initiative.yaml`
- `/new-service worker` (in domain `test`) → root: `test-worker`, config: `initiatives/test/worker/initiative.yaml`
- `/new-feature oauth` (in service `test-worker`) → root: `test-worker-oauth`, config: `initiatives/test/worker/oauth.yaml`

### Step 4: Read lifecycle.yaml

**Feature scope only.** Domain and service scopes skip this step (they have no track, phases, or audiences).

Load `lifecycle.yaml` and validate:
- The selected track exists in the `tracks:` section
- Extract the phases and audiences enabled by this track
- Determine the start phase from `start_phase:` field

### Step 5: Cross-Initiative Sensing (Pre-Creation)

**BEFORE creating any branches**, run cross-initiative sensing:

1. List all existing initiative branches:
   ```bash
   git branch --list '*-small*' '*-medium*' '*-large*' | sed -E 's/-(small|medium|large|base)(-.*)?$//' | sort -u
   ```

2. Parse branch names to find initiatives in the same domain (or service):
   - Same domain: branches starting with `{domain}-`
   - Same service (when scope is service or feature): branches starting with `{domain}-{service}-`

3. For each overlapping initiative, report:
   ```
   ⚠️ Active initiatives in domain `{domain}`:
   - `{initiative-1}` (techplan/small)
   - `{initiative-2}` (devproposal/medium)
   Review for potential conflicts.
   ```

4. **Default behavior:** Informational gate — warn and continue.
5. **If constitution upgrades to hard gate:** Block creation and report why.

### Step 6: Verify Track Permissions

**Feature scope only.** Domain and service scopes skip this step.

Check governance repo (if available) to verify the selected track is permitted at this LENS hierarchy level. If governance repo is not accessible, proceed with a warning.

### Step 7: Create Initiative Config

Create the initiative config YAML file. Fields vary by scope:

**Domain scope:**
```yaml
# Initiative configuration — committed to git (Domain 1 artifact)
initiative: {domain}
scope: domain
domain: {domain}
language: unknown           # auto-detected later or user-specified
created: {ISO8601}
initiative_root: {domain}
```

**Service scope:**
```yaml
initiative: {service}
scope: service
domain: {domain}
service: {service}
language: unknown
created: {ISO8601}
initiative_root: {domain}-{service}
```

**Feature scope:**
```yaml
initiative: {feature}
scope: feature
domain: {domain}
service: {service}
track: {track}
language: unknown
created: {ISO8601}
initiative_root: {domain}-{service}-{feature}
```

Path (see Step 3 for scope-specific paths):
- domain: `_bmad-output/lens-work/initiatives/{domain}/initiative.yaml`
- service: `_bmad-output/lens-work/initiatives/{domain}/{service}/initiative.yaml`
- feature: `_bmad-output/lens-work/initiatives/{domain}/{service}/{feature}.yaml`

### Step 8: Scaffold TargetProjects Folder

**Domain and service scopes only.** Feature scope skips this step.

Read `target_projects_path` from `bmadconfig.yaml` (default: `TargetProjects`) or from the user's `profile.yaml`.

Create the corresponding folder in the TargetProjects tree:

- **Domain scope:** `{target_projects_path}/{domain}/`
- **Service scope:** `{target_projects_path}/{domain}/{service}/`

```bash
mkdir -p {target_projects_path}/{folder-path}
```

This creates the organizational placeholder so that future repo clones and `/new-service` or `/new-feature` operations have a home. The folder is NOT committed to git (TargetProjects is gitignored) — it is a local workspace scaffold only.

### Step 9: Create Branch Topology

Using the git-orchestration skill:

1. Create initiative root branch from the control repo default branch:
   ```bash
   git checkout {default-branch}
   git checkout -b {initiative-root}
   ```

2. **Domain scope:** STOP — domains never have audience branches. The root branch is the only branch.

3. **Service scope:** STOP — services never have audience branches. The root branch is the only branch. Services are organizational containers for features.

4. **Feature scope:** Create first audience branch from root:
   ```bash
   git checkout -b {initiative-root}-small
   ```

5. **CRITICAL: Do NOT create medium, large, or base branches.** Lazy creation — these are created on-demand at promotion time.

### Step 10: Commit and Push

Using the git-orchestration skill:

1. Commit the initiative config:
   - **Domain / Service scope:**
     ```bash
     git add _bmad-output/lens-work/initiatives/{config-path}
     git commit -m "[INIT] {initiative-root} — {scope} created"
     ```
   - **Feature scope:**
     ```bash
     git add _bmad-output/lens-work/initiatives/{config-path}
     git commit -m "[INIT] {initiative-root} — initiative created (track: {track})"
     ```

2. Push branches:
   - **Domain / Service scope:** Push root only:
     ```bash
     git push -u origin {initiative-root}
     ```
   - **Feature scope:** Push both:
     ```bash
     git push -u origin {initiative-root}
     git push -u origin {initiative-root}-small
     ```

### Step 11: Display Response

Follow the 3-part response format:

**Context Header (domain scope):**
```
📂 Domain: {initiative-root}
```

**Context Header (service scope):**
```
📂 Service: {initiative-root}
```

**Context Header (feature scope):**
```
📂 Initiative: {initiative-root}
🏷️ Track: {track}
👥 Audience: small
📋 Phases: {phase-list}
```

**Primary Content (domain scope):**
```
✅ Domain created successfully.

Branch topology:
- `{initiative-root}` (domain root)

TargetProjects folder:
  `{target_projects_path}/{domain}/`

Config committed at:
  `_bmad-output/lens-work/initiatives/{config-path}`
```

**Primary Content (service scope):**
```
✅ Service created successfully.

Branch topology:
- `{initiative-root}` (service root)

TargetProjects folder:
  `{target_projects_path}/{domain}/{service}/`

Config committed at:
  `_bmad-output/lens-work/initiatives/{config-path}`
```

**Primary Content (feature scope):**
```
✅ Feature initiative created successfully.

Branch topology:
- `{initiative-root}` (root)
- `{initiative-root}-small` (active)

Config committed at:
  `_bmad-output/lens-work/initiatives/{config-path}`
```

**Next Step (scope-dependent):**

- **Domain scope:**
  ```
  ▶️ Run `/new-service` to create a service under this domain.
  ```

- **Service scope:**
  ```
  ▶️ Run `/new-feature` to create a feature under this service.
  ```

- **Feature scope:**
  ```
  ▶️ Run `/{start-phase}` to begin the first phase.
  ```
  Where `{start-phase}` is the track's `start_phase` from lifecycle.yaml.

## Error Handling

| Error | Response |
|-------|----------|
| Invalid track (feature scope only) | "Track `{input}` not found. Available tracks: full, feature, tech-change, hotfix, spike, quickdev." |
| Slug-unsafe name | Reject with explanation and suggested correction |
| Initiative already exists | "Initiative `{root}` already exists. Use `/switch {root}` to resume." |
| Not authenticated | "Run `/onboard` first to authenticate." |
| Sensing hard gate failure | "⚠️ Constitution blocks creation: {reason}. Contact governance admin." |
