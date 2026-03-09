---
name: preplan
description: Launch PrePlan phase (brainstorm/research/product brief)
agent: "@lens"
trigger: /preplan command
aliases: [/pre-plan]
category: router
phase_name: preplan
display_name: PrePlan
agent_owner: mary
agent_role: Analyst
imports: lifecycle.yaml
---

# /preplan — PrePlan Phase Router

**Purpose:** Guide users through the PrePlan phase, invoking brainstorming, research, and product brief workflows.

**Lifecycle:** `preplan` phase, audience `small`, owned by Mary (Analyst).

---

## User Interaction Keywords

This workflow supports special keywords to control prompting behavior:

- **"defaults" / "best defaults"** → Apply defaults to **CURRENT STEP ONLY**; resume normal prompting for subsequent steps
- **"yolo" / "keep rolling"** → Apply defaults to **ENTIRE REMAINING WORKFLOW**; auto-complete all steps
- **"all questions" / "batch questions"** → Present **ALL QUESTIONS UPFRONT** → wait for batch answers → follow-up questions → adversarial review → final questions → generate artifacts
- **"skip"** → Jump to a named optional step (e.g., "skip to product brief")
- **"pause"** → Halt workflow, save progress, resume later
- **"back"** → Roll back to previous step, re-answer questions

**Critical Rule:**
- "defaults" applies only to the current question/step
- "yolo" applies to all remaining steps in the workflow
- "all questions" presents comprehensive questionnaire, then iteratively refines with follow-ups and party mode review
- Other workflows and phases are unaffected

---

## Prerequisites

- [x] Initiative created via `#new-*` command
- [x] Layer detected with confidence ≥ 75%
- [x] Initiative file exists at `_bmad-output/lens-work/initiatives/{domain}/{service}/{feature}.yaml`

---

## Execution Sequence

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

### Step 1: Phase Router Validation + Branch

Invoke the @lens phase router:

1. Read `lifecycle.yaml` to confirm `preplan` is valid for this track
2. Derive current initiative and audience from branch via git-state
3. Validate no predecessor is required (preplan is always the first phase)
4. If valid: create phase branch `{initiative-root}-small-preplan` using git-orchestration
5. If track doesn't include preplan: report error with valid phases for this track

### Step 2: Load Initiative Context

Load the initiative config from `_bmad-output/lens-work/initiatives/{domain}/{service}/{feature}.yaml`:

- Initiative root, domain, service, feature
- Track type and enabled phases
- Any previous artifacts from earlier sessions

Derive output path for artifacts:
```yaml
output_path = "_bmad-output/lens-work/initiatives/{domain}/{service}/phases/preplan/"
ensure_directory(output_path)
```

### Step 2a: Execution Mode Selection (Interactive or Batch)

```yaml
# Allow per-phase override of global question_mode preference
ask: |
  📋 Execution Mode Selection

  How would you like to proceed with this phase?

  **[I] Interactive** — Choose workflows and answer step-by-step
  **[B] Batch**       — Answer all questions at once in a single file

  Select mode: [I] or [B]
  (Default: Interactive)
```

If batch mode selected, invoke batch-process and exit.
Otherwise continue to Step 3 for interactive workflow selection.

### Step 3: Offer Workflow Options

```
🧭 /preplan — PrePlan Phase

You're starting the Analysis phase. Available workflows:

**[1] Brainstorming** (optional) — Creative exploration with CIS
**[2] Research** (optional) — Deep dive research with CIS
**[3] Product Brief** (required) — Define problem, vision, and scope

Recommended path: 1 → 2 → 3 (or skip to 3 if you have clarity)

Select workflow(s) to run: [1] [2] [3] [A]ll [S]kip to Product Brief
```

### Step 4: Execute Selected Workflows

**⚠️ CRITICAL — Interactive Workflow Rules:**
Each sub-workflow uses sequential step-file architecture.
- 🛑 **NEVER** auto-complete or batch-generate content without user input
- ⏸️ **ALWAYS** STOP and wait for user input/confirmation at each step
- 🚫 **NEVER** load the next step file until user explicitly confirms (Continue / C)
- 📋 Back-and-forth dialogue is REQUIRED — you are a facilitator, not a generator
- 💾 Save/update frontmatter after completing each step before loading the next
- 🎯 Read the ENTIRE step file before taking any action within it

**Agent:** Adopt Mary (Analyst) persona — load `_bmad/bmm/agents/analyst.md`

#### If Brainstorming selected:

```yaml
# Read fully and follow this workflow file:
#   _bmad/core/workflows/brainstorming/workflow.md
# Uses step-file architecture with steps/ folder — load step-01-session-setup.md first
# STOP and wait for user at each step — do NOT auto-generate brainstorm content
read_and_follow: "_bmad/core/workflows/brainstorming/workflow.md"
params:
  context: "${initiative.name} at ${initiative.layer} layer"
```

#### If Research selected:

```yaml
# Ask user for research type, then follow the correct workflow:
#   Market:    _bmad/bmm/workflows/1-analysis/research/workflow-market-research.md
#   Domain:    _bmad/bmm/workflows/1-analysis/research/workflow-domain-research.md
#   Technical: _bmad/bmm/workflows/1-analysis/research/workflow-technical-research.md
# Each uses step-file architecture — load steps one at a time, wait for user at each step
prompt_user: "Which type of research? [M]arket / [D]omain / [T]echnical"
if research_type == "market":
  read_and_follow: "_bmad/bmm/workflows/1-analysis/research/workflow-market-research.md"
elif research_type == "domain":
  read_and_follow: "_bmad/bmm/workflows/1-analysis/research/workflow-domain-research.md"
elif research_type == "technical":
  read_and_follow: "_bmad/bmm/workflows/1-analysis/research/workflow-technical-research.md"
```

#### Product Brief (always):

```yaml
# Read fully and follow this workflow file:
#   _bmad/bmm/workflows/1-analysis/create-product-brief/workflow.md
# Uses JIT step-file architecture:
#   1. Load step-01-init.md first
#   2. Only load next step when directed by the current step
#   3. NEVER load multiple step files simultaneously
#   4. ALWAYS halt at menus and wait for user input
#   5. Output goes to: ${output_path}/product-brief.md
# Agent persona: Mary (Analyst) — _bmad/bmm/agents/analyst.md
read_and_follow: "_bmad/bmm/workflows/1-analysis/create-product-brief/workflow.md"
params:
  output_path: "${output_path}/"
  context:
    brainstorm_notes: "${output_path}/brainstorm-notes.md"   # if exists from step [1]
    research_summary: "${output_path}/research-summary.md"   # if exists from step [2]
```

### Step 5: Commit Artifacts

Using git-orchestration skill:

1. Stage all artifacts in `phases/preplan/`
2. Commit with message: `[PREPLAN] {initiative-root} — preplan artifacts complete`
3. Push to remote (reviewable checkpoint)

### Step 6: Phase Completion

```yaml
if all_workflows_complete("preplan"):
  # Push final state to phase branch
  # Create PR for phase merge
  output: |
    ✅ /preplan complete
    ├── Phase: PrePlan (preplan) finished
    ├── Audience: small
    ├── Artifacts: product-brief.md (+ brainstorm/research if produced)
    ├── Branch pushed: {phase_branch}
    └── Next: Run /businessplan to continue to BusinessPlan phase
```

---

## Output Artifacts

| Artifact | Location | Required |
|----------|----------|----------|
| Product Brief | `phases/preplan/product-brief.md` | Yes |
| Research Summary | `phases/preplan/research-summary.md` | If research selected |
| Brainstorm Notes | `phases/preplan/brainstorm-notes.md` | If brainstorming selected |

---

## Error Handling

| Error | Response |
|-------|----------|
| Track doesn't include preplan | `❌ Track '{track}' does not include preplan. Valid phases: {phases}` |
| Not on initiative branch | `❌ Not on an initiative branch. Use /switch or /new-domain first.` |
| Already on a phase branch | `⚠️ Already on phase branch {branch}. Complete current phase first.` |
