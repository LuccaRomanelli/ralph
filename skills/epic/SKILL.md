---
name: epic
description: "Create an Epic that decomposes a large feature into multiple parallelizable PRDs. Use when a feature is too large for a single PRD or has natural parallel workstreams. Triggers on: create an epic, plan epic, decompose feature, parallel prds, multi-prd."
---

# Epic Creator

Decompose large features into multiple PRDs that can be worked on in parallel by separate Ralph instances.

---

## The Job

1. Ask for the **epic name** (kebab-case, e.g., `user-management`)
2. Get a high-level description of the feature
3. Ask questions to identify natural sub-features
4. Ask about dependencies between sub-features
5. Generate multiple `prd.md` files in separate folders
6. Create `epic.json` to track the epic structure

**Important:** This creates PRD skeletons. Use `/ralph` on each PRD to convert to `prd.json`.

---

## Step 0: Get Epic Name

Ask for the epic folder name:

```
What should I name this epic? (use kebab-case, e.g., "user-management", "checkout-flow")
```

The epic name should be:
- Lowercase kebab-case
- Short but descriptive (2-4 words)
- Represent the overall feature being built

---

## Step 1: Understand the Feature

Ask for a high-level description:

```
Describe the overall feature you want to build. Include:
- What problem does it solve?
- Who are the users?
- What are the main capabilities?
```

---

## Step 2: Identify Sub-features

Based on the description, ask questions to decompose into PRDs:

```
I've identified these potential sub-features:

1. [Sub-feature A]
   - Scope: [brief description]
   - Complexity: Low/Medium/High

2. [Sub-feature B]
   - Scope: [brief description]
   - Complexity: Low/Medium/High

3. [Sub-feature C]
   - Scope: [brief description]
   - Complexity: Low/Medium/High

Questions:
A. Should these be separate PRDs, or should any be combined?
B. Are there other sub-features I should add?
C. Are there any that should be removed from scope?
```

---

## Step 3: Define Dependencies

For each sub-feature, determine dependencies:

```
Let's establish dependencies between PRDs:

For each PRD, I need to know what must be completed BEFORE it can start.

1. user-auth
   Dependencies: [none - can start immediately]

2. user-profiles
   Dependencies: [none - can start immediately]

3. admin-dashboard
   Dependencies: [user-auth, user-profiles - needs both complete first]

Questions:
A. Are these dependencies correct?
B. Can any PRDs run in parallel that I marked as dependent?
C. Should any parallel PRDs actually be sequential?
```

### Dependency Rules

- PRDs with no dependencies can run in parallel
- PRDs with dependencies wait for ALL dependencies to complete
- Circular dependencies are NOT allowed (A depends on B, B depends on A)
- Keep the dependency graph as shallow as possible for maximum parallelism

---

## Step 4: Generate PRD Structure

For each sub-feature, create a PRD skeleton:

### PRD Template for Each Sub-feature

```markdown
# PRD: [Sub-feature Name]

**Epic:** [epic-name]

## Introduction

[Brief description of this sub-feature within the larger epic context]

## Goals

- [Goal 1]
- [Goal 2]
- [Goal 3]

## User Stories

### US-001: [First story]
**Description:** As a [user], I want [feature] so that [benefit].

**Acceptance Criteria:**
- [ ] [Criterion 1]
- [ ] [Criterion 2]
- [ ] Typecheck passes

[Additional stories...]

## Functional Requirements

- FR-1: [Requirement]
- FR-2: [Requirement]

## Non-Goals

- [What this PRD will NOT include]

## Dependencies

- **Depends on:** [list of PRD names this depends on, or "None"]
- **Blocks:** [list of PRD names that depend on this]

## Open Questions

- [Any remaining questions]
```

---

## Output Structure

Create the following structure:

```
prds/
├── [epic-name]/
│   └── epic.json           # Epic metadata and dependency graph
├── [prd-1-name]/
│   ├── prd.md              # PRD document
│   └── status              # "unstarted"
├── [prd-2-name]/
│   ├── prd.md
│   └── status
└── [prd-3-name]/
    ├── prd.md
    └── status
```

### epic.json Format

```json
{
  "epicName": "[epic-name]",
  "description": "[High-level epic description]",
  "createdAt": "[ISO timestamp]",
  "prds": [
    { "name": "[prd-1-name]", "dependsOn": [] },
    { "name": "[prd-2-name]", "dependsOn": [] },
    { "name": "[prd-3-name]", "dependsOn": ["prd-1-name", "prd-2-name"] }
  ]
}
```

---

## Parallelization Guidelines

### Ideal for Parallel Execution

- **Separate domains:** user-auth vs payment-processing
- **Layer separation:** database schema vs UI components (if schema-first)
- **Independent features:** notifications vs search

### Should Be Sequential

- **Shared schema:** Both PRDs modify the same database tables
- **API dependencies:** One PRD creates API that another consumes
- **UI integration:** Dashboard that displays data from other PRDs

### Red Flags (Reconsider Split)

- More than 3 levels of dependencies
- PRD with 5+ dependencies (too coupled)
- Circular dependency detected
- Single-story PRDs (too granular)

---

## Checklist Before Saving

- [ ] Asked for epic name (kebab-case)
- [ ] Got high-level feature description
- [ ] Identified 2-5 sub-features (PRDs)
- [ ] Verified no circular dependencies
- [ ] Each PRD has clear boundaries
- [ ] Dependencies are minimal (maximize parallelism)
- [ ] Created `prds/[epic-name]/epic.json`
- [ ] Created `prds/[prd-name]/prd.md` for each PRD
- [ ] Created `prds/[prd-name]/status` with "unstarted" for each

---

## Commands to Run

After gathering information, create the structure:

```bash
# Create epic folder and file
mkdir -p prds/[epic-name]
# Write epic.json to prds/[epic-name]/epic.json

# Create each PRD folder
mkdir -p prds/[prd-1-name]
# Write prd.md to prds/[prd-1-name]/prd.md
echo "unstarted" > prds/[prd-1-name]/status

mkdir -p prds/[prd-2-name]
# Write prd.md to prds/[prd-2-name]/prd.md
echo "unstarted" > prds/[prd-2-name]/status

# Repeat for each PRD...
```

---

## Next Steps

After creating the epic structure, tell the user:

```
Epic created: [epic-name]
PRDs created: [count]

Dependency graph:
  [prd-1] ──┐
            ├──> [prd-3]
  [prd-2] ──┘

Next steps:
1. Review each PRD in prds/[prd-name]/prd.md
2. Run /ralph on each PRD to convert to prd.json
3. Run ./ralph-parallel.sh to execute PRDs in parallel
   Or: ./ralph-parallel.sh --epic [epic-name]

PRDs that can start immediately (no dependencies):
  - [prd-1]
  - [prd-2]
```

---

## Example

### Input

User: "I need to build a complete e-commerce checkout system"

### Questions

```
1. What payment providers do you need to support?
   A. Stripe only
   B. Stripe + PayPal
   C. Multiple providers with abstraction layer
   D. Other

2. Does this include inventory management?
   A. Yes, full inventory tracking
   B. Yes, basic stock counts only
   C. No, inventory is managed elsewhere
   D. Not sure yet

3. What about order history and tracking?
   A. Full order history with status tracking
   B. Basic order confirmation only
   C. Out of scope for now
```

### Generated Structure

**Epic:** `checkout-system`

**PRDs:**
1. `payment-integration` - Payment provider integration (no deps)
2. `cart-management` - Shopping cart functionality (no deps)
3. `checkout-flow` - Checkout UI and process (depends on: payment-integration, cart-management)
4. `order-history` - Order tracking and history (depends on: checkout-flow)

**Dependency Graph:**
```
payment-integration ──┐
                      ├──> checkout-flow ──> order-history
cart-management ─────┘
```

**Parallelism:**
- Level 1: payment-integration + cart-management (parallel)
- Level 2: checkout-flow (after level 1)
- Level 3: order-history (after level 2)
