---
name: 'step-01-preflight'
description: 'Run pre-flight, branch routing, prerequisite validation, and artifact checklist gating'
nextStepFile: './step-02-readiness.md'
---

# Step 1: Pre-Flight And Gate Checks

**Goal:** Establish the correct SprintPlan branch context, confirm promotion prerequisites, and detect missing required artifacts before deeper validation.

---

## EXECUTION SEQUENCE

### 1. Pre-Flight [REQ-9]

```yaml
# PRE-FLIGHT (mandatory, never skip) [REQ-9]
# 0. Execute shared preflight include (authority sync + constitution enforcement)
# 1. Verify working directory is clean
# 2. Derive initiative state from git branch (v2: git-state skill)
# 3. Validate audience promotion (medium -> large must be complete)
# 4. Determine correct phase branch: {initiative_root}-{audience}-{phase_name}
# 5. Create phase branch if it doesn't exist
# 6. Checkout phase branch
# 7. Confirm to user: "Now on branch: {branch_name}"
# GATE: All steps must pass before proceeding to sprint planning
# NOTE: sprintplan is the FIRST phase in large audience - requires medium->large promotion

# Shared preflight include (includes constitutional context bootstrap)
invoke: include
path: "_bmad/lens-work/workflows/includes/preflight.md"

# Verify working directory is clean
invoke: git-orchestration.verify-clean-state

# Derive initiative state from git branch (v2: git-state skill)
initiative_state = invoke: git-state.current-initiative
initiative = load("${initiative_state.config_path}")

# Load lifecycle contract for phase -> audience mapping
lifecycle = load("lifecycle.yaml")

# Read initiative config
size = initiative.size
domain_prefix = initiative.domain_prefix

# Derive audience from lifecycle contract (sprintplan -> large)
current_phase = "sprintplan"
audience = lifecycle.phases[current_phase].branching_audience || lifecycle.phases[current_phase].audience
initiative_root = initiative.initiative_root
audience_branch = "${initiative_root}-${audience}"

# === Path Resolver (S01-S06: Context Enhancement) ===
docs_path = initiative.docs.path
repo_docs_path = "docs/${initiative.docs.domain}/${initiative.docs.service}/${initiative.docs.repo}"

if docs_path == null or docs_path == "":
  docs_path = "_bmad-output/planning-artifacts/"
  repo_docs_path = null
  warning: "⚠️ DEPRECATED: Initiative missing docs.path configuration."

output_path = "${docs_path}/reviews/"
ensure_directory("${docs_path}/reviews/")

# REQ-10: Resolve BmadDocs path for per-initiative output co-location
bmad_docs = initiative.docs.bmad_docs
if bmad_docs != null and bmad_docs != "":
  ensure_directory("${bmad_docs}")

# REQ-9: Validate audience promotion gate (medium -> large)
prev_audience = "medium"
prev_audience_branch = "${initiative_root}-medium"

if initiative.audience_status exists:
  if initiative.audience_status.medium_to_large != "complete":
    result = git-orchestration.exec("git merge-base --is-ancestor origin/${prev_audience_branch} origin/${audience_branch}")

    if result.exit_code == 0:
      invoke: state-management.update-initiative
      params:
        initiative_id: ${initiative.id}
        updates:
          audience_status:
            medium_to_large: "complete"
      output: "✅ Audience promotion (medium -> large) complete - stakeholder approval gate passed"
    else:
      output: |
        ❌ Audience promotion (medium -> large) not complete
        ├── Gate: stakeholder-approval
        ├── All medium-audience phases (devproposal) must be complete
        └── Auto-triggering audience promotion now

      invoke_command: "@lens promote"
      exit: 0
else:
  warning: "⚠️ No audience_status in initiative config - legacy format detected"

# Determine phase branch [REQ-9]
phase_branch = "${initiative_root}-${audience}-sprintplan"

# Step 5: Create phase branch if it doesn't exist [REQ-9]
if not branch_exists(phase_branch):
  invoke: git-orchestration.start-phase
  params:
    phase_name: "sprintplan"
    display_name: "SprintPlan"
    initiative_id: ${initiative.id}
    audience: ${audience}
    initiative_root: ${initiative_root}
    parent_branch: ${audience_branch}
  if start_phase.exit_code != 0:
    FAIL("❌ Pre-flight failed: Could not create branch ${phase_branch}")

# Step 6: Checkout phase branch
invoke: git-orchestration.checkout-branch
params:
  branch: ${phase_branch}
invoke: git-orchestration.pull-latest

# Step 7: Confirm to user [REQ-9]
output: |
  📋 Pre-flight complete [REQ-9]
  ├── Initiative: ${initiative.name} (${initiative.id})
  ├── Phase: SprintPlan (sprintplan)
  ├── Audience: large (stakeholder approval)
  ├── Branch: ${phase_branch}
  └── Working directory: clean ✅
```

### 2. Validate Prerequisites And Gate Check

```yaml
# Gate check - verify devproposal phase is complete and medium->large promotion done
devproposal_branch = "${initiative_root}-medium-devproposal"
medium_branch = "${initiative_root}-medium"

result = git-orchestration.exec("git merge-base --is-ancestor origin/${devproposal_branch} origin/${medium_branch}")

if result.exit_code != 0:
  error: "DevProposal phase not complete. Run /devproposal first or merge pending PRs."

# Verify audience promotion gate (medium -> large) passed
if initiative.audience_status.medium_to_large != "complete":
  output: |
    ⏳ Audience promotion (medium -> large) still incomplete
    ▶️  Auto-triggering audience promotion now
  invoke_command: "@lens promote"
  exit: 0
```

### 3. Checklist Enforcement - Verify Required Artifacts

```yaml
required_artifacts:
  - path: "${docs_path}/product-brief.md"
    phase: "preplan"
    name: "Product Brief"
  - path: "${docs_path}/prd.md"
    phase: "businessplan"
    name: "PRD"
  - path: "${docs_path}/architecture.md"
    phase: "techplan"
    name: "Architecture"
  - path: "${docs_path}/epics.md"
    phase: "devproposal"
    name: "Epics"
  - path: "${docs_path}/stories.md"
    phase: "devproposal"
    name: "Stories"
  - path: "${docs_path}/readiness-checklist.md"
    phase: "devproposal"
    name: "Readiness Checklist"

missing = []
for artifact in required_artifacts:
  if not file_exists(artifact.path):
    missing.append("${artifact.name} (${artifact.phase}): ${artifact.path}")

if missing.length > 0:
  output: |
    ⚠️ Missing required artifacts:
    ${missing.join("\n")}

    These must exist before passing the sprint planning gate.

  offer: "Continue anyway? [Y]es / [N]o - (choosing Yes will mark gate as 'passed_with_warnings')"
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{project-root}/_bmad/lens-work/workflows/router/sprintplan/steps/step-02-readiness.md`