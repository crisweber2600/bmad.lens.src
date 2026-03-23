---
name: 'step-02-story-discovery'
description: 'Handle batch-mode requests and discover the ordered story set for the target epic'
nextStepFile: './step-03-story-loop.md'
---

# Step 2: Batch Mode And Story Discovery

**Goal:** Handle question-only batch mode when requested, then resolve and confirm the ordered story set for the epic being implemented.

---

## EXECUTION SEQUENCE

### 1. Batch Mode (Single-File Questions)

```yaml
if initiative.question_mode == "batch":
  invoke: lens-work.batch-process
  params:
    phase_name: "dev"
    template_path: "templates/phase-4-implementation-questions.template.md"
    output_filename: "dev-implementation-questions.md"
  exit: 0
```

### 2. Epic Story Discovery

```yaml
epic_number = params.epic_number
special_instructions = params.special_instructions || ""
session.special_instructions = special_instructions

story_files = []

if bmad_docs != null:
  story_files += glob("${bmad_docs}/dev-story-${epic_number}-*.md")
  story_files += glob("${bmad_docs}/*epic-${epic_number}*.md")

story_files += glob("_bmad-output/implementation-artifacts/dev-story-${epic_number}-*.md")
story_files += glob("_bmad-output/implementation-artifacts/*epic-${epic_number}*.md")

story_files = deduplicate_by_story_id(story_files)
story_files = sort_by_story_order(story_files)

if story_files.length == 0:
  error: |
    ❌ No story files found for epic ${epic_number}.
    Searched:
    ├── ${bmad_docs}/dev-story-${epic_number}-*.md
    ├── ${bmad_docs}/*epic-${epic_number}*.md
    ├── _bmad-output/implementation-artifacts/dev-story-${epic_number}-*.md
    └── _bmad-output/implementation-artifacts/*epic-${epic_number}*.md
    Run /sprintplan to create dev stories first.
  exit: 1

output: |
  🚀 /dev - Epic ${epic_number} Implementation

  📋 Stories discovered: ${story_files.length}
  ${for idx, file in enumerate(story_files)}
  ${idx + 1}. ${extract_story_title(file)} - ${file}
  ${endfor}

  ${if special_instructions}
  📝 Special Instructions (applied to ALL stories):
  ${special_instructions}
  ${endif}

ask: "Proceed with implementing all ${story_files.length} stories? [Y]es / [N]o"
if no:
  exit: 0

session.epic_number = epic_number
session.story_files = story_files
session.stories_completed = []
session.stories_failed = []
```

---

## NEXT STEP DIRECTIVE

**NEXT:** Read fully and follow: `{project-root}/_bmad/lens-work/workflows/router/dev/steps/step-03-story-loop.md`