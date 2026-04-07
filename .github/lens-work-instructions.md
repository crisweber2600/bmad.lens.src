<!-- LENS-WORK ADAPTER -->
# LENS Workbench — Copilot Instructions

## Module Reference

This control repo uses the LENS Workbench module (`lens` v4.0.0):

- **Module path:** `_bmad/lens-work/`
- **Lifecycle contract:** `_bmad/lens-work/lifecycle.yaml`
- **Module version:** See `_bmad/lens-work/module.yaml`
- **Module code:** `lens`

## Agent

The `@lens` agent is defined at `.github/agents/bmad-agent-lens-work-lens.agent.md` and references
the module agent at `_bmad/lens-work/agents/lens.agent.md`.

## Legacy Skills (initiative model)

| Skill | Path |
|-------|------|
| git-state | `_bmad/lens-work/skills/git-state.md` |
| git-orchestration | `_bmad/lens-work/skills/git-orchestration.md` |
| constitution | `_bmad/lens-work/skills/constitution.md` |
| sensing | `_bmad/lens-work/skills/sensing.md` |
| checklist | `_bmad/lens-work/skills/checklist.md` |

## Lens Next Skills (feature model)

| Skill | Path |
|-------|------|
| feature-yaml | `_bmad/lens-work/skills/bmad-lens-feature-yaml/SKILL.md` |
| git-state (next) | `_bmad/lens-work/skills/bmad-lens-git-state/SKILL.md` |
| git-orchestration (next) | `_bmad/lens-work/skills/bmad-lens-git-orchestration/SKILL.md` |
| constitution (next) | `_bmad/lens-work/skills/bmad-lens-constitution/SKILL.md` |
| theme | `_bmad/lens-work/skills/bmad-lens-theme/SKILL.md` |
| init-feature | `_bmad/lens-work/skills/bmad-lens-init-feature/SKILL.md` |
| quickplan | `_bmad/lens-work/skills/bmad-lens-quickplan/SKILL.md` |
| log-problem | `_bmad/lens-work/skills/bmad-lens-log-problem/SKILL.md` |
| status | `_bmad/lens-work/skills/bmad-lens-status/SKILL.md` |
| next | `_bmad/lens-work/skills/bmad-lens-next/SKILL.md` |
| switch | `_bmad/lens-work/skills/bmad-lens-switch/SKILL.md` |
| help | `_bmad/lens-work/skills/bmad-lens-help/SKILL.md` |
| pause-resume | `_bmad/lens-work/skills/bmad-lens-pause-resume/SKILL.md` |
| retrospective | `_bmad/lens-work/skills/bmad-lens-retrospective/SKILL.md` |
| complete | `_bmad/lens-work/skills/bmad-lens-complete/SKILL.md` |
| move-feature | `_bmad/lens-work/skills/bmad-lens-move-feature/SKILL.md` |
| split-feature | `_bmad/lens-work/skills/bmad-lens-split-feature/SKILL.md` |
| dashboard | `_bmad/lens-work/skills/bmad-lens-dashboard/SKILL.md` |
| onboard | `_bmad/lens-work/skills/bmad-lens-onboard/SKILL.md` |
| migrate | `_bmad/lens-work/skills/bmad-lens-migrate/SKILL.md` |
| setup | `_bmad/lens-work/skills/bmad-lens-setup/SKILL.md` |

## Important

- This adapter references module content by path — it NEVER duplicates it
- Do not copy skills, workflows, or lifecycle definitions into `.github/`
- Module updates propagate automatically through path references
- Use `lens-` prefixed prompts for Lens Next; `lens-work.` for legacy
<!-- /LENS-WORK ADAPTER -->
