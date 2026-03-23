---
name: 'step-03-story-loop'
description: 'Execute the per-story implementation loop, review gate, PR creation, and BMAD control-plane updates'
nextStepFile: './step-04-epic-completion.md'
targetRepoRoutingData: '../data/story-target-repo-routing.md'
implementationGuidanceData: '../data/story-implementation-guidance.md'
reviewLoopData: '../data/story-review-loop.md'
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

### 2. Story Constitution Check (Required)

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

### 3. Pre-Implementation Gates (Required)

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

### 4. Target Repo Routing, Implementation Guidance, And Review Loop

Load and execute the following references inside the active story iteration:

- `{targetRepoRoutingData}` for initiative, epic, and story branch routing plus the dev write guard
- `{implementationGuidanceData}` for constitutional implementation guidance and per-task commit rules
- `{reviewLoopData}` for code review, party-mode teardown, story PR creation, and BMAD control-plane completion updates

### 5. End-Of-Loop Summary

```yaml
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

**NEXT:** Read fully and follow: `{nextStepFile}`