---
name: 'step-03-story-loop'
description: 'Execute the per-story implementation loop, review gate, PR creation, and BMAD control-plane updates'
nextStepFile: './step-04-epic-completion.md'
---

# Step 3: Story Implementation Loop

**Goal:** For each story in the epic, enforce constitutional gates, route implementation into the TargetProject repo, run review loops, and create the story PR before moving to the next story.

---

## EXECUTION SEQUENCE

### 1. Story Loop

**For each story in the epic, execute the sequence below before moving to the next story.**

```yaml
for story_idx, story_file in enumerate(session.story_files):
  story_id = extract_story_id(story_file)

  output: |
    ═══════════════════════════════════════════
    📖 Story ${story_idx + 1}/${session.story_files.length}: ${story_id}
    ═══════════════════════════════════════════
```

### 2. Load Story

```yaml
  dev_story = load(story_file)
  dev_story_source = story_file
  id = story_id

  output: |
    🚀 Story: ${dev_story.title}
    **Source:** ${dev_story_source}
    **Acceptance Criteria:**
    ${dev_story.acceptance_criteria}

    **Technical Notes:**
    ${dev_story.technical_notes}

    **Branch:** ${initiative.initiative_root}-dev
```

### 3. Story Constitution Check (Required)

```yaml
dev_story_path = dev_story_source

dev_story_compliance = invoke("constitution.compliance-check")
params:
  artifact_path: ${dev_story_path}
  artifact_type: "Story/Epic"
  constitutional_context: ${constitutional_context}

if dev_story_compliance.article_gate_results.failed_gates > 0:
  display: dev_story_compliance.article_gate_results

  if enforcement_mode == "enforced":
    invoke: constitution.auto-resolve-gate-block
    params:
      failed_gates: ${dev_story_compliance.article_gate_results}
      artifact_path: ${dev_story_path}
      artifact_type: "Story/Epic"
      initiative_id: ${initiative.id}
      source_branch: current_branch()
      gate_stage: "dev-story-compliance"
    halt: true
  else:
    warning: |
      ⚠️ Dev story has ${dev_story_compliance.article_gate_results.failed_gates} article gate warning(s).
    invoke: constitution.record-complexity-tracking
    params:
      article_gate_results: ${dev_story_compliance.article_gate_results}
      initiative_id: ${initiative.id}
      phase: "dev"

if dev_story_compliance.fail_count > 0 and enforcement_mode == "enforced":
  invoke: constitution.auto-resolve-gate-block
  params:
    fail_count: ${dev_story_compliance.fail_count}
    artifact_path: ${dev_story_path}
    artifact_type: "Story/Epic"
    initiative_id: ${initiative.id}
    source_branch: current_branch()
    gate_stage: "dev-story-compliance-legacy"
  halt: true
```

### 4. Pre-Implementation Gates (Required)

```yaml
article_gates = invoke("constitution.generate-article-gates")
params:
  constitutional_context: ${constitutional_context}
  artifact_path: ${dev_story_path}
  artifact_type: "Story/Epic"

output: |
  ═══ Pre-Implementation Gates ═══
  ${for gate in article_gates.gates}
  Gate ${gate.article_id}: ${gate.title} (${gate.source_layer})  ${gate.status == "pass" ? "✓ PASS" : "✗ FAIL"}
    ${for item in gate.check_items}
    ${item.status == "pass" ? "✓" : "✗"} ${item.description}
      ${if item.status == "fail"}→ ${item.violation}${endif}
    ${endfor}
  ${endfor}
  ── Summary ──
    Passed: ${article_gates.passed_gates}/${article_gates.total_gates} gates
    Mode: ${enforcement_mode}

if article_gates.failed_gates > 0:
  if enforcement_mode == "enforced":
    invoke: constitution.auto-resolve-gate-block
    params:
      failed_gates: ${article_gates}
      artifact_path: ${dev_story_path}
      artifact_type: "Story/Epic"
      initiative_id: ${initiative.id}
      source_branch: current_branch()
      gate_stage: "pre-implementation-gates"
    halt: true
  else:
    output: |
      ⚠️ ${article_gates.failed_gates} gate(s) have warnings (advisory mode).
    for gate in article_gates.gates where gate.status == "fail":
      ask: |
        Override gate ${gate.article_id}: ${gate.title}?
        Provide justification and simpler alternative considered:
      invoke: constitution.record-complexity-tracking
      params:
        gate: ${gate}
        initiative_id: ${initiative.id}
        phase: "dev"
        justification: ${user_justification}

checklist_gate = invoke("constitution.checklist-quality-gate")
params:
  bmad_docs: ${bmad_docs}
  docs_path: ${docs_path}
  initiative_id: ${initiative.id}
```

### 5. Checkout Target Repo - Initiative, Epic, And Story Branch Management

```yaml
story_key = story_id
epic_num = session.epic_number
epic_key = "epic-${epic_num}"

initiative_id = initiative.id || "init-1"
session.initiative_id = initiative_id

initiative_branch = "feature/${initiative_id}"
epic_branch = "feature/${initiative_id}-${epic_key}"
story_branch = "feature/${initiative_id}-${epic_key}-${story_key}"

target_path = session.target_path
target_repo = session.target_repo

cd "${target_path}"
git fetch origin
default_branch_check = exec("git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo ''")
if default_branch_check == '':
  for candidate in ["develop", "main", "master"]:
    if exec("git rev-parse --verify origin/${candidate} 2>/dev/null").exit_code == 0:
      default_branch_check = candidate
      break
git checkout "${default_branch_check}"
git pull origin "${default_branch_check}"
output: |
  🔄 Target repo synced - pulled latest from ${default_branch_check}
  └── Path: ${target_path}

invoke: git-orchestration.ensure-initiative-branch
params:
  target_repo_path: "${target_path}"
  initiative_id: "${initiative_id}"

invoke: git-orchestration.ensure-epic-branch
params:
  target_repo_path: "${target_path}"
  initiative_id: "${initiative_id}"
  epic_key: "${epic_key}"
  epic_branch: "${epic_branch}"
  initiative_branch: "${initiative_branch}"

if story_idx == 0:
  parent_branch = epic_branch
else:
  prev_story_id = extract_story_id(session.story_files[story_idx - 1])
  parent_branch = "feature/${initiative_id}-${epic_key}-${prev_story_id}"

invoke: git-orchestration.ensure-story-branch
params:
  target_repo_path: "${target_path}"
  initiative_id: "${initiative_id}"
  epic_key: "${epic_key}"
  story_key: "${story_key}"
  story_branch: "${story_branch}"
  parent_branch: "${parent_branch}"

session.initiative_id = "${initiative_id}"
session.initiative_branch = "${initiative_branch}"
session.epic_key = "${epic_key}"
session.epic_branch = "${epic_branch}"
session.story_branch = "${story_branch}"

resolved_ib_file = "${target_path}/.lens-work-integration-branch"
if file_exists(resolved_ib_file):
  session.resolved_integration_branch = read_file(resolved_ib_file).trim()
else:
  session.resolved_integration_branch = target_repo.default_branch || "develop"

actual_branch = exec("git -C ${target_path} branch --show-current").stdout.trim()
if actual_branch != story_branch:
  FAIL: |
    ❌ Branch checkout assertion failed after ensure-story-branch
    ├── Expected: ${story_branch}
    ├── Actual:   ${actual_branch}
    ├── All task commits MUST go to the story branch
    └── Epic branch receives code ONLY via story->epic PR merges

output: |
  📂 Target Repo Ready - ALL implementation goes here (NOT bmad.lens.release)
  ├── Repo: ${target_repo.name}
  ├── Path: ${target_path}
  ├── Initiative: ${initiative_id}
  ├── Initiative Branch: ${initiative_branch}
  ├── Epic Branch: ${epic_branch}
  ├── Story Branch: ${story_branch} (checked out ✅ VERIFIED)
  ├── Parent Branch: ${parent_branch} (${story_idx == 0 ? 'from epic' : 'chained from prev story'})
  ├── Branch Chain: ${story_branch} -> ${epic_branch} -> ${initiative_branch} -> ${session.resolved_integration_branch}
  ├── Auto-commit: ON (tasks auto-committed after completion)
  ├── Auto-PR: ON (PR created after code review, no wait)
  ├── ⚠️  Commits go to STORY branch only - epic branch is merge-only
  └── ⚠️  bmad.lens.release is READ-ONLY - never write there
```

### 6. Verify Working Directory - Dev Write Guard

```yaml
cd "${session.target_path}"
actual_dir = exec("pwd").stdout.trim()

target_canonical = canonicalize(session.target_path)
actual_canonical = canonicalize(actual_dir)

if actual_canonical contains "bmad.lens.release":
  FAIL: |
    ❌ Dev Write Guard - BLOCKED: Working directory is inside bmad.lens.release
    ├── Actual: ${actual_dir}
    ├── bmad.lens.release is a READ-ONLY authority repo
    ├── It contains BMAD framework code, NOT implementation targets
    └── Implementation MUST happen in: ${session.target_path}

if actual_canonical does not start with target_canonical:
  FAIL: |
    ❌ Dev Write Guard - Working directory mismatch
    ├── Expected: ${session.target_path}
    ├── Actual: ${actual_dir}
    └── All /dev implementation writes MUST be inside the TargetProject repo.

output: |
  🔒 Dev Write Guard - PASSED
  ├── Working directory: ${actual_dir}
  ├── Scoped to TargetProject repo: ${session.target_path}
  └── ⚠️  bmad.lens.release is READ-ONLY - never write there
```

### 7. Implementation Guidance, Constitutional Context, And Review Loop

```yaml
articles = constitutional_context.resolved.articles

tdd_articles = filter(articles, rule_text contains "test" or "TDD" or "test-first")
arch_articles = filter(articles, rule_text contains "simplicity" or "abstraction" or "library")
quality_articles = filter(articles, rule_text contains "observability" or "logging" or "coverage")
integration_articles = filter(articles, rule_text contains "integration" or "contract" or "mock")

complexity_tracking = load_if_exists("${bmad_docs}/complexity-tracking.md")
override_count = count_entries(complexity_tracking) if complexity_tracking else 0
```

```text
🔧 Implementation Mode - Story ${story_idx + 1}/${session.story_files.length}

You're now working in: ${target_path}
⚠️  THIS is the TargetProject repo - NOT bmad.lens.release (which is read-only).

${if session.special_instructions}
═══ Special Instructions (User-Provided) ═══
${session.special_instructions}
══════════════════════════════════════════════
Apply these instructions to ALL implementation decisions for this story.
${endif}

═══ Constitutional Guidance ═══

${if tdd_articles}
🧪 Test-First Requirements:
${for article in tdd_articles}
  Article ${article.article_id}: ${article.title}
  -> ${article.rule_text_summary}
${endfor}
  ⚡ Action: Write tests FIRST. Verify they FAIL. Then implement.
${endif}

${if arch_articles}
🏗️ Architecture Constraints:
${for article in arch_articles}
  Article ${article.article_id}: ${article.title}
  -> ${article.rule_text_summary}
${endfor}
${endif}

${if quality_articles}
📊 Quality Requirements:
${for article in quality_articles}
  Article ${article.article_id}: ${article.title}
  -> ${article.rule_text_summary}
${endfor}
${endif}

${if integration_articles}
🔗 Integration Rules:
${for article in integration_articles}
  Article ${article.article_id}: ${article.title}
  -> ${article.rule_text_summary}
${endfor}
${endif}

${if override_count > 0}
⚠️ Active Overrides: ${override_count} complexity tracking entries
   Review: ${bmad_docs}/complexity-tracking.md
${endif}

═══════════════════════════════

**Per-Task Commit Rule:**
- BEFORE each commit, verify you are on the STORY branch.
- After completing EACH task/subtask, immediately commit and push.
- Do NOT batch task commits - each task gets its own commit.
- Commit body MUST include Story, Task, and Epic metadata.
- Push target MUST specify `origin "${story_branch}"` - never bare `git push`.
- NEVER commit directly to `${epic_branch}` - epic branch receives code ONLY via merged PRs.

**Remember:**
- ALL file writes go to ${target_path} (the TargetProject repo) - NEVER to bmad.lens.release.
- ALL commits go to the STORY branch - NEVER to the epic or integration branch.
- Follow constitutional articles above during implementation.
- Follow special instructions (if provided) for all implementation decisions.
- Commit after EACH task (not after all tasks).
- Return to BMAD directory when story implementation is complete.
```

```yaml
if article_gates and article_gates.failed_gates > 0 and enforcement_mode == "enforced":
  halt: true
  output: |
    ⛔ BLOCKED - Unresolved enforced gate failures detected at Step 7
    ├── ${article_gates.failed_gates} gate(s) still failing
    ├── Resolve violations and re-run /dev
    └── Implementation cannot proceed until all enforced gates pass
else:
  output: |
    ✅ No blockers - proceeding with story ${story_id} implementation
    ├── All pre-implementation gates passed
    ├── Agent will implement story tasks in the target repo
    ├── Each task will be committed individually
    └── Code review will run automatically after all tasks complete

# After all tasks are implemented and committed, proceed to the review loop.

story_check = load("${dev_story_path}")
story_status_check = story_check.status || story_check.Status || "unknown"
if story_status_check not in ["review", "in-progress"]:
  error: |
    ⛔ Code review blocked - story status is "${story_status_check}", not ready for review.
    Complete implementation and signal @lens done before proceeding.
  halt: true

invoke: git-orchestration.start-workflow
params:
  workflow_name: code-review

agent_persona: "_bmad/bmm/agents/qa.md"
read_and_follow: "_bmad/bmm/workflows/4-implementation/bmad-code-review/workflow.md"
params:
  target_repo: "${target_path}"
  branch: "${session.story_branch}"
  constitutional_context: ${constitutional_context}
  auto_fix_rerun: true
  auto_fix_severities: "CRITICAL,HIGH,MEDIUM"
  max_review_passes: 2
  on_max_passes: "needs_manual"

refreshed_context = invoke("constitution.resolve-context")
if refreshed_context.status != "parse_error":
  session.constitutional_context = refreshed_context

code_review_path = "_bmad-output/implementation-artifacts/code-review-${id}.md"
code_review_compliance = invoke("constitution.compliance-check")
params:
  artifact_path: ${code_review_path}
  artifact_type: "Code file"
  constitutional_context: ${session.constitutional_context}

if code_review_compliance.article_gate_results:
  review_gates = code_review_compliance.article_gate_results
  if review_gates.failed_gates > 0:
    output: |
      ═══ Post-Review Constitutional Re-Validation ═══
      ${for gate in review_gates.gates where gate.status == "fail"}
      ✗ Article ${gate.article_id}: ${gate.title} (${gate.source_layer})
        ${for item in gate.failed_items}
        -> ${item.violation}
        ${endfor}
      ${endfor}
    if enforcement_mode == "enforced":
      invoke: constitution.auto-resolve-gate-block
      params:
        failed_gates: ${review_gates}
        artifact_path: ${code_review_path}
        artifact_type: "Code file"
        initiative_id: ${initiative.id}
        source_branch: current_branch()
        gate_stage: "post-review-revalidation"
      halt: true
    else:
      warning: |
        ⚠️ ${review_gates.failed_gates} article gate warning(s) on code review.

complexity_tracking = load_if_exists("${bmad_docs}/complexity-tracking.md")

if code_review_compliance.fail_count > 0 and enforcement_mode == "enforced":
  invoke: constitution.auto-resolve-gate-block
  params:
    fail_count: ${code_review_compliance.fail_count}
    artifact_path: ${code_review_path}
    artifact_type: "Code file"
    initiative_id: ${initiative.id}
    source_branch: current_branch()
    gate_stage: "post-review-compliance-legacy"
  halt: true

read_and_follow: "_bmad/core/skills/bmad-party-mode/workflow.md"
params:
  input_file: ${code_review_path}
  artifacts_path: ${target_path}
  output_file: "_bmad-output/implementation-artifacts/party-mode-review-${story_id}.md"
  constitutional_context: ${session.constitutional_context}
  complexity_tracking: ${complexity_tracking}

if party_mode.status not in ["pass", "complete"]:
  error: |
    Party mode teardown found unresolved issues for story ${story_id}.
    Address _bmad-output/implementation-artifacts/party-mode-review-${story_id}.md and fix issues.
  halt: true

reviewed_story = load(${dev_story_path})
reviewed_story_status = reviewed_story.status || reviewed_story.Status || reviewed_story.story_status || "unknown"
if reviewed_story_status != "done":
  output: |
    ⛔ PR blocked for ${story_id}
    ├── Post-review story status: ${reviewed_story_status}
    ├── Meaning: review follow-ups or unresolved fixes remain
    └── Action: resolve review items and re-review

  invoke: git-orchestration.finish-workflow
  halt: true

invoke: git-orchestration.create-pr
params:
  repo_path: ${target_path}
  source_branch: ${session.story_branch}
  target_branch: ${session.epic_branch}
  title: "feat(${session.epic_key}): ${story_id}"
  body: |
    Story ${story_id} completed and passed the dev -> review -> fix gate.

    Source branch: ${session.story_branch}
    Target branch: ${session.epic_branch}

    This PR was auto-created by /dev only after review fixes were resolved.
capture: story_pr_result

if story_pr_result.fallback:
  warning: |
    ⚠️ Auto-PR fallback triggered for story ${story_id}.
    Run this in target repo (${target_path}):
    gh pr create --base "${session.epic_branch}" --head "${session.story_branch}" --title "feat(${session.epic_key}): ${story_id}"
else:
  output: |
    ✅ Story PR auto-created
    ├── Branch: ${session.story_branch} -> ${session.epic_branch}
    └── URL: ${story_pr_result.pr_url || story_pr_result.url || story_pr_result}

output: |
  📋 Story PR created - continuing to next story (no wait).
  ├── Story: ${story_id}
  ├── PR: ${story_pr_result.pr_url || story_pr_result.url || story_pr_result || '(manual - see fallback above)'}
  └── ⚠️  Merge story PRs into epic before epic completion gate.

invoke: git-orchestration.finish-workflow

session.stories_completed.append(story_id)

invoke: git-orchestration.commit-and-push
params:
  paths:
    - "_bmad-output/lens-work/initiatives/${initiative.id}.yaml"
    - "_bmad-output/implementation-artifacts/"
  message: "[lens-work] /dev: Story ${story_id} complete - ${story_idx + 1}/${session.story_files.length}"
  branch: "${initiative.initiative_root}-dev"

output: |
  ✅ Story ${story_id} complete (${story_idx + 1}/${session.story_files.length})
  ├── Stories completed: ${session.stories_completed.length}
  └── Stories remaining: ${session.story_files.length - session.stories_completed.length}

endfor

output: |
  ═══════════════════════════════════════════
  🎉 All ${session.stories_completed.length} stories in Epic ${session.epic_number} implemented!
  ═══════════════════════════════════════════
  ${for sid in session.stories_completed}
  ✅ ${sid}
  ${endfor}
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{project-root}/_bmad/lens-work/workflows/router/dev/steps/step-04-epic-completion.md`