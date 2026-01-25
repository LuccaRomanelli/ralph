# Ralph

![Ralph](ralph.webp)

Ralph is an autonomous AI agent loop that runs [Claude Code](https://claude.ai/code) repeatedly until all PRD items are complete. Each iteration is a fresh Claude Code instance with clean context. Memory persists via git history, `progress.txt`, and `prd.json`.

Based on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/).

[Read my in-depth article on how I use Ralph](https://x.com/ryancarson/status/2008548371712135632)

## Features

- **Multi-PRD Support**: Manage multiple PRDs in separate folders
- **Epic Support**: Group related PRDs with dependency management
- **Parallel Execution**: Run multiple PRDs simultaneously via tmux
- **Git Worktrees**: Isolate feature work from main branch automatically
- **Automatic PR Creation**: Creates draft PR when all stories complete
- **Regression Testing**: Run tests after each iteration to catch breakages
- **Interactive Selection**: Choose which PRD to work on when multiple exist

## Prerequisites

- [Claude Code CLI](https://claude.ai/code) installed and authenticated
- `jq` installed (`brew install jq` on macOS)
- `gh` CLI installed for PR creation (`brew install gh` on macOS)
- `tmux` installed for parallel execution (`brew install tmux` on macOS)
- A git repository for your project

## Setup

### Option 1: Import to your project (Recommended)

From the Ralph repository, use the import skill:

```bash
cd /path/to/ralph
# In Claude Code:
/import-to /path/to/your/project
```

This creates:
- `.ralph/` - Core Ralph files
- `.claude/skills/prd/` - PRD creation skill
- `.claude/skills/ralph/` - PRD conversion skill
- `prds/` - Directory for your PRDs
- `ralph` - Wrapper script in project root

### Option 2: Manual copy

```bash
# From your project root
mkdir -p .ralph
cp /path/to/ralph/ralph.sh .ralph/
cp /path/to/ralph/prompt.md .ralph/
cp /path/to/ralph/fix-prompt.template.md .ralph/
chmod +x .ralph/ralph.sh

# Create wrapper script
echo '#!/bin/bash
exec "$(dirname "$0")/.ralph/ralph.sh" "$@"' > ralph
chmod +x ralph
```

## Workflow

### 1. Create a PRD

Use the `/prd` skill to generate a detailed requirements document:

```
/prd
```

The skill will:
1. Ask for a folder name (kebab-case, e.g., `user-auth`)
2. Ask clarifying questions about your feature
3. Generate `prds/<folder-name>/prd.md`
4. Create a status file set to `unstarted`

### 2. Convert PRD to Ralph format

Use the `/ralph` skill to convert the markdown PRD to JSON:

```
/ralph
```

This reads `prds/<folder-name>/prd.md` and creates `prds/<folder-name>/prd.json` with user stories structured for autonomous execution.

### 3. Run Ralph

```bash
# Interactive PRD selection (if multiple PRDs exist)
./ralph

# Run specific PRD with max iterations
./ralph 10 user-auth

# List all PRDs and their status
./ralph --list

# Show current PRD status
./ralph --status
```

Default is 10 iterations.

### 4. Parallel Execution (Optional)

For large features, use epics to run multiple PRDs in parallel:

```bash
# Create an epic with multiple PRDs
/epic

# Run all eligible PRDs in parallel
./ralph-parallel.sh

# Limit concurrent PRDs
./ralph-parallel.sh --max 3

# Run only PRDs from specific epic
./ralph-parallel.sh --epic user-management

# Monitor running PRDs
./ralph-parallel.sh --attach

# Stop all running PRDs
./ralph-parallel.sh --stop
```

Ralph will:
1. Create a git worktree for the feature branch (main stays untouched)
2. Pick the highest priority story where `passes: false`
3. Implement that single story
4. Run quality checks (typecheck, tests)
5. Commit if checks pass
6. Run regression tests
7. Update `prd.json` to mark story as `passes: true`
8. Append learnings to `progress.txt`
9. Repeat until all stories pass or max iterations reached
10. Create a draft PR and cleanup worktree on completion

## Project Structure

```
your-project/
├── prds/                         # PRD folders
│   ├── user-management/          # Epic folder (optional)
│   │   └── epic.json             # Epic metadata and dependencies
│   ├── user-auth/
│   │   ├── prd.md                # Human-readable PRD
│   │   ├── prd.json              # Machine-readable PRD (includes epicName, dependsOn)
│   │   ├── progress.txt          # Progress log
│   │   ├── regression-tests.json # Regression tests
│   │   └── status                # unstarted | in_progress | complete | error
│   └── dashboard/
│       └── ...
├── .worktrees/                   # Git worktrees (auto-managed)
├── archive/                      # Archived completed PRDs
├── .ralph/                       # Ralph core files
│   ├── ralph.sh
│   ├── ralph-parallel.sh
│   ├── prompt.md
│   └── ...
└── ralph                         # Wrapper script
```

## Key Files

| File | Purpose |
|------|---------|
| `ralph.sh` | The bash loop that spawns fresh Claude Code instances |
| `ralph-parallel.sh` | Parallel execution via tmux for multiple PRDs |
| `prompt.md` | Instructions given to each Claude Code instance |
| `prds/<name>/prd.md` | Human-readable PRD |
| `prds/<name>/prd.json` | User stories with `passes` status (the task list) |
| `prds/<name>/progress.txt` | Append-only learnings for future iterations |
| `prds/<name>/status` | PRD status: unstarted, in_progress, complete, error |
| `prds/<epic>/epic.json` | Epic metadata with dependency graph |
| `skills/prd/` | Skill for generating PRDs |
| `skills/ralph/` | Skill for converting PRDs to JSON |
| `skills/epic/` | Skill for creating epics (multiple parallel PRDs) |
| `flowchart/` | Interactive visualization of how Ralph works |

## Status Values

| Status | Meaning |
|--------|---------|
| `unstarted` | PRD exists but work hasn't begun |
| `in_progress` | Ralph is actively working on this PRD |
| `complete` | All stories pass, PR created |
| `error` | Ralph encountered an irrecoverable error |

## Flowchart

[![Ralph Flowchart](ralph-flowchart.png)](https://snarktank.github.io/ralph/)

**[View Interactive Flowchart](https://snarktank.github.io/ralph/)** - Click through to see each step with animations.

The `flowchart/` directory contains the source code. To run locally:

```bash
cd flowchart
npm install
npm run dev
```

## Critical Concepts

### Each Iteration = Fresh Context

Each iteration spawns a **new Claude Code instance** with clean context. The only memory between iterations is:
- Git history (commits from previous iterations)
- `progress.txt` (learnings and context)
- `prd.json` (which stories are done)

### Git Worktrees

Ralph uses git worktrees to isolate feature work:
- Main branch stays untouched during development
- Each PRD gets its own worktree in `.worktrees/`
- On completion, changes are pushed and a draft PR is created
- Worktree is cleaned up after PR creation

### Epics and Parallel Execution

For large features, use epics to manage multiple PRDs:

```json
{
  "epicName": "user-management",
  "description": "Complete user management system",
  "prds": [
    { "name": "user-auth", "dependsOn": [] },
    { "name": "user-profiles", "dependsOn": [] },
    { "name": "admin-dashboard", "dependsOn": ["user-auth", "user-profiles"] }
  ]
}
```

**Key concepts:**
- PRDs with no dependencies run in parallel
- PRDs with dependencies wait for all dependencies to complete
- Circular dependencies are automatically detected and rejected
- Use `ralph-parallel.sh` to orchestrate parallel execution via tmux

**Dependency graph visualization:**
```
user-auth ──────┐
                ├──> admin-dashboard
user-profiles ──┘
```

### Small Tasks

Each PRD item should be small enough to complete in one context window. If a task is too big, the LLM runs out of context before finishing and produces poor code.

Right-sized stories:
- Add a database column and migration
- Add a UI component to an existing page
- Update a server action with new logic
- Add a filter dropdown to a list

Too big (split these):
- "Build the entire dashboard"
- "Add authentication"
- "Refactor the API"

### CLAUDE.md Updates Are Critical

After each iteration, Ralph updates the relevant `CLAUDE.md` files with learnings. This is key because Claude Code automatically reads these files, so future iterations (and future human developers) benefit from discovered patterns, gotchas, and conventions.

Examples of what to add to CLAUDE.md:
- Patterns discovered ("this codebase uses X for Y")
- Gotchas ("do not forget to update Z when changing W")
- Useful context ("the settings panel is in component X")

### Regression Testing

Ralph supports regression tests that run after each iteration:

```json
{
  "tests": [
    {
      "id": "RT-001",
      "storyId": "US-001",
      "description": "Verify login works",
      "command": "npm test -- --grep 'login'",
      "lastResult": "pass"
    }
  ]
}
```

Configure behavior in `regression-tests.json`:
- `runStrategy`: "all", "newest", "random", "failing"
- `failureAction`: "warn", "stop", "fix", "continue"

### Feedback Loops

Ralph only works if there are feedback loops:
- Typecheck catches type errors
- Tests verify behavior
- Regression tests catch breakages
- CI must stay green (broken code compounds across iterations)

### Browser Verification for UI Stories

Frontend stories must include browser verification in acceptance criteria. Verify changes work by testing manually or taking screenshots.

### Stop Condition

When all stories have `passes: true`, Ralph outputs `<promise>COMPLETE</promise>`, creates a draft PR, and the loop exits.

## Commands Reference

```bash
# Single PRD execution
./ralph                    # Interactive PRD selection
./ralph 10                 # Run with 10 max iterations
./ralph 10 user-auth       # Run specific PRD
./ralph --list             # List all PRDs
./ralph --status           # Show current PRD status
./ralph --help             # Show help

# Parallel execution (requires tmux)
./ralph-parallel.sh                    # Run all eligible PRDs
./ralph-parallel.sh --max 3            # Limit to 3 concurrent
./ralph-parallel.sh --epic myepic      # Only PRDs from epic
./ralph-parallel.sh --status           # Show all PRD status
./ralph-parallel.sh --attach           # Attach to tmux session
./ralph-parallel.sh --stop             # Stop all PRDs
```

## Debugging

Check current state:

```bash
# See which stories are done
cat prds/my-feature/prd.json | jq '.userStories[] | {id, title, passes}'

# See learnings from previous iterations
cat prds/my-feature/progress.txt

# Check git history
git log --oneline -10

# List active worktrees
git worktree list

# Check PRD status
cat prds/my-feature/status
```

## Customizing prompt.md

Edit `prompt.md` (or `.ralph/prompt.md`) to customize Ralph's behavior for your project:
- Add project-specific quality check commands
- Include codebase conventions
- Add common gotchas for your stack

## Archiving

Ralph automatically archives completed PRDs to `archive/YYYY-MM-DD-feature-name/` when a PR is created. This includes:
- `prd.json`
- `prd.md`
- `progress.txt`
- `regression-tests.json`

## Migration from Legacy Format

If you have an existing `prd.json` in your project root, Ralph will automatically migrate it to the new `prds/` structure on first run.

## References

- [Geoffrey Huntley's Ralph article](https://ghuntley.com/ralph/)
- [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code)
