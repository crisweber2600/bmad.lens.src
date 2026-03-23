---
validationDate: 2026-03-23
workflowName: dev
workflowPath: d:/bmad.lens.bmad/bmad.lens.src/_bmad/lens-work/workflows/router/dev
validationStatus: COMPLETE
completionDate: 2026-03-23
---

# Validation Report: dev

**Validation Started:** 2026-03-23
**Validator:** BMAD Workflow Validation System
**Standards Version:** BMAD Workflow Standards

---

## File Structure & Size

**Folder structure assessment:** PASS

- `workflow.md` exists.
- Step files are organized under `steps/` with sequential numbering from `step-01` through `step-05`.
- Folder naming is coherent for a step-file workflow package.
- `data/` now exists and holds extracted reference material for the previously oversized steps.
- `workflow-plan.md` exists and covers the step package.

**File size analysis:** PASS

- `workflow.md` - 68 lines - Good
- `steps/step-01-preflight.md` - 134 lines - Good
- `steps/step-02-story-discovery.md` - 83 lines - Good
- `steps/step-03-story-loop.md` - 169 lines - Good
- `steps/step-04-epic-completion.md` - 125 lines - Good
- `steps/step-05-closeout.md` - 181 lines - Good
- `data/preflight-promotion-and-context.md` - reference file, acceptable
- `data/story-target-repo-routing.md` - reference file, acceptable
- `data/story-implementation-guidance.md` - reference file, acceptable
- `data/story-review-loop.md` - reference file, acceptable

**Issues found:** None.

**Overall status for this section:** PASS

## Frontmatter Validation

**Files checked:** 5 step files

**Overall status:** PASS

**Per-file results:**

- `steps/step-01-preflight.md` - PASS
	- `nextStepFile` and extracted data references are declared and used.
- `steps/step-02-story-discovery.md` - PASS
	- `nextStepFile` is declared and referenced through the body directive.
- `steps/step-03-story-loop.md` - PASS
	- `nextStepFile` and extracted data references are declared and used.
- `steps/step-04-epic-completion.md` - PASS
	- `nextStepFile` is declared and referenced through the body directive.
- `steps/step-05-closeout.md` - PASS
	- Required `name` and `description` are present.
	- No unused frontmatter variables detected.

**Violations:** None.

## Critical Path Violations

### Config Variables (Exceptions)

No config-variable exceptions are required. The entry file uses local relative references and delegates execution through `{entryStep}`.

### Content Path Violations

No content-path violations found in the active workflow sources.

### Dead Links

No broken `nextStepFile` or extracted data-file references were found. All active references resolved on disk.

**Note:** Output-file checks were not applicable in this workflow package.

### Module Awareness

No `bmb`-specific module path assumptions were detected inside this non-`bmb` workflow package.

### Summary

- **CRITICAL:** 0 violations
- **HIGH:** 0 violations
- **MEDIUM:** 0 violations

**Status:** ✅ PASS - Critical path is clean

## Menu Handling Validation

**Overall status:** PASS with minor caution

- No formal markdown menu sections are present in the step package, which is acceptable because `dev` is primarily a control-plane orchestration workflow.
- User choices are represented through inline `ask:` and `offer:` operations inside the workflow logic rather than A/P/C menu blocks.
- No branch transition depends on a missing markdown menu handler.

**Observed prompt points:**

- `steps/step-01-preflight.md` prompts for a missing target path when initiative metadata is incomplete.
- `steps/step-02-story-discovery.md` asks for confirmation before implementing all stories.
- `steps/step-03-story-loop.md` prompts for justification when advisory overrides are needed.
- `steps/step-05-closeout.md` offers the retrospective.

**Assessment:**

- For this router-style workflow, inline prompts are acceptable and keep the operational flow compact.
- If the package is later adapted into a more conversational user-facing workflow, those prompts could be normalized into explicit menu sections.

## Step Type Validation

**Overall status:** PASS

**Per-step classification:**

- `steps/step-01-preflight.md` - Init/control-plane routing step - PASS
- `steps/step-02-story-discovery.md` - Middle discovery step - PASS
- `steps/step-03-story-loop.md` - Middle complex orchestration step - PASS
- `steps/step-04-epic-completion.md` - Middle/final gate step - PASS
- `steps/step-05-closeout.md` - Final closeout step - PASS

**Notes:**

- The extracted `data/` files now support the complex middle steps cleanly.
- The package matches the intended router pattern rather than a template-driven conversation workflow.

## Output Format Validation

**Overall status:** N/A - orchestration workflow

- This package does not produce an internal template-driven document under its own folder.
- It orchestrates external implementation artifacts, review outputs, state files, and retrospective outputs.
- Because the workflow is not a direct document-builder, template and final-polish checks are not applicable.

## Validation Design Check

**Overall status:** N/A

- `dev` is not a standalone validation workflow.
- It contains embedded quality gates, but it does not require its own `steps-v/` validation mode inside this package.
- Current segregation is appropriate for an execution router workflow.

## Instruction Style Check

**Overall status:** PASS

- The instruction style is intentionally mixed but predominantly prescriptive.
- That is appropriate for this domain because the workflow manages branch routing, gate enforcement, review loops, and PR orchestration.
- The extracted reference files improve readability without weakening execution precision.

**Assessment:** Mixed leaning prescriptive, appropriate for a control-plane implementation router.

## Collaborative Experience Check

**Overall Facilitation Quality:** Good

**Step-by-step assessment:**

- `step-01-preflight` - Clear initialization and fallback path for missing target repo metadata
- `step-02-story-discovery` - Good confirmation checkpoint before expensive execution begins
- `step-03-story-loop` - Strong progression through compliance, routing, implementation guidance, and review
- `step-04-epic-completion` - Clear hard-stop gate before post-epic completion
- `step-05-closeout` - Clear finalization and optional retrospective

**Strengths:**

- Strong execution arc from repo resolution to story loop to epic closeout.
- User checkpoints are limited and purposeful.
- The workflow now reads materially better after extracting bulky reference logic to `data/` files.

**Cautions:**

- The workflow is intentionally automation-heavy, so it is less conversational than discovery-oriented workflows.
- Some prompts remain terse because they are embedded in YAML control logic.

**Overall Collaborative Rating:** 4/5

## Subprocess Optimization Opportunities

**Overall status:** ✅ Complete

**Total opportunities:** 2

### Moderate-priority opportunities

1. `steps/step-05-closeout.md`
	 - Current: long reference tables for control-plane rules, output artifacts, error handling, and post-conditions.
	 - Suggested: extract the tables to a `data/closeout-reference.md` file if the step grows further.
	 - Impact: moderate context savings and simpler maintenance.

2. `steps/step-04-epic-completion.md`
	 - Current: long epic gate sequence remains inline.
	 - Suggested: extract PR-wait guidance only if more epic gate branches are added later.
	 - Impact: low current benefit.

**Summary:** The highest-value subprocess optimization was already completed through the new `data/` files. No urgent refactor remains.

## Cohesive Review

**Overall assessment:** Good and ready to use

**Quality evaluation:**

- Goal clarity: Strong
- Logical flow: Strong
- Facilitation quality: Good for an execution router
- User experience: Predictable and disciplined
- Goal achievement: Strong

**Strengths:**

- The repaired workflow is materially easier to follow than the oversized previous version.
- Critical branch and review control points are explicit.
- Supporting `data/` files reduce clutter without obscuring flow.

**Weaknesses:**

- Closeout remains dense.
- Some interactive prompts are inline rather than normalized menu structures.

**Recommendation:** Ready to use. No blocking issues remain.

## Plan Quality Validation

**Plan file:** `workflow-plan.md`

**Overall status:** PASS

**Coverage assessment:**

- Goal alignment: Implemented
- Step structure: 5/5 planned steps present
- Supporting data files: Implemented
- Key state coverage: Implemented in active workflow content
- Output artifact coverage: Implemented

**Requirement-area assessment:**

- Discovery/vision: High quality
- Classification and routing: High quality
- Requirements coverage: High quality
- Design implementation: High quality
- Tools/data support: High quality

**Plan implementation score:** 100%

**Gaps found:** None.

## Summary

**Validation completed:** 2026-03-23

**Overall status:** ✅ PASS

**Validation step results:**

- File Structure & Size: PASS
- Frontmatter Validation: PASS
- Critical Path Violations: PASS
- Menu Handling Validation: PASS with minor caution
- Step Type Validation: PASS
- Output Format Validation: N/A
- Validation Design Check: N/A
- Instruction Style Check: PASS
- Collaborative Experience Check: PASS
- Subprocess Optimization Opportunities: COMPLETE
- Cohesive Review: PASS
- Plan Quality Validation: PASS

**Critical issues:** 0

**Warnings / cautions:** 1 low-severity caution around inline prompt normalization.

**Key strengths:**

- All earlier blocker classes are resolved.
- The workflow now fits BMAD size limits cleanly.
- Extracted reference files improved readability without weakening logic.

**Readiness recommendation:** Ready to use and safe to commit.