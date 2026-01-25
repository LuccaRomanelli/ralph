# Ralph Agent Instructions

## Overview

Ralph is an autonomous AI agent loop that runs Claude Code repeatedly until all PRD items are complete. Each iteration is a fresh Claude Code instance with clean context.

## Commands

```bash
# Run Ralph with interactive PRD selection
./ralph.sh

# Run Ralph with specific PRD and max iterations
./ralph.sh [max_iterations] [prd_folder]

# List all PRDs and their status
./ralph.sh --list

# Show current PRD status
./ralph.sh --status

# Run multiple PRDs in parallel (requires tmux)
./ralph-parallel.sh

# Parallel with max 3 concurrent PRDs
./ralph-parallel.sh --max 3

# Parallel for specific epic only
./ralph-parallel.sh --epic user-management

# Attach to running parallel session
./ralph-parallel.sh --attach

# Stop all parallel PRDs
./ralph-parallel.sh --stop

# Run the flowchart dev server
cd flowchart && npm run dev

# Build the flowchart
cd flowchart && npm run build
```

## Key Files

- `ralph.sh` - The bash loop that spawns fresh Claude Code instances with worktree support
- `ralph-parallel.sh` - Parallel execution via tmux for multiple PRDs
- `prompt.md` - Instructions given to each Claude Code instance
- `prd.json.example` - Example PRD format
- `epic.json.example` - Example epic format with dependencies
- `regression-tests.json.example` - Example regression test format
- `skills/prd/SKILL.md` - PRD creation skill
- `skills/ralph/SKILL.md` - PRD to JSON conversion skill
- `skills/epic/SKILL.md` - Epic creation skill (multiple parallel PRDs)
- `skills/import-to/SKILL.md` - Import Ralph to other projects

## Project Structure

```
project-root/
├── prds/                    # PRD folders
│   ├── my-epic/             # Epic folder (optional)
│   │   └── epic.json        # Epic metadata and dependency graph
│   ├── feature-a/
│   │   ├── prd.md           # Human-readable PRD
│   │   ├── prd.json         # Machine-readable PRD (includes epicName, dependsOn)
│   │   ├── progress.txt     # Progress log
│   │   ├── regression-tests.json
│   │   └── status           # unstarted | in_progress | complete | error
│   └── feature-b/
│       └── ...
├── .worktrees/              # Git worktrees (auto-managed)
├── archive/                 # Archived completed PRDs
├── ralph.sh                 # Main script (or in .ralph/)
└── ralph-parallel.sh        # Parallel execution script
```

## Workflow

### Single PRD

1. **Create PRD**: Use `/prd` skill to create `prds/<feature>/prd.md`
2. **Convert to JSON**: Use `/ralph` skill to generate `prds/<feature>/prd.json`
3. **Run Ralph**: Execute `./ralph.sh` to start the autonomous loop
4. **Worktree**: Ralph creates a git worktree to isolate changes from main
5. **Completion**: When all stories pass, Ralph creates a draft PR and archives

### Epic (Multiple Parallel PRDs)

1. **Create Epic**: Use `/epic` skill to decompose a large feature into multiple PRDs
   - Creates `prds/<epic-name>/epic.json` with dependency graph
   - Creates multiple `prds/<prd-name>/prd.md` files
2. **Convert Each PRD**: Use `/ralph` on each PRD to generate `prd.json` files
3. **Run in Parallel**: Execute `./ralph-parallel.sh` to run PRDs concurrently
   - PRDs without dependencies start immediately
   - PRDs with dependencies wait for their dependencies to complete
4. **Monitor**: Use `./ralph-parallel.sh --status` or `--attach` to monitor progress

## Status Values

- `unstarted` - PRD exists but work hasn't begun
- `in_progress` - Ralph is actively working on this PRD
- `complete` - All stories pass, PR created
- `error` - Ralph encountered an irrecoverable error

## Epics and Dependencies

Epics group related PRDs that can be worked on in parallel:

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

**Dependency Rules:**
- PRDs with empty `dependsOn` can run in parallel
- PRDs with dependencies wait for ALL dependencies to be `complete`
- Circular dependencies are detected and rejected
- Use `/epic` skill to create well-structured dependency graphs

## Flowchart

The `flowchart/` directory contains an interactive visualization built with React Flow. It's designed for presentations - click through to reveal each step with animations.

To run locally:
```bash
cd flowchart
npm install
npm run dev
```

## Patterns

- Each iteration spawns a fresh Claude Code instance with clean context
- Memory persists via git history, `progress.txt`, and `prd.json`
- Stories should be small enough to complete in one context window
- Worktrees isolate feature work from the main branch
- Draft PRs are created automatically when all stories complete
- Always update CLAUDE.md with discovered patterns for future iterations
