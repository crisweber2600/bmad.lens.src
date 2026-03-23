---
name: 'step-03-sprint-planning'
description: 'Run the scrum-master sprint planning workflow and generate the sprint backlog'
nextStepFile: './step-04-dev-story.md'
---

# Step 3: Sprint Planning

**Goal:** Execute the sprint-planning sub-workflow as Bob, producing the sprint backlog after all gates pass.

---

## EXECUTION SEQUENCE

### 1. Run Sprint Planning Workflow

**CRITICAL - Workflow Rules:**
Sub-workflow execution remains sequential.

- Read and follow the workflow.md file directly.
- Save outputs after each step.
- Stop and wait for user at decision points.

**Agent:** Adopt Bob (Scrum Master) persona - load `_bmad/bmm/agents/sm.md`

```yaml
invoke: git-orchestration.start-workflow
params:
  workflow_name: sprint-planning

# RESOLVED: bmm.sprint-planning -> Read fully and follow this workflow file:
#   _bmad/bmm/workflows/4-implementation/bmad-sprint-planning/workflow.md
# Agent persona: Bob (Scrum Master) - _bmad/bmm/agents/sm.md
# Execute steps sequentially - save outputs after EACH step
# STOP and wait for user at decision points
agent_persona: "_bmad/bmm/agents/sm.md"
read_and_follow: "_bmad/bmm/workflows/4-implementation/bmad-sprint-planning/workflow.md"
params:
  stories: "${docs_path}/stories.md"
  output_path: "${bmad_docs}"
  constitutional_context: ${constitutional_context}

invoke: git-orchestration.finish-workflow

output: |
  📋 Sprint Planning
  ├── Stories prioritized
  ├── Capacity allocated
  ├── Sprint backlog: ${bmad_docs}/sprint-backlog.md
  └── Sprint backlog created
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{project-root}/_bmad/lens-work/workflows/router/sprintplan/steps/step-04-dev-story.md`