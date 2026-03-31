---
name: 'step-02-plan-renames'
description: 'Scan local branches and compute the rename plan from migration descriptors'
nextStepFile: './step-03-confirm-and-apply.md'
---

# Step 2: Branch Scan And Rename Plan

**Goal:** List all local branches, apply the v2 audience-to-milestone mapping from the migration descriptor, and produce a `rename_plan` and `phase_branch_notes` list.

---

## EXECUTION SEQUENCE

### 1. Scan Local Branches

```bash
git branch --format='%(refname:short)'
```

```yaml
branch_scan = invoke_command("git branch --format='%(refname:short)'").split('\n').map(b => b.trim()).filter(b => b != "")
```

### 2. Build Audience-To-Milestone Map

Audience-to-milestone token mapping (from migration descriptor `changes`):

```yaml
audience_map = {
  "small":  "techplan",
  "medium": "devproposal",
  "large":  "sprintplan",
  "base":   "dev-ready"
}

# v2 audience-root suffix patterns: {root}-{audience}
# v2 phase-branch suffix patterns:  {root}-{audience}-{phase}
audience_tokens = keys(audience_map)  # ["small", "medium", "large", "base"]
```

### 3. Classify Each Branch

```yaml
rename_plan = []
phase_branch_notes = []

for branch in branch_scan:
  # Split branch name into segments to detect audience token position
  segments = branch.split("-")

  # Find last occurrence of an audience token
  audience_idx = last_index_where(segments, s => audience_tokens.includes(s))

  if audience_idx == -1:
    continue  # No audience token — not a v2 migration candidate

  audience_token = segments[audience_idx]
  milestone_token = audience_map[audience_token]

  # Determine if this is a phase branch (has segments after the audience token)
  trailing_segments = segments.slice(audience_idx + 1)

  if trailing_segments.length == 0:
    # Pure audience-root branch: {root}-{audience} → {root}-{milestone}
    init_root = segments.slice(0, audience_idx).join("-")
    new_name = init_root + "-" + milestone_token
    rename_plan.push({ from: branch, to: new_name, type: "milestone-root" })
  else:
    # Phase branch: {root}-{audience}-{phase} — no v3 equivalent
    phase_branch_notes.push({
      branch: branch,
      note: "v2 phase branch — no v3 equivalent. Verify merged, then delete."
    })

output: |
  📋 Branch scan complete
  ├── Total local branches: ${branch_scan.length}
  ├── Milestone renames planned: ${rename_plan.length}
  └── Phase branch advisories: ${phase_branch_notes.length}
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`
