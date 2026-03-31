---
name: 'step-04-write-version'
description: 'Write LENS_VERSION to the control repo root, commit, and report completion'
---

# Step 4: Write LENS_VERSION And Report

**Goal:** Stamp the control repo with the target schema version, commit the change, and report the completed upgrade with next-step guidance.

---

## EXECUTION SEQUENCE

### 1. Write LENS_VERSION

```bash
printf '%s.0.0\n' "${target_version}" > LENS_VERSION
```

```yaml
version_string = "${target_version}.0.0"
write_file("LENS_VERSION", version_string + "\n")

output: "📝 Wrote LENS_VERSION: ${version_string}"
```

### 2. Commit

```bash
git add LENS_VERSION
git commit -m "chore: upgrade to LENS v${target_version} schema"
```

```yaml
invoke_command("git add LENS_VERSION")
commit_result = invoke_command("git commit -m 'chore: upgrade to LENS v${target_version} schema'")

if commit_result.exitCode != 0:
  output: "⚠️  Commit failed: ${commit_result.stderr}. LENS_VERSION was written but not committed."
else:
  output: "✅ Committed LENS_VERSION"
```

### 3. Report

```yaml
output: |
  ## ✅ Upgrade Complete

  | Field | Value |
  |---|---|
  | Previous version | ${detected_version} |
  | New version | ${version_string} |
  | Branches renamed | ${renames_applied || 0} |

  ${rename_plan && rename_plan.length > 0 ? "⚠️  Remember to push renamed branches to your remote — see the commands above." : ""}

  **Next:** Run `/next` to resume lifecycle workflow.
```
