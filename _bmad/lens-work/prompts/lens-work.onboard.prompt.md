---
description: "Bootstrap a new control repo and onboard the user to lens-work v2"
---

# setupRepo — LENS Workbench Onboarding

You are the `@lens` agent performing first-time setup of a control repo for lens-work v2.

## What This Prompt Does

1. **Hydrates the control repo structure** — creates `_bmad-output/lens-work/` workspace directories
2. **Chains to /onboard** — runs the full onboarding workflow

## Steps

### Step 0: Run Preflight

Before continuing, run preflight:

1. Read the `bmad.lens.release` branch with `git -C bmad.lens.release branch --show-current`.
2. If branch is `alpha` or `beta`: run **full preflight** — pull ALL authority repos (do NOT check `.preflight-timestamp` — ALWAYS pull on alpha/beta):
   ```bash
   git -C bmad.lens.release pull origin
   git -C .github pull origin
   git -C {governance-repo-path} pull origin   # path from governance-setup.yaml
   ```
   Then write today's date to `_bmad-output/lens-work/.preflight-timestamp`.
3. Otherwise: read `_bmad-output/lens-work/.preflight-timestamp`. If missing or older than today, run the same pulls and update timestamp. If today's date matches, skip pulls.
4. If any authority repo directory is missing: stop and report the failure.

For `/onboard` only: if missing repos are reported, continue onboarding so the workflow can bootstrap/repair those repos.

### Step 1: Hydrate Control Repo Structure

Create the workspace directories if they don't exist:

```
_bmad-output/
└── lens-work/
    ├── personal/
    └── initiatives/
```

### Step 2: Run /onboard

Execute the onboard workflow at `_bmad/lens-work/workflows/utility/onboard/`.

The onboard workflow handles:
- Provider detection from git remote URL
- Authentication validation
- Governance repo verification/clone
- Profile creation (`_bmad-output/lens-work/personal/profile.yaml`)
- TargetProjects bootstrap from governance `repo-inventory.yaml` (auto-clone missing repos)
- Health check
- Next command recommendation

## Prerequisites

- Control repo must be a git repository with a remote configured
- `bmad.lens.release/_bmad/lens-work/` must be accessible (release module)
- `git` available in PATH
