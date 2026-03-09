---
model: Claude Sonnet 4.6 (copilot)
---

# /preplan Prompt

Route to the preplan phase workflow via the @lens phase router.

1. Run preflight before routing:
   1. Read the `bmad.lens.release` branch with `git -C bmad.lens.release branch --show-current`.
   2. If branch is `alpha` or `beta`: run **full preflight** — pull ALL authority repos:
      ```bash
      git -C bmad.lens.release pull origin
      git -C .github pull origin
      git -C {governance-repo-path} pull origin   # path from governance-setup.yaml
      ```
      Then write today's date to `_bmad-output/lens-work/.preflight-timestamp`.
   3. Otherwise: read `_bmad-output/lens-work/.preflight-timestamp`. If missing or older than today, run the same pulls and update timestamp. If today's date matches, skip pulls.
   4. If any authority repo directory is missing: stop and report the failure.
2. Load `lifecycle.yaml` from the lens-work module
3. Invoke phase routing for `preplan`:
   - Validate no predecessor phase required (preplan is the first phase)
   - Check current track includes `preplan` in its phases
   - Create phase branch `{initiative-root}-small-preplan`
4. Execute `workflows/router/preplan/workflow.md`
