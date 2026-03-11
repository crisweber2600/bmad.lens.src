# Shared Preflight

**Include with:** Reference this file from any prompt that needs preflight.

**Purpose:** Ensures all authority repos are synchronized before workflow execution.

---

## Preflight Steps

### 1. Check Release Branch

Read the `bmad.lens.release` branch:
```bash
git -C bmad.lens.release branch --show-current
```

### 2. Determine Pull Strategy

**If branch is `alpha` or `beta`:** Run **full preflight** — pull ALL authority repos (do NOT check `.preflight-timestamp` — ALWAYS pull on alpha/beta):

```bash
git -C bmad.lens.release pull origin
git -C {governance-repo-path} pull origin   # path from governance-setup.yaml
```

**Otherwise:** Read `_bmad-output/lens-work/.preflight-timestamp`. 
- If missing or older than today: run the same pulls
- If today's date matches: skip pulls

### 3. Sync .github from Release Repo

After pulling `bmad.lens.release`, check if `.github/` folder has any modified files:

```bash
git -C bmad.lens.release diff --name-only HEAD@{1} HEAD -- .github/
```

If any files changed in `.github/` (or if this is the first pull today), sync them to the control repo's `.github/` folder:

**PowerShell:**
```powershell
if (Test-Path "bmad.lens.release/.github") {
    if (-not (Test-Path ".github")) { New-Item -ItemType Directory -Path ".github" }
    Copy-Item -Recurse -Force "bmad.lens.release/.github/*" ".github/"
}
```

**Bash:**
```bash
if [ -d "bmad.lens.release/.github" ]; then
    mkdir -p .github
    cp -rf bmad.lens.release/.github/* .github/
fi
```

### 4. Update Timestamp

Write today's date to `_bmad-output/lens-work/.preflight-timestamp`.

### 5. Verify Authority Repos

If any authority repo directory is missing, stop and report the failure.

**Exception for /onboard:** If missing repos are reported during onboarding, continue so the workflow can bootstrap/repair those repos.

---

## Authority Repos

| Repo | Purpose |
|------|---------|
| `bmad.lens.release` | Release module with workflows, agents, prompts |
| `{governance-repo-path}` | Governance settings (from `_bmad-output/lens-work/governance-setup.yaml`) |

## Synced Content

| Source | Destination | Content |
|--------|-------------|---------|
| `bmad.lens.release/.github/` | `.github/` | Copilot agents, prompts, instructions |
