---
name: 'step-01-preflight'
description: 'Run dev pre-flight, resolve the target repo, and validate the large-to-base promotion gate'
nextStepFile: './step-02-story-discovery.md'
promotionAndContextData: '../data/preflight-promotion-and-context.md'
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
# 3. Determine correct phase branch: {initiative_root}-{audience}-{phase_name}
# 4. Create phase branch if it doesn't exist
# 5. Checkout phase branch
# 6. Confirm to user: "Now on branch: {branch_name}"

invoke: include
path: "_bmad/lens-work/workflows/includes/preflight.md"

invoke: git-orchestration.verify-clean-state

branch = invoke: git-orchestration.get-current-branch
initiative = load("_bmad-output/lens-work/initiatives/${git-state.parse-initiative-root(branch)}.yaml")

size = initiative.size
domain_prefix = initiative.domain_prefix

audience = "base"
initiative_root = initiative.initiative_root
audience_branch = "base"

docs_path = initiative.docs.path
repo_docs_path = "docs/${initiative.docs.domain}/${initiative.docs.service}/${initiative.docs.repo}"

if docs_path == null or docs_path == "":
  docs_path = "_bmad-output/planning-artifacts/"
  repo_docs_path = null
  warning: "⚠️ DEPRECATED: Initiative missing docs.path configuration."
  warning: "  -> Run: /lens migrate <initiative-id> to add docs.path"

bmad_docs = initiative.docs.bmad_docs

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

if session.target_path contains "bmad.lens.release":
  FAIL: |
    ❌ INVALID TARGET - bmad.lens.release is a READ-ONLY authority repo.
    ├── Resolved target_path: ${session.target_path}
    ├── It is NEVER the implementation target for /dev
    └── Fix: Update initiative.target_repos to point to the actual TargetProject repo path.

if docs_path != "_bmad-output/planning-artifacts/":
  architecture = load_if_exists("${docs_path}/architecture.md")
  stories = load_if_exists("${docs_path}/stories.md")
  planning_context = { architecture: architecture, stories: stories }
else:
  planning_context = null

phase_branch = "${initiative.initiative_root}-dev"

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

invoke: git-orchestration.checkout-branch
params:
  branch: ${phase_branch}
invoke: git-orchestration.pull-latest

output: |
  📋 Pre-flight complete [REQ-9]
  ├── Initiative: ${initiative.name} (${initiative.id})
  ├── Phase: Dev (Implementation)
  ├── Branch: ${phase_branch}
  └── Working directory: clean ✅
```

### 2. Promotion, Constitutional Context, And Branch Verification

Load and execute `{promotionAndContextData}` in the active `/dev` pre-flight context. This reference contains:

- large-to-base promotion verification
- prior SprintPlan completion handling
- constitutional context injection
- final branch assertion

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`