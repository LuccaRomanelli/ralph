---
name: prd
description: "Generate a Product Requirements Document (PRD) for a new feature. Use when planning a feature, starting a new project, or when asked to create a PRD. Triggers on: create a prd, write prd for, plan this feature, requirements for, spec out."
user-invocable: true
---

# PRD Generator

Create detailed Product Requirements Documents that are clear, actionable, and suitable for implementation.

---

## The Job

1. Analyze the existing codebase (NEW)
2. Receive a feature description from the user
3. Ask clarifying questions using AskUserQuestion tool in batches
4. Generate a structured PRD with Codebase Analysis section
5. Save to `tasks/prd-[feature-name].md`

**Important:** Do NOT start implementing. Just create the PRD.

---

## Step 0: Codebase Analysis (BEFORE asking questions)

Before asking clarifying questions, analyze the existing codebase to inform your PRD:

### 1. Map Project Structure
- Identify main directories and their purposes
- Note the tech stack (framework, styling, database)
- Find where similar features live

### 2. Find Reusable Components
Search for existing code that could be reused:
- UI components (buttons, modals, forms)
- Hooks and utilities
- API patterns and validation schemas

### 3. Identify Patterns
Document conventions:
- Naming conventions
- State management
- Styling approach
- Error handling

### 4. Check for Similar Features
- Could this extend an existing feature?
- Is there code that does something similar?

**Use these findings** to ask better questions and write a more informed PRD.

---

## Step 1: Clarifying Questions (Informed by Analysis)

Start by sharing what you found in the codebase, then ask questions:

```
I analyzed your codebase and found:
- You have Badge, Button, Dialog components in components/ui/
- Tasks are in src/app/tasks/ with server actions
- You use Tailwind + cn() for styling

With this context, I'll ask a few clarifying questions...
```

Then use AskUserQuestion tool with questions informed by your analysis.

Ask only critical questions where the initial prompt is ambiguous. Focus on:

- **Problem/Goal:** What problem does this solve?
- **Core Functionality:** What are the key actions?
- **Scope/Boundaries:** What should it NOT do?
- **Success Criteria:** How do we know it's done?

### Use AskUserQuestion Tool

Use the AskUserQuestion tool to ask clarifying questions in batches of 2-4 questions. Continue asking until all critical areas are covered.

**Batch 1: Problem & Goal**
```json
{
  "questions": [
    {
      "question": "What is the primary goal of this feature?",
      "header": "Goal",
      "options": [
        {"label": "Improve onboarding", "description": "Enhance new user experience"},
        {"label": "Increase retention", "description": "Keep existing users engaged"},
        {"label": "Reduce support", "description": "Decrease support ticket volume"}
      ],
      "multiSelect": false
    },
    {
      "question": "Who is the target user for this feature?",
      "header": "Target User",
      "options": [
        {"label": "New users only", "description": "First-time users of the product"},
        {"label": "Existing users", "description": "Users already familiar with the product"},
        {"label": "All users", "description": "Both new and existing users"},
        {"label": "Admin users", "description": "Users with admin privileges"}
      ],
      "multiSelect": false
    }
  ]
}
```

**Batch 2: Scope & Success** (after receiving Batch 1 answers)
```json
{
  "questions": [
    {
      "question": "What is the scope for this feature?",
      "header": "Scope",
      "options": [
        {"label": "MVP only", "description": "Minimal viable version"},
        {"label": "Full feature", "description": "Complete implementation"},
        {"label": "Backend only", "description": "Just the API/backend"},
        {"label": "UI only", "description": "Just the frontend/UI"}
      ],
      "multiSelect": false
    },
    {
      "question": "How will success be measured?",
      "header": "Success",
      "options": [
        {"label": "User metrics", "description": "Engagement, retention, satisfaction"},
        {"label": "Business metrics", "description": "Revenue, conversion, support reduction"},
        {"label": "Technical metrics", "description": "Performance, reliability, coverage"}
      ],
      "multiSelect": true
    }
  ]
}
```

**Guidelines:**
- Ask 2-4 questions per batch
- Wait for user answers before asking the next batch
- Continue until these areas are clarified:
  - Problem/Goal
  - Target Users
  - Core Functionality
  - Scope/Boundaries
  - Success Criteria
- If user selects "Other" or provides custom input, follow up with clarifying questions

---

## Step 2: PRD Structure

Generate the PRD with these sections:

### 0. Codebase Analysis (First Section)

Include analysis results at the TOP of the PRD:

```markdown
## Codebase Analysis

### Project Structure
| Directory | Purpose |
|-----------|---------|
| src/app/ | Next.js app router pages |
| src/components/ | Reusable UI components |
| src/lib/ | Utilities and helpers |
| src/db/ | Database schema and queries |

### Tech Stack
- Framework: Next.js 14 (app router)
- Styling: Tailwind CSS + cn() utility
- Database: Drizzle ORM + SQLite
- UI: Shadcn/ui components

### Reusable Components
| Component | Location | Reuse For |
|-----------|----------|-----------|
| Badge | components/ui/badge | Priority indicator |
| Dialog | components/ui/dialog | Edit modal |
| useOptimistic | hooks/ | Instant updates |

### Relevant Existing Code
- `src/app/tasks/actions.ts` - Task mutations (extend for priority)
- `src/components/TaskCard.tsx` - Add priority display here
- `src/db/schema.ts` - Add priority field

### Patterns to Follow
- Server actions for mutations
- Zod schemas for validation
- cn() for conditional Tailwind classes
```

### 1. Introduction/Overview
Brief description of the feature and the problem it solves.

### 2. Goals
Specific, measurable objectives (bullet list).

### 3. User Stories
Each story needs:
- **Title:** Short descriptive name
- **Description:** "As a [user], I want [feature] so that [benefit]"
- **Acceptance Criteria:** Verifiable checklist of what "done" means

For each user story, specify `testType` (unit|integration|e2e|none) and `testRepo`.
See CLAUDE.md for test commands and .claude/docs/e2e-testing.md for patterns.

Each story should be small enough to implement in one focused session.

**Format:**
```markdown
### US-001: [Title]
**Description:** As a [user], I want [feature] so that [benefit].

**Acceptance Criteria:**
- [ ] Specific verifiable criterion
- [ ] Another criterion
- [ ] Typecheck/lint passes
- [ ] **[UI stories only]** Verify in browser using dev-browser skill
```

**Important:** 
- Acceptance criteria must be verifiable, not vague. "Works correctly" is bad. "Button shows confirmation dialog before deleting" is good.
- **For any story with UI changes:** Always include "Verify in browser using dev-browser skill" as acceptance criteria. This ensures visual verification of frontend work.

### 4. Functional Requirements
Numbered list of specific functionalities:
- "FR-1: The system must allow users to..."
- "FR-2: When a user clicks X, the system must..."

Be explicit and unambiguous.

### 5. Non-Goals (Out of Scope)
What this feature will NOT include. Critical for managing scope.

### 6. Design Considerations (Optional)
- UI/UX requirements
- Link to mockups if available
- Relevant existing components to reuse

### 7. Technical Considerations (Required)

Reference the Codebase Analysis section:

```markdown
## Technical Considerations

**From Codebase Analysis:**

- **Reuse:** Badge component for priority indicator, useOptimistic for instant UI
- **Extend:** TaskCard.tsx, actions.ts, schema.ts
- **Pattern:** Follow existing Dialog usage for edit modal
- **New:** Only priority-badge.tsx if Badge doesn't fit
```

Additional considerations:
- Known constraints or dependencies
- Integration points with existing systems
- Performance requirements

### 8. Success Metrics
How will success be measured?
- "Reduce time to complete X by 50%"
- "Increase conversion rate by 10%"

### 9. Open Questions
Remaining questions or areas needing clarification.

---

## Writing for Junior Developers

The PRD reader may be a junior developer or AI agent. Therefore:

- Be explicit and unambiguous
- Avoid jargon or explain it
- Provide enough detail to understand purpose and core logic
- Number requirements for easy reference
- Use concrete examples where helpful

---

## Output

- **Format:** Markdown (`.md`)
- **Location:** `tasks/`
- **Filename:** `prd-[feature-name].md` (kebab-case)

---

## Example PRD

```markdown
# PRD: Task Priority System

## Codebase Analysis

### Project Structure
| Directory | Purpose |
|-----------|---------|
| src/app/ | Next.js pages |
| src/components/ | UI components |
| src/lib/ | Utilities |
| src/db/ | Database |

### Tech Stack
- Next.js 14, Tailwind, Drizzle, Shadcn/ui

### Reusable Components
| Component | Location | Reuse For |
|-----------|----------|-----------|
| Badge | components/ui/badge | Priority indicator |
| Dialog | components/ui/dialog | Edit modal |

### Relevant Existing Code
- src/app/tasks/actions.ts - extend for priority
- src/components/TaskCard.tsx - add priority prop

### Patterns to Follow
- Server actions for data mutations
- cn() for conditional classes

---

## Introduction

Add priority levels to tasks so users can focus on what matters most. Tasks can be marked as high, medium, or low priority, with visual indicators and filtering to help users manage their workload effectively.

## Goals

- Allow assigning priority (high/medium/low) to any task
- Provide clear visual differentiation between priority levels
- Enable filtering and sorting by priority
- Default new tasks to medium priority

## User Stories

### US-001: Add priority field to database
**Description:** As a developer, I need to store task priority so it persists across sessions.

**Acceptance Criteria:**
- [ ] Add priority column to tasks table: 'high' | 'medium' | 'low' (default 'medium')
- [ ] Generate and run migration successfully
- [ ] Typecheck passes

### US-002: Display priority indicator on task cards
**Description:** As a user, I want to see task priority at a glance so I know what needs attention first.

**Acceptance Criteria:**
- [ ] Each task card shows colored priority badge (red=high, yellow=medium, gray=low)
- [ ] Priority visible without hovering or clicking
- [ ] Typecheck passes
- [ ] Verify in browser using dev-browser skill

### US-003: Add priority selector to task edit
**Description:** As a user, I want to change a task's priority when editing it.

**Acceptance Criteria:**
- [ ] Priority dropdown in task edit modal
- [ ] Shows current priority as selected
- [ ] Saves immediately on selection change
- [ ] Typecheck passes
- [ ] Verify in browser using dev-browser skill

### US-004: Filter tasks by priority
**Description:** As a user, I want to filter the task list to see only high-priority items when I'm focused.

**Acceptance Criteria:**
- [ ] Filter dropdown with options: All | High | Medium | Low
- [ ] Filter persists in URL params
- [ ] Empty state message when no tasks match filter
- [ ] Typecheck passes
- [ ] Verify in browser using dev-browser skill

## Functional Requirements

- FR-1: Add `priority` field to tasks table ('high' | 'medium' | 'low', default 'medium')
- FR-2: Display colored priority badge on each task card
- FR-3: Include priority selector in task edit modal
- FR-4: Add priority filter dropdown to task list header
- FR-5: Sort by priority within each status column (high to medium to low)

## Non-Goals

- No priority-based notifications or reminders
- No automatic priority assignment based on due date
- No priority inheritance for subtasks

## Technical Considerations

**From Codebase Analysis:**

- **Reuse:** Badge component for priority colors
- **Extend:** schema.ts, actions.ts, TaskCard.tsx
- **Pattern:** Follow existing migration format

Additional:
- Filter state managed via URL search params
- Priority stored in database, not computed

## Success Metrics

- Users can change priority in under 2 clicks
- High-priority tasks immediately visible at top of lists
- No regression in task list performance

## Open Questions

- Should priority affect task ordering within a column?
- Should we add keyboard shortcuts for priority changes?
```

---

## Checklist

Before saving the PRD:

- [ ] Analyzed the codebase first
- [ ] Shared codebase findings with user before questions
- [ ] Asked clarifying questions using AskUserQuestion tool in batches
- [ ] Incorporated user's answers
- [ ] PRD includes Codebase Analysis section at the top
- [ ] User stories are small and specific
- [ ] Functional requirements are numbered and unambiguous
- [ ] Non-goals section defines clear boundaries
- [ ] Technical Considerations references Codebase Analysis
- [ ] Saved to `tasks/prd-[feature-name].md`
