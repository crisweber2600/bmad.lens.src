---
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
- **track**: Lifecycle track

## Steps

### Step 0: Run Preflight

Before continuing, run preflight:

- If the `bmad.lens.release` branch is `alpha` or `beta`, force a full preflight run (equivalent to `/preflight`) on every command invocation.
- For all other branches, run standard session preflight (daily freshness).
- If preflight fails for missing authority repos, stop and report the failure.

### Step 1: Determine Scope and Collect Parameters

| Command | Collection Strategy | Initiative Root |
|---------|---------------------|-----------------|
| `/new-domain` | Collect: domain name → track | `{domain}` |
| `/new-service` | Use context domain, collect: service name → track | `{domain}-{service}` |
| `/new-feature` | Use context domain + service, collect: feature name → track | `{domain}-{service}-{feature}` |

**Each scope creates an initiative root with the appropriate number of segments.** Do NOT collect parameters beyond the scope level.

### Step 2: Execute Workflow

Run the init-initiative workflow at `_bmad/lens-work/workflows/router/init-initiative/`.

The workflow handles:
- Slug-safe name validation
- Track selection and lifecycle.yaml validation
- Cross-initiative sensing (pre-creation)
- Branch topology creation (root + small only)
- Initiative config creation and commit
- Response formatting (Context Header → Primary Content → Next Step)

## Prerequisites

- User must be authenticated and onboarded (`profile.yaml` exists)
- Control repo must have a remote configured
- `lifecycle.yaml` must be accessible
