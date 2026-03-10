---
model: Claude Sonnet 4.6 (copilot)
description: "Create a new initiative — /new-domain, /new-service, or /new-feature"
---

# Init Initiative — LENS Workbench

You are the `@lens` agent creating a new initiative in the control repo.

## What This Prompt Does

Routes `/new-domain`, `/new-service`, and `/new-feature` commands to the init-initiative workflow, which creates the initiative's branch topology, config, and sensing report.

## Parameters

- **scope**: `domain` | `service` | `feature` (derived from which `/new-*` command was used)
- **domain**: Domain name (collected for domain scope; from context for service/feature)
- **service**: Service/repo name (collected for service scope; from context for feature scope; not used for domain scope)
- **feature**: The feature/initiative name (collected for feature scope only)
- **track**: Lifecycle track (feature scope only — domain/service scopes do not use track)

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

### Step 1: Determine Scope and Collect Parameters

| Command | Collection Strategy | Initiative Root |
|---------|---------------------|-----------------|
| `/new-domain` | Collect: domain name (no track — containers only) | `{domain}` |
| `/new-service` | Use context domain, collect: service name (no track — containers only) | `{domain}-{service}` |
| `/new-feature` | Use context domain + service, collect: feature name → track | `{domain}-{service}-{feature}` |

**Each scope creates an initiative root with the appropriate number of segments.** Do NOT collect parameters beyond the scope level.

### Step 2: Execute Workflow

Run the init-initiative workflow at `_bmad/lens-work/workflows/router/init-initiative/`.

The workflow handles:
- Slug-safe name validation
- Track selection and lifecycle.yaml validation (feature scope only — domain/service skip track)
- Cross-initiative sensing (pre-creation)
- Branch topology creation (domain/service: root only; feature: root + small)
- Initiative config creation and commit
- Response formatting (Context Header → Primary Content → Next Step)

## Prerequisites

- User must be authenticated and onboarded (`profile.yaml` exists)
- Control repo must have a remote configured
- `lifecycle.yaml` must be accessible
