---
name: 'step-04-dev-story'
description: 'Batch-create dev-ready story artifacts for all stories in the sprint backlog for the target epic'
nextStepFile: './step-05-closeout.md'
workflowXml: '{project-root}/_bmad/core/tasks/workflow.xml'
scrumMasterAgent: '{project-root}/_bmad/bmm/agents/sm.md'
devStoryWorkflow: '{project-root}/_bmad/bmm/workflows/4-implementation/dev-story/workflow.yaml'
---

# Step 4: Batch-Create Dev-Ready Stories

## STEP GOAL:

Generate developer-facing story artifacts for ALL stories in the sprint backlog for the target epic, so `/dev` can discover and implement the complete story set in a single session.

## MANDATORY EXECUTION RULES:

### Universal Rules:
- Read the complete step file before taking action.
- Iterate ALL stories in the sprint backlog for the target epic — do not stop after one.
- Preserve constitutional context while generating each dev-story artifact.

### Role Reinforcement:
- You are the LENS control-plane router.
- Convert SprintPlan output into a complete set of developer-ready handoffs without losing traceability.

### Step-Specific Rules:
- Load `{scrumMasterAgent}` before executing `{devStoryWorkflow}`.
- Load `{workflowXml}` and execute `{devStoryWorkflow}` through the workflow engine once per story.
- Generate each story artifact in `{bmad_docs}` so `/dev` can consume them directly.
- Skip stories that already have existing dev-story artifacts (no overwrite).

## EXECUTION PROTOCOLS:
- Follow the numbered sequence exactly.
- Track created count and skipped count for closeout reporting.
- Persist all created story ids and output paths for closeout.

## CONTEXT BOUNDARIES:
- Available context: sprint backlog, `{workflowXml}`, `{scrumMasterAgent}`, and `{devStoryWorkflow}`.
- Focus: batch dev-story generation and handoff readiness.
- Limits: do not create the milestone branch or PR in this step.
- Dependencies: successful sprint planning output with populated sprint backlog.

---

## MANDATORY SEQUENCE

### 1. Load Sprint Backlog For Target Epic

Load the sprint backlog (from sprint planning output or `sprint-status.yaml`).
Collect all stories assigned to the target epic into `epic_stories`.

```yaml
sprint_backlog = load("${docs_path}/sprint-status.yaml") || load("${docs_path}/sprint-backlog.md")
epic_stories = sprint_backlog.stories.filter(story => story.epic == target_epic)
created_count = 0
skipped_count = 0
created_stories = []
```

### 2. Iterate And Create Dev-Story Artifacts

Start workflow tracking for `dev-story-batch`.

Load `{scrumMasterAgent}` once before the loop.

For EACH story in `epic_stories`:

```yaml
for story in epic_stories:
  artifact_path = "${bmad_docs}/dev-story-${story.id}.md"

  # Skip if artifact already exists
  if file_exists(artifact_path):
    skipped_count += 1
    output: "⏭️  Skipping ${story.id} — dev-story artifact already exists at ${artifact_path}"
    continue

  # Generate dev-story artifact
  invoke: workflow-engine.execute
  params:
    workflow_xml: "{workflowXml}"
    workflow: "{devStoryWorkflow}"
    inputs:
      story_id: ${story.id}
      story_title: ${story.title}
      output_path: ${bmad_docs}
      constitutional_context: ${constitutional_context}

  created_count += 1
  created_stories.append(story.id)
  output: "✅ Created dev-story artifact: ${artifact_path} (${created_count}/${epic_stories.length})"

# Update sprint-status to mark all created stories as ready-for-dev
for story_id in created_stories:
  invoke: sprint-status.update-story-status
  params:
    story_id: ${story_id}
    status: "ready-for-dev"
```

Finish workflow tracking after all stories are processed.

Display batch summary:
```
📋 Dev-Story Batch Summary
├── Epic: ${target_epic}
├── Total stories: ${epic_stories.length}
├── Created: ${created_count}
├── Skipped (existing): ${skipped_count}
└── All created stories marked as ready-for-dev
```

### 3. Auto-Proceed

Display: "**Proceeding to closeout and handoff...**"

#### Menu Handling Logic:
- After batch dev-story generation completes, load, read fully, and execute `{nextStepFile}`.

#### EXECUTION RULES:
- This is an auto-proceed step with no user choice.
- Halt only if ALL dev-story generation attempts fail or no stories exist for the target epic.
- Individual story failures should be logged but should not block remaining stories.

## SYSTEM SUCCESS/FAILURE METRICS:

### SUCCESS:
- Dev-story artifacts created for all stories in the sprint backlog for the target epic (minus skipped existing ones).
- Sprint status updated to mark created stories as `ready-for-dev`.
- Created and skipped counts are available for closeout reporting.

### SYSTEM FAILURE:
- No stories found in the sprint backlog for the target epic.
- ALL dev-story generation attempts fail.
- Sprint status cannot be updated.

**Master Rule:** Skipping steps is FORBIDDEN.