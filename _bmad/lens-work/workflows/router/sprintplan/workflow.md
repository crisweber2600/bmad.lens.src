---
name: sprintplan
description: Sprint planning phase - sprint-status, story files, dev handoff
agent: "@lens"
trigger: /sprintplan command
aliases: [/review, /sprint]
category: router
phase_name: sprintplan
display_name: SprintPlan
agent_owner: bob
agent_role: Scrum Master
imports: lifecycle.yaml
entryStep: './steps/step-01-preflight.md'
---

# /sprintplan - SprintPlan Phase Router

**Goal:** Validate readiness, run sprint planning, create dev-ready stories, and hand off to developers.

**Your Role:** Route the SprintPlan phase as Bob's control-plane workflow, enforcing promotion gates, readiness checks, and constitutional compliance before any developer handoff occurs.

---

## WORKFLOW ARCHITECTURE

This workflow now uses **step-file architecture**:

- Each step keeps a single concern in focus so phase routing remains maintainable.
- State persists through the active initiative context: `initiative`, `initiative_root`, `docs_path`, `bmad_docs`, `phase_branch`, `constitutional_context`, `missing`, `compliance_warnings`, `compliance_checked`, `readiness`, `selected_story`, `story_id`, `story_title`, `developer_name`, `pr_result`, and `gate_status`.
- The execution order matches the legacy router exactly; only the structure changed.

---

## INITIALIZATION

- Core user and module context is already loaded by `@lens` from `{project-root}/_bmad/lens-work/bmadconfig.yaml`.
- `installed_path = {project-root}/_bmad/lens-work/workflows/router/sprintplan`
- `lifecycle_contract = {project-root}/_bmad/lens-work/lifecycle.yaml`
- `preflight_include = {project-root}/_bmad/lens-work/workflows/includes/preflight.md`
- `promotion_check_include = {project-root}/_bmad/lens-work/workflows/includes/promotion-check.md`

---

## EXECUTION

Read fully and follow: `{project-root}/_bmad/lens-work/workflows/router/sprintplan/steps/step-01-preflight.md`

### Step Map

1. `step-01-preflight.md` - Pre-flight, branch routing, prerequisite gate, artifact gate
2. `step-02-readiness.md` - Constitutional context, readiness validation, compliance gate
3. `step-03-sprint-planning.md` - Sprint planning sub-workflow execution
4. `step-04-dev-story.md` - Dev-ready story creation
5. `step-05-closeout.md` - PR creation, state updates, event log, developer handoff, promotion check
