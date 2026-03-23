---
name: 'step-04-epic-completion'
description: 'Run epic-level review gates, create the epic PR, and stop until the epic merge completes'
nextStepFile: './step-05-closeout.md'
---

# Step 4: Epic Completion Gate

**Goal:** After all stories finish, run epic-level gates, create the epic PR into the initiative branch, and wait at the hard merge gate.

---

## EXECUTION SEQUENCE

### 1. Epic Completion Gate (Mandatory)

```yaml
current_epic_id = "epic-${session.epic_number}"

read_and_follow: "_bmad/bmm/workflows/3-solutioning/bmad-check-implementation-readiness/workflow.md"
params:
  scope: "epic"
  epic_id: ${current_epic_id}
  stories: "${docs_path}/stories.md"
  implementation_artifacts: "_bmad-output/implementation-artifacts/"
  constitutional_context: ${constitutional_context}

if epic_adversarial.status in ["blocked", "fail", "failed"]:
  error: |
    ⛔ MANDATORY GATE - Epic adversarial review failed for ${current_epic_id}.
    Resolve implementation-readiness findings and re-run /dev.
  halt: true

read_and_follow: "_bmad/core/skills/bmad-party-mode/workflow.md"
params:
  input_file: "${docs_path}/epics.md"
  focus_epic: ${current_epic_id}
  artifacts_path: ${session.target_path}
  output_file: "_bmad-output/implementation-artifacts/epic-${current_epic_id}-party-mode-review.md"
  constitutional_context: ${constitutional_context}

if party_mode.status not in ["pass", "complete"]:
  error: |
    ⛔ MANDATORY GATE - Epic party-mode teardown found unresolved issues for ${current_epic_id}.
    Address _bmad-output/implementation-artifacts/epic-${current_epic_id}-party-mode-review.md and re-run /dev.
  halt: true

invoke: git-orchestration.commit-and-push
params:
  repo_path: ${session.target_path}
  branch: ${session.epic_branch}
  message: "feat(${session.epic_key}): Epic ${session.epic_number} complete - all stories merged"

target_base_branch = session.initiative_branch

invoke: git-orchestration.create-pr
params:
  repo_path: ${session.target_path}
  source_branch: ${session.epic_branch}
  target_branch: ${target_base_branch}
  title: "feat(${session.epic_key}): Epic ${session.epic_number}"
  body: |
    Epic ${session.epic_number} - all ${session.stories_completed.length} stories implemented and reviewed.

    Stories completed:
    ${for sid in session.stories_completed}
    - ✅ ${sid}
    ${endfor}

    Source branch: ${session.epic_branch}
    Target branch: ${target_base_branch}

    This PR was auto-created by /dev after all stories passed code review and epic-level gates.

    ⚠️ All story->epic PRs should be merged before merging this epic->initiative PR.
capture: epic_pr_result

if epic_pr_result.fallback:
  warning: |
    ⚠️ Auto-PR fallback for epic ${session.epic_number}.
    Run this in target repo (${session.target_path}):
    gh pr create --base "${target_base_branch}" --head "${session.epic_branch}" --title "feat(${session.epic_key}): Epic ${session.epic_number}"
else:
  output: |
    ✅ Epic PR auto-created
    ├── Branch: ${session.epic_branch} -> ${target_base_branch}
    └── URL: ${epic_pr_result.pr_url || epic_pr_result.url || epic_pr_result}

output: |
  ⏳ Epic PR Merge Gate - HARD STOP
  ├── PR: ${epic_pr_result.pr_url || epic_pr_result.url || epic_pr_result || '(manual - see fallback above)'}
  ├── Branch: ${session.epic_branch} -> ${target_base_branch}
  ├── ⚠️  Ensure all story->epic PRs are merged first
  └── ⚠️  Please merge this epic PR now. Waiting up to 10 minutes...

invoke: git-orchestration.wait-for-pr-merge
params:
  repo_path: ${session.target_path}
  source_branch: ${session.epic_branch}
  target_branch: ${target_base_branch}
  pr_url: ${epic_pr_result.pr_url || epic_pr_result.url || epic_pr_result || "(manual)"}
  timeout_seconds: 600
capture: epic_merge_wait_result

if epic_merge_wait_result.merged == false:
  output: |
    ❌ Epic PR not merged within 10 minutes - STOPPING.
    ├── Epic: ${session.epic_key}
    ├── PR: ${epic_pr_result.pr_url || epic_pr_result.url || epic_pr_result || '(manual)'}
    ├── Action: Merge all story PRs into epic, then merge epic PR into initiative.
    └── Re-run /dev to continue with post-epic steps.
  invoke: git-orchestration.finish-workflow
  halt: true

output: |
  ✅ Epic PR merged into initiative branch.
  └── ${session.epic_key} integrated into ${target_base_branch}

invoke: git-orchestration.finish-workflow
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`