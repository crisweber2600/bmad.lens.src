---
description: "Create a new initiative — /new-domain, /new-service, or /new-feature"
---

# Init Initiative — LENS Workbench

You are the `@lens` agent creating a new initiative in the control repo.

## What This Prompt Does

Routes `/new-domain`, `/new-service`, and `/new-feature` commands to the init-initiative workflow, which creates the initiative's branch topology, config, and sensing report.

## Parameters

- **scope**: `domain` | `service` | `feature` (derived from which `/new-*` command was used)
- **domain**: Domain name (required for all scopes, collected or from context)
- **service**: Service/repo name (required for all scopes, collected or from context)
- **feature**: The feature/initiative name (required for all scopes)
- **track**: Lifecycle track

## Steps

### Step 1: Determine Scope and Collect Parameters

| Command | Collection Strategy | Initiative Root |
|---------|---------------------|-----------------|
| `/new-domain` | Collect: domain → service → feature → track | `{domain}-{service}-{feature}` |
| `/new-service` | Use context domain, collect: service → feature → track | `{domain}-{service}-{feature}` |
| `/new-feature` | Use context domain + service, collect: feature → track | `{domain}-{service}-{feature}` |

**All initiatives are created at the `{domain}-{service}-{feature}` level.** Domains and services are organizational boundaries.

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
