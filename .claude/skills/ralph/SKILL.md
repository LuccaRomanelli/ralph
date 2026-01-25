---
name: ralph
description: "Convert PRDs to prd.json format for the Ralph autonomous agent system. Use when you have an existing PRD and need to convert it to Ralph's JSON format. Triggers on: convert this prd, turn this into ralph format, create prd.json from this, ralph json."
---

# Ralph PRD Converter

Converts existing PRDs to the prd.json format that Ralph uses for autonomous execution.

---

## The Job

1. List available PRDs in `prds/` directory
2. Ask user which PRD to convert (if multiple exist)
3. Read the `prd.md` file from the selected PRD folder
4. Convert it to `prd.json` in the same folder
5. Update status to `unstarted` if not already set

---

## Step 1: Find PRD to Convert

Check for PRDs in the `prds/` directory:

```bash
ls -la prds/
```

If multiple PRD folders exist, show them and ask which to convert:

```
Available PRDs:
  1. task-priority/  [unstarted]
  2. user-auth/      [in_progress]
  3. dashboard/      [unstarted]

Which PRD should I convert? (enter number or folder name)
```

If only one PRD exists without a prd.json, use it automatically.

---

## Step 2: Read and Validate prd.md

Read the PRD markdown file:
- Location: `prds/<folder-name>/prd.md`

Verify it contains:
- User stories with IDs (US-XXX format)
- Acceptance criteria for each story
- Clear feature description

If prd.md is missing, inform the user:
```
No prd.md found in prds/<folder-name>/
Use /prd to create a PRD first.
```

---

## Output Format

```json
{
  "project": "[Project Name]",
  "branchName": "ralph/[folder-name]",
  "description": "[Feature description from PRD title/intro]",
  "epicName": "[epic-name or null if not part of epic]",
  "dependsOn": ["[prd-names this depends on]"],
  "userStories": [
    {
      "id": "US-001",
      "title": "[Story title]",
      "description": "As a [user], I want [feature] so that [benefit]",
      "acceptanceCriteria": [
        "Criterion 1",
        "Criterion 2",
        "Typecheck passes"
      ],
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ]
}
```

---

## Story Size: The Number One Rule

**Each story must be completable in ONE Ralph iteration (one context window).**

Ralph spawns a fresh Claude Code instance per iteration with no memory of previous work. If a story is too big, the LLM runs out of context before finishing and produces broken code.

### Right-sized stories:
- Add a database column and migration
- Add a UI component to an existing page
- Update a server action with new logic
- Add a filter dropdown to a list

### Too big (split these):
- "Build the entire dashboard" - Split into: schema, queries, UI components, filters
- "Add authentication" - Split into: schema, middleware, login UI, session handling
- "Refactor the API" - Split into one story per endpoint or pattern

**Rule of thumb:** If you cannot describe the change in 2-3 sentences, it is too big.

---

## Story Ordering: Dependencies First

Stories execute in priority order. Earlier stories must not depend on later ones.

**Correct order:**
1. Schema/database changes (migrations)
2. Server actions / backend logic
3. UI components that use the backend
4. Dashboard/summary views that aggregate data

**Wrong order:**
1. UI component (depends on schema that does not exist yet)
2. Schema change

---

## Acceptance Criteria: Must Be Verifiable

Each criterion must be something Ralph can CHECK, not something vague.

### Good criteria (verifiable):
- "Add `status` column to tasks table with default 'pending'"
- "Filter dropdown has options: All, Active, Completed"
- "Clicking delete shows confirmation dialog"
- "Typecheck passes"
- "Tests pass"

### Bad criteria (vague):
- "Works correctly"
- "User can do X easily"
- "Good UX"
- "Handles edge cases"

### Always include as final criterion:
```
"Typecheck passes"
```

For stories with testable logic, also include:
```
"Tests pass"
```

### For stories that change UI, also include:
```
"Verify changes work in browser"
```

Frontend stories are NOT complete until visually verified.

---

## Conversion Rules

1. **Each user story becomes one JSON entry**
2. **IDs**: Sequential (US-001, US-002, etc.) - preserve from prd.md
3. **Priority**: Based on dependency order, then document order
4. **All stories**: `passes: false` and empty `notes`
5. **branchName**: Use `ralph/<folder-name>` where folder-name is the PRD folder
6. **Always add**: "Typecheck passes" to every story's acceptance criteria (if not present)
7. **epicName**: If PRD is part of an epic (check for epic.json in parent or sibling folders), set to epic name. Otherwise `null`.
8. **dependsOn**: Array of PRD folder names that must complete before this one can start. Check the prd.md for "Dependencies" section or epic.json for dependency graph. Empty array `[]` if no dependencies.

---

## Epic Detection

When converting a PRD, check if it belongs to an epic:

1. **Check prd.md**: Look for "Epic:" line near the top or "Dependencies" section
2. **Check for epic.json**: Search `prds/*/epic.json` for references to this PRD folder name
3. **Extract dependencies**: From epic.json's `prds[].dependsOn` array

### Example epic.json lookup:

```bash
# Find epic.json files
ls prds/*/epic.json

# Check if this PRD is in an epic
cat prds/*/epic.json | jq -r '.prds[] | select(.name == "user-auth")'
```

If PRD is part of an epic:
```json
{
  "epicName": "user-management",
  "dependsOn": []
}
```

If PRD is standalone:
```json
{
  "epicName": null,
  "dependsOn": []
}
```

---

## Splitting Large PRDs

If a PRD has big features, split them:

**Original:**
> "Add user notification system"

**Split into:**
1. US-001: Add notifications table to database
2. US-002: Create notification service for sending notifications
3. US-003: Add notification bell icon to header
4. US-004: Create notification dropdown panel
5. US-005: Add mark-as-read functionality
6. US-006: Add notification preferences page

Each is one focused change that can be completed and verified independently.

---

## Example

**Input PRD (prds/task-status/prd.md):**
```markdown
# Task Status Feature

Add ability to mark tasks with different statuses.

## Requirements
- Toggle between pending/in-progress/done on task list
- Filter list by status
- Show status badge on each task
- Persist status in database
```

**Output (prds/task-status/prd.json):**
```json
{
  "project": "TaskApp",
  "branchName": "ralph/task-status",
  "description": "Task Status Feature - Track task progress with status indicators",
  "epicName": null,
  "dependsOn": [],
  "userStories": [
    {
      "id": "US-001",
      "title": "Add status field to tasks table",
      "description": "As a developer, I need to store task status in the database.",
      "acceptanceCriteria": [
        "Add status column: 'pending' | 'in_progress' | 'done' (default 'pending')",
        "Generate and run migration successfully",
        "Typecheck passes"
      ],
      "priority": 1,
      "passes": false,
      "notes": ""
    },
    {
      "id": "US-002",
      "title": "Display status badge on task cards",
      "description": "As a user, I want to see task status at a glance.",
      "acceptanceCriteria": [
        "Each task card shows colored status badge",
        "Badge colors: gray=pending, blue=in_progress, green=done",
        "Typecheck passes",
        "Verify changes work in browser"
      ],
      "priority": 2,
      "passes": false,
      "notes": ""
    },
    {
      "id": "US-003",
      "title": "Add status toggle to task list rows",
      "description": "As a user, I want to change task status directly from the list.",
      "acceptanceCriteria": [
        "Each row has status dropdown or toggle",
        "Changing status saves immediately",
        "UI updates without page refresh",
        "Typecheck passes",
        "Verify changes work in browser"
      ],
      "priority": 3,
      "passes": false,
      "notes": ""
    },
    {
      "id": "US-004",
      "title": "Filter tasks by status",
      "description": "As a user, I want to filter the list to see only certain statuses.",
      "acceptanceCriteria": [
        "Filter dropdown: All | Pending | In Progress | Done",
        "Filter persists in URL params",
        "Typecheck passes",
        "Verify changes work in browser"
      ],
      "priority": 4,
      "passes": false,
      "notes": ""
    }
  ]
}
```

---

## Output Location

Write the prd.json to the same folder as the prd.md:

```
prds/<folder-name>/
├── prd.md              # Source (human-readable)
├── prd.json            # Generated (machine-readable)
└── status              # Update if needed
```

---

## Checklist Before Saving

Before writing prd.json, verify:

- [ ] Read prd.md from `prds/<folder-name>/`
- [ ] Each story is completable in one iteration (small enough)
- [ ] Stories are ordered by dependency (schema to backend to UI)
- [ ] Every story has "Typecheck passes" as criterion
- [ ] UI stories have "Verify changes work in browser" as criterion
- [ ] Acceptance criteria are verifiable (not vague)
- [ ] No story depends on a later story
- [ ] branchName uses format `ralph/<folder-name>`
- [ ] Saved to `prds/<folder-name>/prd.json`

---

## Next Steps

After creating the prd.json, tell the user:

```
prd.json created at: prds/<folder-name>/prd.json
Branch: ralph/<folder-name>
Stories: X total

Next steps:
1. Review the stories and acceptance criteria
2. Run ./ralph.sh to start the autonomous agent loop
   Or: ./ralph.sh 10 <folder-name>
```
