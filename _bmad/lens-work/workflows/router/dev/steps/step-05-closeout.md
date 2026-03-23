---
name: 'step-05-closeout'
description: 'Run the optional retrospective, persist dev state, and finalize initiative completion when applicable'
---

# Step 5: Closeout And Initiative State

**Goal:** Offer the retrospective, persist dev state, append the event log, and complete the initiative when all phases are done.

---

## EXECUTION SEQUENCE

### 1. Retrospective (Optional)

```yaml
offer: "Run retrospective? [Y]es / [N]o"

if yes:
  invoke: git-orchestration.start-workflow
  params:
    workflow_name: retro

  agent_persona: "_bmad/bmm/agents/sm.md"
  read_and_follow: "_bmad/bmm/workflows/4-implementation/bmad-retrospective/workflow.md"
  params:
    constitutional_context: ${constitutional_context}
  invoke: git-orchestration.finish-workflow
```

### 2. Update State Files And Initiative Config

```yaml
invoke: state-management.update-initiative
params:
  initiative_id: ${initiative.id}
  updates:
    current_phase: "dev"
    phase_status:
      dev: "in_progress"
    gates:
      large_to_base:
        status: "passed"
        verified_at: "${ISO_TIMESTAMP}"
      dev_started:
        status: "in_progress"
        started_at: "${ISO_TIMESTAMP}"
        story_id: "${story_id}"

invoke: state-management.update-state
params:
  updates:
    current_phase: "dev"
    active_branch: "${initiative.initiative_root}-dev"
    workflow_status: "in_progress"
```

### 3. Commit State Changes

```yaml
invoke: git-orchestration.commit-and-push
params:
  paths:
    - "_bmad-output/lens-work/initiatives/${initiative.id}.yaml"
    - "_bmad-output/lens-work/event-log.jsonl"
    - "_bmad-output/implementation-artifacts/"
  message: "[lens-work] /dev: Dev Implementation - ${initiative.id} - ${story_id}"
  branch: "${initiative.initiative_root}-dev"
```

### 4. Log Event

```json
{"ts":"${ISO_TIMESTAMP}","event":"dev","id":"${initiative.id}","phase":"dev","workflow":"dev","story":"${story_id}","status":"in_progress"}
```

### 5. Complete Initiative (When All Done)

```yaml
if all_phases_complete():
  invoke: state-management.update-initiative
  params:
    initiative_id: ${initiative.id}
    updates:
      status: "complete"
      completed_at: "${ISO_TIMESTAMP}"
      phase_status:
        dev: "complete"

  invoke: state-management.archive

  invoke: git-orchestration.commit-and-push
  params:
    paths:
      - "_bmad-output/lens-work/"
    message: "[lens-work] Initiative complete - ${initiative.id}"

  output: |
    🎉 Initiative Complete!
    ├── All phases finished
    ├── Code merged to main
    ├── Initiative archived
    └── Great work, team!
```

---

## CONTROL-PLANE RULE REMINDER

Throughout `/dev`, the user may work in TargetProjects for actual coding, but all lens-work commands continue to execute from the BMAD directory:

| Action | Location | Note |
|--------|----------|------|
| Write code / create files | TargetProjects/${repo} (session.target_path) | **ONLY here** |
| Run /dev commands | BMAD directory | Control plane |
| Read framework files | bmad.lens.release/ | **READ-ONLY - never write here** |
| State tracking writes | _bmad-output/ | Sprint status, initiative config |
| Code review | BMAD directory | |
| Status checks | BMAD directory | |

**⚠️ bmad.lens.release is NEVER the implementation target.** It is a read-only authority repo containing BMAD framework code.

---

## OUTPUT ARTIFACTS

| Artifact | Location |
|----------|----------|
| Code Review Report | `_bmad-output/implementation-artifacts/code-review-${id}.md` |
| Party Mode Review Report | `_bmad-output/implementation-artifacts/party-mode-review-${story_id}.md` |
| Epic Party Mode Review Report | `_bmad-output/implementation-artifacts/epic-*-party-mode-review.md` |
| Complexity Tracking | `{bmad_docs}/complexity-tracking.md` |
| Retro Notes | `_bmad-output/implementation-artifacts/retro-${id}.md` |
| Initiative State | `_bmad-output/lens-work/initiatives/${id}.yaml` |
| Event Log | `_bmad-output/lens-work/event-log.jsonl` |

---

## ERROR HANDLING

| Error | Recovery |
|-------|----------|
| No dev story | Prompt to run /sprintplan first |
| SprintPlan not merged | Error with merge gate blocked message |
| Constitution gate not passed | Auto-triggers audience promotion (large -> base) |
| Audience promotion failed | Error - must complete large -> base promotion |
| Dirty working directory | Prompt to stash or commit changes first |
| Target repo checkout failed | Check target_repos config, retry |
| Branch creation failed | Check remote connectivity, retry with backoff |
| Dev story compliance gate failed | Auto-resolve: fix branch + PR created; merge and rerun /dev |
| Article-specific gate blocked | Auto-resolve: fix branch + PR created; merge and rerun /dev |
| Pre-implementation gate blocked | Auto-resolve: fix branch + PR created; merge and rerun /dev |
| Checklist quality gate failed | Complete checklist items or override with justification |
| Code review failed | Allow retry or manual review |
| Code review compliance gate failed | Auto-resolve: fix branch + PR created; merge and rerun @lens done |
| Post-review re-validation failed | Auto-resolve: fix branch + PR created; merge and rerun @lens done |
| Party mode teardown failed | Address party-mode findings and re-run code review |
| Epic adversarial review failed | Resolve implementation-readiness findings for the epic and re-run code review |
| Epic party mode teardown failed | Address epic party-mode findings and re-run code review |
| State file write failed | Retry (max 3 attempts), then fail with save instructions |

---

## POST-CONDITIONS

- [ ] Working directory clean (all changes committed)
- [ ] On correct branch: `{initiative_root}-dev`
- [ ] Audience promotion validated (large -> base passed)
- [ ] initiatives/{id}.yaml updated with dev status and gate entries
- [ ] event-log.jsonl entries appended
- [ ] All stories for the epic discovered and implemented
- [ ] Each story: constitution check passed, pre-implementation gates passed
- [ ] Each task: individually committed to story branch
- [ ] Each story: adversarial code review executed with fix loop (max 2 passes)
- [ ] Each story: party mode teardown passed
- [ ] Each story: PR created (story branch -> epic branch)
- [ ] Epic completion gate: adversarial review and party-mode teardown passed
- [ ] Constitutional guidance surfaced with special instructions (if provided)
- [ ] Target repo feature branches used for implementation
- [ ] Epic adversarial review executed when epic completion is detected
- [ ] Epic party-mode teardown executed when epic completion is detected
- [ ] All state changes pushed to origin