---
name: 'step-04-dev-story'
description: 'Create the selected dev-ready story after sprint planning completes'
nextStepFile: './step-05-closeout.md'
---

# Step 4: Create Dev-Ready Story

**Goal:** Generate the developer-facing story artifact that `/dev` consumes after sprint planning completes.

---

## EXECUTION SEQUENCE

### 1. Create Dev Story

```yaml
invoke: git-orchestration.start-workflow
params:
  workflow_name: dev-story

# RESOLVED: bmm.create-dev-story -> Read fully and follow this workflow file:
#   _bmad/bmm/workflows/4-implementation/bmad-create-story/workflow.md
# Agent persona: Bob (Scrum Master) - _bmad/bmm/agents/sm.md
# Execute steps sequentially - save outputs after EACH step
# STOP and wait for user at decision points
read_and_follow: "_bmad/bmm/workflows/4-implementation/bmad-create-story/workflow.md"
params:
  story_id: "${selected_story}"
  output_path: "${bmad_docs}"
  constitutional_context: ${constitutional_context}

invoke: git-orchestration.finish-workflow

output: |
  📝 Dev Story Created
  ├── Story: ${story_id}
  ├── Location: ${bmad_docs}/dev-story-${story_id}.md
  ├── Acceptance Criteria: ✅
  ├── Technical Notes: ✅
  └── Ready for developer pickup
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`