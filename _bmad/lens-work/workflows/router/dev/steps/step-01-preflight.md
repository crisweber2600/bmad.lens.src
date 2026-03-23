---
name: 'step-01-preflight'
description: 'Run dev pre-flight, resolve the target repo, and validate the large-to-base promotion gate'
nextStepFile: './step-02-story-discovery.md'
---

# Step 1: Pre-Flight And Target Repo Validation

**Goal:** Establish the `/dev` branch context, resolve the implementation target repo, and confirm SprintPlan and promotion gates before story execution begins.

---

## EXECUTION SEQUENCE

### 1. Pre-Flight [REQ-9]

```yaml
# PRE-FLIGHT (mandatory, never skip) [REQ-9]
# 0. Execute shared preflight include (authority sync + constitution enforcement)
# 1. Verify working directory is clean
# 2. Load initiative config (git-derived state)
# 3. Check previous phase status (if applicable)
# 4. Determine correct phase branch: {initiative_root}-{audience}-{phase_name}
# 5. Create phase branch if it doesn't exist
# 6. Checkout phase branch
# 7. Confirm to user: "Now on branch: {branch_name}"
# GATE: All steps must pass before proceeding to artifact work

# Shared preflight include (includes constitutional context bootstrap)
invoke: include
path: "_bmad/lens-work/workflows/includes/preflight.md"

# Verify working directory is clean
invoke: git-orchestration.verify-clean-state

# Load initiative config from current git branch (v2 git-derived state)
branch = invoke: git-orchestration.get-current-branch
initiative = load("_bmad-output/lens-work/initiatives/${git-state.parse-initiative-root(branch)}.yaml")

# Read initiative config
size = initiative.size
domain_prefix = initiative.domain_prefix

# Derive audience for dev phase (base) [REQ-9]
audience = "base"
initiative_root = initiative.initiative_root
audience_branch = "base"

# === Path Resolver (S01-S06: Context Enhancement) ===
docs_path = initiative.docs.path
repo_docs_path = "docs/${initiative.docs.domain}/${initiative.docs.service}/${initiative.docs.repo}"

if docs_path == null or docs_path == "":
  docs_path = "_bmad-output/planning-artifacts/"
  repo_docs_path = null
  warning: "⚠️ DEPRECATED: Initiative missing docs.path configuration."
  warning: "  -> Run: /lens migrate <initiative-id> to add docs.path"

# NOTE: docs_path is READ-ONLY in /dev - used for context loading (S11)
# Dev outputs go to _bmad-output/implementation-artifacts/ (unchanged)

# REQ-10: Resolve BmadDocs path for per-initiative output co-location
bmad_docs = initiative.docs.bmad_docs

# === Target Repo Validation Gate ===
if initiative.target_repos == null or initiative.target_repos.length == 0:
  output: |
    ⚠️ No target repos configured for this initiative.
    ├── Initiative: ${initiative.id}
    └── target_repos field is missing or empty.

  ask: |
    Please provide the path to the target repo for this initiative.
    This should be the local path to the repository (e.g., TargetProjects/domain/service/repo-name):
  capture: user_target_path

  if user_target_path == null or user_target_path == "":
    FAIL("❌ Target repo path is required for /dev. Cannot proceed without a target repo.")

  session.target_repo = { name: basename(user_target_path), local_path: user_target_path }
  session.target_path = user_target_path
  warning: |
    ⚠️ Using user-provided target path: ${user_target_path}
    Consider running /lens init-repo to register this repo in the initiative config.
else:
  session.target_repo = initiative.target_repos[0]
  session.target_path = initiative.target_repos[0].local_path

output: |
  📂 Target Repo Resolved
  ├── Repo: ${session.target_repo.name}
  └── Path: ${session.target_path}

# === HARD REJECTION: bmad.lens.release is NEVER a valid implementation target ===
if session.target_path contains "bmad.lens.release":
  FAIL: |
    ❌ INVALID TARGET - bmad.lens.release is a READ-ONLY authority repo.
    ├── Resolved target_path: ${session.target_path}
    ├── bmad.lens.release contains BMAD framework code (agents, workflows, lifecycle)
    ├── It is NEVER the implementation target for /dev
    └── Fix: Update initiative.target_repos to point to the actual TargetProject repo path.

    Expected target_path pattern: TargetProjects/{domain}/{service}/{repo-name}

# === Context Loader (S11: Context Enhancement) ===
if docs_path != "_bmad-output/planning-artifacts/":
  architecture = load_if_exists("${docs_path}/architecture.md")
  stories = load_if_exists("${docs_path}/stories.md")
  planning_context = { architecture: architecture, stories: stories }
else:
  planning_context = null

# REQ-7/REQ-9: Validate previous phase (sprintplan) and audience promotion
prev_phase = "sprintplan"
prev_audience = "large"
prev_phase_branch = "${initiative.initiative_root}-${prev_audience}-sprintplan"
prev_audience_branch = "${initiative.initiative_root}-${prev_audience}"

if initiative.phase_status[prev_phase] exists:
  if initiative.phase_status[prev_phase] == "pr_pending":
    branch_exists_result = git-orchestration.exec("git ls-remote --heads origin ${prev_audience_branch}")
    prev_audience_branch_exists = (branch_exists_result.stdout != "")

    if prev_audience_branch_exists:
      result = git-orchestration.exec("git merge-base --is-ancestor origin/${prev_phase_branch} origin/${prev_audience_branch}")

      if result.exit_code == 0:
        invoke: state-management.update-initiative
        params:
          initiative_id: ${initiative.id}
          updates:
            phase_status:
              sprintplan: "complete"
        output: "✅ Previous phase (sprintplan) PR merged - status updated to complete"
      else:
        pr_url = initiative.phase_status.sprintplan_pr_url || "(no PR URL recorded)"
        output: |
          ⚠️  Previous phase (sprintplan) PR not yet merged
          ├── Status: pr_pending
          ├── PR: ${pr_url}
          └── You may continue, but phase artifacts may not be on the audience branch

        ask: "Continue anyway? [Y]es / [N]o"
        if no:
          exit: 0
    else:
      if initiative.audience_status.large_to_base in ["complete", "passed", "passed_with_warnings"]:
        invoke: state-management.update-initiative
        params:
          initiative_id: ${initiative.id}
          updates:
            phase_status:
              sprintplan: "complete"
        output: "✅ Previous phase (sprintplan) complete - audience branch merged and deleted (large->base promotion passed)"
      else:
        pr_url = initiative.phase_status.sprintplan_pr_url || "(no PR URL recorded)"
        output: |
          ⚠️  Audience branch ${prev_audience_branch} not found remotely
          ├── May have been deleted after PR merge
          ├── PR: ${pr_url}
          └── Proceeding - verify manually if needed

if initiative.question_mode == "batch":
  pass

if initiative.audience_status.large_to_base not in ["complete", "passed", "passed_with_warnings"]:
  output: |
    ⏳ Audience promotion validation pending
    ├── Required: large -> base promotion (constitution gate)
    └── ▶️  Auto-triggering audience promotion now
  invoke_command: "@lens promote"
  exit: 0

# Determine phase branch [REQ-9]
phase_branch = "${initiative.initiative_root}-dev"

# Step 5: Create phase branch if it doesn't exist [REQ-9]
if not branch_exists(phase_branch):
  invoke: git-orchestration.start-phase
  params:
    phase_name: "dev"
    initiative_id: ${initiative.id}
    audience: ${audience}
    initiative_root: ${initiative.initiative_root}
    parent_branch: ${audience_branch}
  if start_phase.exit_code != 0:
    FAIL("❌ Pre-flight failed: Could not create branch ${phase_branch}")

# Step 6: Checkout phase branch
invoke: git-orchestration.checkout-branch
params:
  branch: ${phase_branch}
invoke: git-orchestration.pull-latest

# Step 7: Confirm to user
output: |
  📋 Pre-flight complete [REQ-9]
  ├── Initiative: ${initiative.name} (${initiative.id})
  ├── Phase: Dev (Implementation)
  ├── Branch: ${phase_branch}
  └── Working directory: clean ✅
```

### 2. Audience Promotion Check - large -> base Complete

```yaml
sprintplan_branch = "${initiative.initiative_root}-large-sprintplan"
large_branch = "${initiative.initiative_root}-large"

sprintplan_branch_exists = git-orchestration.exec("git ls-remote --heads origin ${sprintplan_branch}").stdout != ""
large_branch_exists = git-orchestration.exec("git ls-remote --heads origin ${large_branch}").stdout != ""

if sprintplan_branch_exists and large_branch_exists:
  result = git-orchestration.exec("git merge-base --is-ancestor origin/${sprintplan_branch} origin/${large_branch}")

  if result.exit_code != 0:
    error: |
      ❌ Merge gate blocked
      ├── SprintPlan not merged into large audience branch
      ├── Expected: ${sprintplan_branch} is ancestor of ${large_branch}
      └── Action: Complete /sprintplan and merge PR first
else:
  if initiative.audience_status.large_to_base in ["complete", "passed", "passed_with_warnings"]:
    output: "✅ Audience branch(es) deleted post-merge - large->base promotion already complete"
  else:
    output: |
      ⚠️  Audience branch(es) not found remotely
      ├── sprintplan: ${sprintplan_branch} (${sprintplan_branch_exists ? 'found' : 'gone'})
      ├── large: ${large_branch} (${large_branch_exists ? 'found' : 'gone'})
      └── Proceeding - verify manually if needed

if initiative.audience_status.large_to_base not in ["complete", "passed", "passed_with_warnings"]:
  output: |
    ⏳ Constitution gate still not passed for large -> base
    ▶️  Auto-triggering audience promotion now
  invoke_command: "@lens promote"
  exit: 0
```

### 3. Constitutional Context Injection (Required)

```yaml
constitutional_context = invoke("constitution.resolve-context")

if constitutional_context.status == "parse_error":
  error: |
    Constitutional context parse error:
    ${constitutional_context.error_details.file}
    ${constitutional_context.error_details.error}

session.constitutional_context = constitutional_context
```

### 4. Branch Verification

```yaml
assert: current_branch == phase_branch
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{project-root}/_bmad/lens-work/workflows/router/dev/steps/step-02-story-discovery.md`