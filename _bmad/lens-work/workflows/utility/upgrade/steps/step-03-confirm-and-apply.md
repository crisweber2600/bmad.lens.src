---
name: 'step-03-confirm-and-apply'
description: 'Render the rename plan, confirm with the user, apply local branch renames, output remote push commands'
nextStepFile: './step-04-write-version.md'
---

# Step 3: Confirm And Apply Renames

**Goal:** Display the full rename plan and phase-branch advisories, ask the user to confirm, rename local branches, and output the `git push` commands needed to sync remotes.

---

## EXECUTION SEQUENCE

### 1. Render The Plan

```yaml
if rename_plan.length == 0 and phase_branch_notes.length == 0:
  output: "ℹ️  No v2 branches detected. Only LENS_VERSION will be written."
else:
  output: |
    ## 📋 Upgrade Plan — Local Branch Renames

    | Current (v2) | New (v3) |
    |---|---|
    ${rename_plan.map(r => `| \`${r.from}\` | \`${r.to}\` |`).join('\n')}

    ${phase_branch_notes.length > 0 ? "## ⚠️  Phase Branch Advisories (not renamed)\n\n" +
      phase_branch_notes.map(n => `- \`${n.branch}\` — ${n.note}`).join('\n') : ""}

    **Current branch:** ${invoke_command("git branch --show-current")}

    > Phase branches have no v3 equivalent. Verify they are merged into their parent milestone branch before deleting.
    > Local renames will be applied immediately. Remote branches are NOT renamed automatically — commands will be provided.
```

### 2. Confirm

```yaml
if rename_plan.length == 0:
  confirmed = true  # Nothing to confirm, just write version
else:
  user_input = ask_user("Apply ${rename_plan.length} local branch rename(s) and write LENS_VERSION? [y/N]")
  confirmed = user_input.trim().toLowerCase() == "y" or user_input.trim().toLowerCase() == "yes"

if not confirmed:
  output: "❌ Upgrade cancelled. No changes made."
  STOP()
```

### 3. Apply Local Renames

```yaml
renames_applied = 0
current_branch = invoke_command("git branch --show-current").trim()
rename_errors = []

for rename in rename_plan:
  if rename.from == current_branch:
    # Rename current branch
    result = invoke_command("git branch -m ${rename.from} ${rename.to}")
    if result.exitCode == 0:
      renames_applied++
      output: "  ✅ Renamed (current): `${rename.from}` → `${rename.to}`"
    else:
      rename_errors.push({ rename: rename, error: result.stderr })
      output: "  ❌ Failed to rename `${rename.from}`: ${result.stderr}"
  else:
    result = invoke_command("git branch -m ${rename.from} ${rename.to}")
    if result.exitCode == 0:
      renames_applied++
      output: "  ✅ Renamed: `${rename.from}` → `${rename.to}`"
    else:
      rename_errors.push({ rename: rename, error: result.stderr })
      output: "  ❌ Failed to rename `${rename.from}`: ${result.stderr}"
```

### 4. Output Remote Push Commands

```yaml
if renames_applied > 0:
  output: |
    ## Remote Sync Commands

    Run these commands to update remote branches (review before pushing):

    ```bash
    ${rename_plan
      .filter(r => !rename_errors.some(e => e.rename.from == r.from))
      .map(r => `git push origin ${r.to}:${r.to} && git push origin --delete ${r.from}`)
      .join('\n')}
    ```

output: |
  ✅ Renames applied: ${renames_applied}/${rename_plan.length}
  ${rename_errors.length > 0 ? "⚠️  Errors: " + rename_errors.length : ""}
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{nextStepFile}`
