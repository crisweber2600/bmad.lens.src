---
name: 'step-02-readiness'
description: 'Resolve constitutional context, run readiness validation, and enforce compliance gating'
nextStepFile: './step-03-sprint-planning.md'
---

# Step 2: Readiness And Compliance

**Goal:** Load constitutional context, validate implementation readiness, and block SprintPlan when compliance failures remain unresolved.

---

## EXECUTION SEQUENCE

### 1. Constitutional Context Injection (Required)

```yaml
constitutional_context = invoke("constitution.resolve-context")

if constitutional_context.status == "parse_error":
  error: |
    Constitutional context parse error:
    ${constitutional_context.error_details.file}
    ${constitutional_context.error_details.error}

session.constitutional_context = constitutional_context
```

### 2. Re-run Readiness Checklist

```yaml
# RESOLVED: bmm.readiness-checklist -> Read fully and follow:
#   _bmad/bmm/workflows/3-solutioning/bmad-check-implementation-readiness/workflow.md
# Run in validate mode (check existing artifacts, don't create new ones)
# Agent persona: Bob (Scrum Master) - _bmad/bmm/agents/sm.md
read_and_follow: "_bmad/bmm/workflows/3-solutioning/bmad-check-implementation-readiness/workflow.md"
params:
  mode: "validate"
  constitutional_context: ${constitutional_context}

if readiness.blockers > 0:
  output: |
    ⚠️ Readiness blockers found:
    ${readiness.blockers}

    Resolve blockers before proceeding to sprint planning.
  exit: 1
```

### 3. Constitutional Compliance Gate (Required)

```yaml
compliance_targets:
  - path: "${docs_path}/product-brief.md"
    type: "PRD"
  - path: "${docs_path}/prd.md"
    type: "PRD"
  - path: "${docs_path}/architecture.md"
    type: "Architecture document"
  - path: "${docs_path}/epics.md"
    type: "Story/Epic"
  - path: "${docs_path}/stories.md"
    type: "Story/Epic"
  - path: "${docs_path}/readiness-checklist.md"
    type: "Story/Epic"

compliance_failures = []
compliance_warnings = []
compliance_checked = 0

for target in compliance_targets:
  if file_exists(target.path):
    compliance_result = invoke("constitution.compliance-check")
    params:
      artifact_path: ${target.path}
      artifact_type: ${target.type}
      constitutional_context: ${constitutional_context}

    compliance_checked = compliance_checked + 1

    if compliance_result.fail_count > 0:
      compliance_failures.append("${target.path}: ${compliance_result.fail_count} FAIL")

    if compliance_result.warn_count > 0:
      compliance_warnings.append("${target.path}: ${compliance_result.warn_count} WARN")

if compliance_failures.length > 0:
  output: |
    FAIL Constitutional compliance failures detected:
    ${compliance_failures.join("\n")}

    Sprint planning blocked until violations are resolved.
  exit: 1
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`