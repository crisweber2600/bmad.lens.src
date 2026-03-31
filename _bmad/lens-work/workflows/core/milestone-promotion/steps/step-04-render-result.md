---
name: 'step-04-render-result'
description: 'Render the promotion result and show the remaining promotion chain'
---

# Step 4: Render Promotion Result

**Goal:** Report the created promotion PR and show the next promotion opportunities in the lifecycle.

---

## EXECUTION SEQUENCE

### 1. Report The Promotion Result

```yaml
output: |
  ✅ Promotion PR created: ${promotion_pr.Url || promotion_pr.url || promotion_pr}

  [PROMOTE] ${initiative_root} ${current_milestone}->${next_milestone} - Milestone Gate

  The PR requires review and merge to complete promotion.
  Sensing: ${sensing_result.overlap_count || 0} overlapping initiative(s) detected.

  Promotion chain:
  - Current completed: ${current_milestone} -> ${next_milestone}
  - Next available after merge: follow the lifecycle gates for ${next_milestone}
```