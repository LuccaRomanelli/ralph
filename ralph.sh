#!/bin/bash
# Ralph Wiggum - Long-running AI agent loop (Claude Code version)
# Multi-PRD + Worktree + PR Automation
#
# Usage:
#   ./ralph.sh [max_iterations] [prd_folder]  - Run specific PRD
#   ./ralph.sh --list                         - List all PRDs
#   ./ralph.sh --status                       - Show current PRD status

set -e

# === CONFIGURATION ===

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect if running from .ralph/ or directly
if [[ "$(basename "$SCRIPT_DIR")" == ".ralph" ]]; then
  PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
else
  PROJECT_ROOT="$SCRIPT_DIR"
fi

# Core files (templates) - always in SCRIPT_DIR
PROMPT_FILE="$SCRIPT_DIR/prompt.md"
FIX_PROMPT_TEMPLATE="$SCRIPT_DIR/fix-prompt.template.md"

# Directories
PRDS_DIR="$PROJECT_ROOT/prds"
WORKTREE_BASE="$PROJECT_ROOT/.worktrees"
ARCHIVE_DIR="$PROJECT_ROOT/archive"

# Legacy work files (for migration)
LEGACY_PRD_FILE="$PROJECT_ROOT/prd.json"
LEGACY_PROGRESS_FILE="$PROJECT_ROOT/progress.txt"
LEGACY_REGRESSION_FILE="$PROJECT_ROOT/regression-tests.json"
LEGACY_LAST_BRANCH_FILE="$PROJECT_ROOT/.last-branch"

# === UTILITY FUNCTIONS ===

# Print colored output
print_header() {
  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "  $1"
  echo "═══════════════════════════════════════════════════════"
}

print_section() {
  echo ""
  echo "───────────────────────────────────────────────────────"
  echo "  $1"
  echo "───────────────────────────────────────────────────────"
}

# === PRD FUNCTIONS ===

# List all PRDs with their status
list_prds() {
  if [ ! -d "$PRDS_DIR" ]; then
    echo "No PRDs found. Create one with /prd skill first."
    return 1
  fi

  echo ""
  echo "Available PRDs:"
  echo ""

  local i=1
  for dir in "$PRDS_DIR"/*/; do
    [ ! -d "$dir" ] && continue
    local name=$(basename "$dir")
    local status=$(cat "$dir/status" 2>/dev/null || echo "unknown")
    local total=$(jq '.userStories | length' "$dir/prd.json" 2>/dev/null || echo "?")
    local done=$(jq '[.userStories[] | select(.passes == true)] | length' "$dir/prd.json" 2>/dev/null || echo "?")

    printf "  %d. %-25s [%-11s] %s/%s stories\n" "$i" "$name" "$status" "$done" "$total"
    i=$((i + 1))
  done

  if [ "$i" -eq 1 ]; then
    echo "  No PRD folders found in $PRDS_DIR/"
    echo ""
    echo "Create a PRD with: /prd"
    return 1
  fi

  echo ""
  return 0
}

# Interactive PRD selection menu
select_prd_interactive() {
  if [ ! -d "$PRDS_DIR" ]; then
    echo "ERROR: No prds/ directory found."
    echo "Create a PRD with /prd skill first."
    exit 1
  fi

  # Build array of PRD directories
  local PRD_LIST=()
  for dir in "$PRDS_DIR"/*/; do
    [ -d "$dir" ] && PRD_LIST+=("$dir")
  done

  if [ ${#PRD_LIST[@]} -eq 0 ]; then
    echo "ERROR: No PRD folders found in $PRDS_DIR/"
    echo "Create a PRD with /prd skill first."
    exit 1
  fi

  # If only one PRD, use it automatically
  if [ ${#PRD_LIST[@]} -eq 1 ]; then
    echo "${PRD_LIST[0]}"
    return 0
  fi

  # Show menu
  echo ""
  echo "Available PRDs:"
  echo ""

  local i=1
  for dir in "${PRD_LIST[@]}"; do
    local name=$(basename "$dir")
    local status=$(cat "$dir/status" 2>/dev/null || echo "unknown")
    local total=$(jq '.userStories | length' "$dir/prd.json" 2>/dev/null || echo "?")
    local done=$(jq '[.userStories[] | select(.passes == true)] | length' "$dir/prd.json" 2>/dev/null || echo "?")

    printf "  %d. %-25s [%-11s] %s/%s stories\n" "$i" "$name" "$status" "$done" "$total"
    i=$((i + 1))
  done

  echo ""
  read -p "Select PRD (1-$((i-1))) or 'q' to quit: " choice

  if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
    exit 0
  fi

  if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -lt "$i" ]; then
    echo "${PRD_LIST[$((choice-1))]}"
  else
    echo "Invalid selection" >&2
    exit 1
  fi
}

# Find PRD with in_progress status, or first unstarted
find_active_prd() {
  if [ ! -d "$PRDS_DIR" ]; then
    return 1
  fi

  # First, check for in_progress
  for dir in "$PRDS_DIR"/*/; do
    [ ! -d "$dir" ] && continue
    local status=$(cat "$dir/status" 2>/dev/null || echo "")
    if [ "$status" = "in_progress" ]; then
      echo "$dir"
      return 0
    fi
  done

  # Then, check for unstarted
  for dir in "$PRDS_DIR"/*/; do
    [ ! -d "$dir" ] && continue
    local status=$(cat "$dir/status" 2>/dev/null || echo "")
    if [ "$status" = "unstarted" ]; then
      echo "$dir"
      return 0
    fi
  done

  return 1
}

# === GIT WORKTREE FUNCTIONS ===

setup_worktree() {
  local BRANCH="$1"
  local WORKTREE_PATH="$2"

  # Check if worktree already exists
  if git -C "$PROJECT_ROOT" worktree list | grep -q "$WORKTREE_PATH"; then
    echo "Worktree exists, reusing: $WORKTREE_PATH"
    return 0
  fi

  mkdir -p "$(dirname "$WORKTREE_PATH")"

  # Determine base branch (try origin/main, then main, then HEAD)
  local BASE_BRANCH="origin/main"
  if ! git -C "$PROJECT_ROOT" rev-parse --verify "$BASE_BRANCH" >/dev/null 2>&1; then
    BASE_BRANCH="main"
    if ! git -C "$PROJECT_ROOT" rev-parse --verify "$BASE_BRANCH" >/dev/null 2>&1; then
      BASE_BRANCH="HEAD"
    fi
  fi

  # Create worktree
  if git -C "$PROJECT_ROOT" show-ref --verify --quiet "refs/heads/$BRANCH"; then
    echo "Creating worktree from existing branch: $BRANCH"
    git -C "$PROJECT_ROOT" worktree add "$WORKTREE_PATH" "$BRANCH"
  elif git -C "$PROJECT_ROOT" show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
    echo "Creating worktree from remote branch: origin/$BRANCH"
    git -C "$PROJECT_ROOT" worktree add "$WORKTREE_PATH" -b "$BRANCH" "origin/$BRANCH"
  else
    echo "Creating worktree with new branch: $BRANCH (from $BASE_BRANCH)"
    git -C "$PROJECT_ROOT" worktree add "$WORKTREE_PATH" -b "$BRANCH" "$BASE_BRANCH"
  fi
}

cleanup_worktree() {
  local WORKTREE_PATH="$1"
  local PRD_DIR="$2"
  local PRD_NAME="$3"

  cd "$PROJECT_ROOT"

  # Archive work files
  local DATE=$(date +%Y-%m-%d)
  local ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$PRD_NAME"

  echo "Archiving to: $ARCHIVE_FOLDER"
  mkdir -p "$ARCHIVE_FOLDER"

  [ -f "$WORKTREE_PATH/prd.json" ] && cp "$WORKTREE_PATH/prd.json" "$ARCHIVE_FOLDER/"
  [ -f "$WORKTREE_PATH/progress.txt" ] && cp "$WORKTREE_PATH/progress.txt" "$ARCHIVE_FOLDER/"
  [ -f "$WORKTREE_PATH/regression-tests.json" ] && cp "$WORKTREE_PATH/regression-tests.json" "$ARCHIVE_FOLDER/"

  # Also copy from PRD dir
  [ -f "$PRD_DIR/prd.md" ] && cp "$PRD_DIR/prd.md" "$ARCHIVE_FOLDER/"

  # Remove worktree
  echo "Removing worktree..."
  git -C "$PROJECT_ROOT" worktree remove "$WORKTREE_PATH" --force 2>/dev/null || true
}

# === PR FUNCTIONS ===

build_pr_body() {
  local PRD_JSON="$1"

  local DESCRIPTION=$(jq -r '.description // "No description"' "$PRD_JSON")
  local STORIES=$(jq -r '.userStories[] | "- [x] \(.id): \(.title)"' "$PRD_JSON" 2>/dev/null || echo "")

  cat << EOF
## Summary

$DESCRIPTION

## User Stories

$STORIES

## Test Plan

- [ ] All regression tests pass
- [ ] Manual verification completed

---
🤖 Generated by [Ralph](https://github.com/ralphwiggum/ralph)
EOF
}

create_draft_pr() {
  local WORKTREE_PATH="$1"
  local PRD_JSON="$WORKTREE_PATH/prd.json"

  cd "$WORKTREE_PATH"

  local BRANCH=$(jq -r '.branchName' "$PRD_JSON")
  local DESCRIPTION=$(jq -r '.description' "$PRD_JSON")

  # Check if PR already exists
  if gh pr list --head "$BRANCH" --json number --jq '.[0].number' 2>/dev/null | grep -q .; then
    echo "PR already exists for branch: $BRANCH"
    local PR_URL=$(gh pr view --json url --jq '.url' 2>/dev/null || echo "")
    [ -n "$PR_URL" ] && echo "PR URL: $PR_URL"
    return 0
  fi

  # Push branch
  echo "Pushing branch: $BRANCH"
  git push -u origin "$BRANCH"

  # Create PR draft
  echo "Creating draft PR..."
  local PR_BODY=$(build_pr_body "$PRD_JSON")

  gh pr create --draft --title "$DESCRIPTION" --body "$PR_BODY"
}

# === REGRESSION TESTING ===

# Fix a failing regression test by spawning Claude
fix_regression() {
  local TEST_ID="$1"
  local STORY_ID="$2"
  local STORY_TITLE="$3"
  local TEST_DESCRIPTION="$4"
  local TEST_COMMAND="$5"
  local MAX_ATTEMPTS="$6"
  local WORK_DIR="$7"

  echo "   Attempting to fix regression: $TEST_ID"

  for attempt in $(seq 1 $MAX_ATTEMPTS); do
    echo "   Fix attempt $attempt of $MAX_ATTEMPTS..."

    # Create fix prompt from template
    FIX_PROMPT=$(cat "$FIX_PROMPT_TEMPLATE" | \
      sed "s|{{TEST_ID}}|$TEST_ID|g" | \
      sed "s|{{STORY_ID}}|$STORY_ID|g" | \
      sed "s|{{STORY_TITLE}}|$STORY_TITLE|g" | \
      sed "s|{{TEST_DESCRIPTION}}|$TEST_DESCRIPTION|g" | \
      sed "s|{{TEST_COMMAND}}|$TEST_COMMAND|g")

    # Spawn Claude to fix the regression (in worktree)
    cd "$WORK_DIR"
    echo "$FIX_PROMPT" | claude --dangerously-skip-permissions -p 2>&1 | tee /dev/stderr || true

    # Re-run the test to verify fix
    echo "   Verifying fix..."
    cd "$WORK_DIR"
    if eval "$TEST_COMMAND" > /dev/null 2>&1; then
      echo "   Fix successful!"

      # Update test result in regression-tests.json
      local REGRESSION_FILE="$WORK_DIR/regression-tests.json"
      local TEMP_FILE=$(mktemp)
      jq --arg id "$TEST_ID" --arg now "$(date -Iseconds)" \
        '(.tests[] | select(.id == $id)) |= . + {"lastRun": $now, "lastResult": "pass"}' \
        "$REGRESSION_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$REGRESSION_FILE"

      return 0
    fi

    echo "   Fix attempt $attempt failed, test still failing"
  done

  echo "   All fix attempts exhausted for $TEST_ID"
  return 1
}

# Run regression tests based on configuration
run_regression_tests() {
  local WORK_DIR="$1"
  local REGRESSION_FILE="$WORK_DIR/regression-tests.json"

  if [ ! -f "$REGRESSION_FILE" ]; then
    echo "No regression tests found"
    return 0
  fi

  local TEST_COUNT=$(jq '.tests | length' "$REGRESSION_FILE")
  if [ "$TEST_COUNT" -eq 0 ]; then
    echo "No regression tests to run"
    return 0
  fi

  print_section "Running Regression Tests"

  # Read configuration
  local STRATEGY=$(jq -r '.config.runStrategy // "all"' "$REGRESSION_FILE")
  local MAX_TESTS=$(jq -r '.config.maxTests // 0' "$REGRESSION_FILE")
  local FAILURE_ACTION=$(jq -r '.config.failureAction // "warn"' "$REGRESSION_FILE")
  local MAX_FIX_ATTEMPTS=$(jq -r '.config.maxFixAttempts // 3' "$REGRESSION_FILE")

  echo "Strategy: $STRATEGY | Max tests: ${MAX_TESTS:-unlimited} | On failure: $FAILURE_ACTION"

  # Select tests based on strategy
  local TESTS_TO_RUN
  case "$STRATEGY" in
    "newest")
      TESTS_TO_RUN=$(jq -r '[.tests | sort_by(.createdAt) | reverse] | .[0] | @json' "$REGRESSION_FILE")
      ;;
    "random")
      TESTS_TO_RUN=$(jq -r '[.tests | to_entries | map(.value)] | @json' "$REGRESSION_FILE")
      ;;
    "failing")
      TESTS_TO_RUN=$(jq -r '[.tests[] | select(.lastResult == "fail" or .lastResult == "never")] | @json' "$REGRESSION_FILE")
      ;;
    *)  # "all" or default
      TESTS_TO_RUN=$(jq -r '.tests | @json' "$REGRESSION_FILE")
      ;;
  esac

  # Parse tests into array
  local TESTS_ARRAY
  TESTS_ARRAY=$(echo "$TESTS_TO_RUN" | jq -r '.[] | @base64' 2>/dev/null || echo "")

  if [ -z "$TESTS_ARRAY" ]; then
    echo "No tests selected for strategy: $STRATEGY"
    return 0
  fi

  # Shuffle for random strategy
  if [ "$STRATEGY" = "random" ]; then
    TESTS_ARRAY=$(echo "$TESTS_ARRAY" | shuf)
  fi

  # Apply maxTests limit
  if [ "$MAX_TESTS" -gt 0 ]; then
    TESTS_ARRAY=$(echo "$TESTS_ARRAY" | head -n "$MAX_TESTS")
  fi

  local PASSED=0
  local FAILED=0
  local TOTAL=0

  cd "$WORK_DIR"

  for TEST_B64 in $TESTS_ARRAY; do
    TOTAL=$((TOTAL + 1))

    local TEST_JSON=$(echo "$TEST_B64" | base64 -d)
    local TEST_ID=$(echo "$TEST_JSON" | jq -r '.id')
    local STORY_ID=$(echo "$TEST_JSON" | jq -r '.storyId')
    local STORY_TITLE=$(echo "$TEST_JSON" | jq -r '.storyTitle')
    local TEST_DESC=$(echo "$TEST_JSON" | jq -r '.description')
    local TEST_CMD=$(echo "$TEST_JSON" | jq -r '.command')

    echo ""
    echo "[$TOTAL] $TEST_ID: $TEST_DESC"
    echo "    Command: $TEST_CMD"

    # Run the test
    if eval "$TEST_CMD" > /dev/null 2>&1; then
      echo "    ✓ PASS"
      PASSED=$((PASSED + 1))

      # Update lastRun and lastResult
      local TEMP_FILE=$(mktemp)
      jq --arg id "$TEST_ID" --arg now "$(date -Iseconds)" \
        '(.tests[] | select(.id == $id)) |= . + {"lastRun": $now, "lastResult": "pass"}' \
        "$REGRESSION_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$REGRESSION_FILE"
    else
      echo "    ✗ FAIL"
      FAILED=$((FAILED + 1))

      # Update lastRun and lastResult
      local TEMP_FILE=$(mktemp)
      jq --arg id "$TEST_ID" --arg now "$(date -Iseconds)" \
        '(.tests[] | select(.id == $id)) |= . + {"lastRun": $now, "lastResult": "fail"}' \
        "$REGRESSION_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$REGRESSION_FILE"

      # Handle failure based on configured action
      case "$FAILURE_ACTION" in
        "stop")
          echo ""
          echo "REGRESSION FAILURE: Stopping Ralph (failureAction=stop)"
          echo "Failed test: $TEST_ID - $TEST_DESC"
          return 1
          ;;
        "fix")
          if fix_regression "$TEST_ID" "$STORY_ID" "$STORY_TITLE" "$TEST_DESC" "$TEST_CMD" "$MAX_FIX_ATTEMPTS" "$WORK_DIR"; then
            FAILED=$((FAILED - 1))
            PASSED=$((PASSED + 1))
          else
            echo ""
            echo "REGRESSION FAILURE: Could not auto-fix $TEST_ID after $MAX_FIX_ATTEMPTS attempts"
            return 1
          fi
          ;;
        "warn")
          echo "    WARNING: Regression detected, continuing anyway"
          ;;
        "continue")
          # Silent continue
          ;;
      esac
    fi
  done

  echo ""
  echo "───────────────────────────────────────────────────────"
  echo "  Regression Results: $PASSED/$TOTAL passed"
  if [ "$FAILED" -gt 0 ]; then
    echo "  $FAILED test(s) failed"
  fi
  echo "───────────────────────────────────────────────────────"

  return 0
}

# === DEPENDENCY VALIDATION ===

# Check if a PRD's dependencies are satisfied
check_dependencies() {
  local PRD_JSON="$1"

  # Read dependsOn array from prd.json
  local DEPENDS_ON=$(jq -r '.dependsOn // [] | .[]' "$PRD_JSON" 2>/dev/null)

  if [ -z "$DEPENDS_ON" ]; then
    return 0  # No dependencies
  fi

  local BLOCKED=0
  local BLOCKING_PRDS=""

  for DEP in $DEPENDS_ON; do
    local DEP_DIR="$PRDS_DIR/$DEP"
    local DEP_STATUS=""

    if [ -f "$DEP_DIR/status" ]; then
      DEP_STATUS=$(cat "$DEP_DIR/status")
    else
      DEP_STATUS="unknown"
    fi

    if [ "$DEP_STATUS" != "complete" ]; then
      BLOCKED=1
      BLOCKING_PRDS="$BLOCKING_PRDS  - $DEP ($DEP_STATUS)\n"
    fi
  done

  if [ "$BLOCKED" -eq 1 ]; then
    echo ""
    echo "ERROR: This PRD has unmet dependencies."
    echo ""
    echo "Blocking PRDs (must be 'complete' first):"
    echo -e "$BLOCKING_PRDS"
    echo ""
    echo "Options:"
    echo "  1. Run the blocking PRDs first: ./ralph.sh <iterations> <prd-name>"
    echo "  2. Use parallel execution: ./ralph-parallel.sh"
    echo "  3. Remove dependencies from prd.json if not actually needed"
    return 1
  fi

  return 0
}

# Detect circular dependencies in epic
check_circular_dependencies() {
  local EPIC_JSON="$1"

  if [ ! -f "$EPIC_JSON" ]; then
    return 0
  fi

  # Simple cycle detection using DFS approach in jq
  local CYCLE=$(jq -r '
    def has_cycle:
      . as $graph |
      reduce .prds[] as $prd (
        { visited: {}, rec_stack: {}, has_cycle: false };
        if .has_cycle then .
        else
          def dfs($name):
            if .has_cycle then .
            elif .rec_stack[$name] then .has_cycle = true
            elif .visited[$name] then .
            else
              .visited[$name] = true |
              .rec_stack[$name] = true |
              ($graph.prds[] | select(.name == $name) | .dependsOn // []) as $deps |
              reduce $deps[] as $dep (.; dfs($dep)) |
              .rec_stack[$name] = false
            end;
          dfs($prd.name)
        end
      ) | .has_cycle;
    if has_cycle then "CYCLE_DETECTED" else "OK" end
  ' "$EPIC_JSON" 2>/dev/null || echo "OK")

  if [ "$CYCLE" = "CYCLE_DETECTED" ]; then
    echo "ERROR: Circular dependency detected in epic!"
    echo "Check the epic.json file and ensure no PRD depends on itself (directly or indirectly)."
    return 1
  fi

  return 0
}

# === MIGRATION ===

migrate_legacy_format() {
  # If prd.json exists in root but prds/ does not exist, migrate
  if [ -f "$LEGACY_PRD_FILE" ] && [ ! -d "$PRDS_DIR" ]; then
    echo "Migrating legacy PRD format to prds/ structure..."

    local BRANCH=$(jq -r '.branchName // "unknown"' "$LEGACY_PRD_FILE" | sed 's|^ralph/||')
    local PRD_DIR="$PRDS_DIR/$BRANCH"

    mkdir -p "$PRD_DIR"

    mv "$LEGACY_PRD_FILE" "$PRD_DIR/prd.json"
    [ -f "$LEGACY_PROGRESS_FILE" ] && mv "$LEGACY_PROGRESS_FILE" "$PRD_DIR/progress.txt"
    [ -f "$LEGACY_REGRESSION_FILE" ] && mv "$LEGACY_REGRESSION_FILE" "$PRD_DIR/regression-tests.json"
    [ -f "$LEGACY_LAST_BRANCH_FILE" ] && rm "$LEGACY_LAST_BRANCH_FILE"

    echo "in_progress" > "$PRD_DIR/status"

    echo "Migrated to: $PRD_DIR/"
  fi
}

# === INITIALIZATION ===

init_work_files() {
  local WORK_DIR="$1"
  local PRD_DIR="$2"
  local PROGRESS_FILE="$WORK_DIR/progress.txt"
  local REGRESSION_FILE="$WORK_DIR/regression-tests.json"
  local PRD_FILE="$WORK_DIR/prd.json"

  # Copy prd.json to worktree if not present
  if [ ! -f "$PRD_FILE" ] && [ -f "$PRD_DIR/prd.json" ]; then
    cp "$PRD_DIR/prd.json" "$PRD_FILE"
  fi

  # Initialize progress file if it doesn't exist
  if [ ! -f "$PROGRESS_FILE" ]; then
    # Check if there's one in PRD dir
    if [ -f "$PRD_DIR/progress.txt" ]; then
      cp "$PRD_DIR/progress.txt" "$PROGRESS_FILE"
    else
      echo "# Ralph Progress Log" > "$PROGRESS_FILE"
      echo "Started: $(date)" >> "$PROGRESS_FILE"
      echo "---" >> "$PROGRESS_FILE"
    fi
  fi

  # Initialize regression-tests.json if it doesn't exist
  if [ ! -f "$REGRESSION_FILE" ]; then
    # Check if there's one in PRD dir
    if [ -f "$PRD_DIR/regression-tests.json" ]; then
      cp "$PRD_DIR/regression-tests.json" "$REGRESSION_FILE"
    else
      local PROJECT_NAME=$(jq -r '.project // "Unknown"' "$PRD_FILE" 2>/dev/null || echo "Unknown")
      local BRANCH_NAME=$(jq -r '.branchName // "main"' "$PRD_FILE" 2>/dev/null || echo "main")
      cat > "$REGRESSION_FILE" << EOF
{
  "project": "$PROJECT_NAME",
  "branchName": "$BRANCH_NAME",
  "config": {
    "runStrategy": "all",
    "maxTests": 0,
    "failureAction": "warn",
    "maxFixAttempts": 3
  },
  "tests": []
}
EOF
    fi
  fi
}

# Sync work files back to PRD directory
sync_work_files() {
  local WORK_DIR="$1"
  local PRD_DIR="$2"

  [ -f "$WORK_DIR/prd.json" ] && cp "$WORK_DIR/prd.json" "$PRD_DIR/prd.json"
  [ -f "$WORK_DIR/progress.txt" ] && cp "$WORK_DIR/progress.txt" "$PRD_DIR/progress.txt"
  [ -f "$WORK_DIR/regression-tests.json" ] && cp "$WORK_DIR/regression-tests.json" "$PRD_DIR/regression-tests.json"
}

# === MAIN ===

# Handle command-line flags
case "${1:-}" in
  --list|-l)
    list_prds
    exit $?
    ;;
  --status|-s)
    PRD_DIR=$(find_active_prd)
    if [ -n "$PRD_DIR" ]; then
      PRD_NAME=$(basename "$PRD_DIR")
      STATUS=$(cat "$PRD_DIR/status" 2>/dev/null || echo "unknown")
      TOTAL=$(jq '.userStories | length' "$PRD_DIR/prd.json" 2>/dev/null || echo "?")
      DONE=$(jq '[.userStories[] | select(.passes == true)] | length' "$PRD_DIR/prd.json" 2>/dev/null || echo "?")
      echo "Current PRD: $PRD_NAME"
      echo "Status: $STATUS"
      echo "Progress: $DONE/$TOTAL stories"
    else
      echo "No active PRD found."
    fi
    exit 0
    ;;
  --help|-h)
    echo "Usage: ./ralph.sh [max_iterations] [prd_folder]"
    echo ""
    echo "Arguments:"
    echo "  max_iterations  Maximum number of iterations (default: 10)"
    echo "  prd_folder      Name of PRD folder in prds/ (optional)"
    echo ""
    echo "Flags:"
    echo "  --list, -l      List all PRDs and their status"
    echo "  --status, -s    Show current PRD status"
    echo "  --help, -h      Show this help message"
    exit 0
    ;;
esac

MAX_ITERATIONS=${1:-10}
PRD_FOLDER_ARG="${2:-}"

# Run migration if needed
migrate_legacy_format

# Find or select PRD
if [ -n "$PRD_FOLDER_ARG" ]; then
  PRD_DIR="$PRDS_DIR/$PRD_FOLDER_ARG"
  if [ ! -d "$PRD_DIR" ]; then
    echo "ERROR: PRD folder not found: $PRD_DIR"
    exit 1
  fi
else
  PRD_DIR=$(select_prd_interactive)
fi

PRD_NAME=$(basename "$PRD_DIR")

# Validate PRD files exist
if [ ! -f "$PRD_DIR/prd.md" ] && [ ! -f "$PRD_DIR/prd.json" ]; then
  echo "ERROR: PRD files not found in $PRD_DIR"
  echo "Expected: prd.md (human-readable) and/or prd.json (machine-readable)"
  echo ""
  echo "Use /prd to create a PRD first, then /ralph to convert it."
  exit 1
fi

if [ ! -f "$PRD_DIR/prd.json" ]; then
  echo "ERROR: prd.json not found in $PRD_DIR"
  echo "Use /ralph to convert prd.md to prd.json first."
  exit 1
fi

# Get branch name from PRD
BRANCH_NAME=$(jq -r '.branchName' "$PRD_DIR/prd.json")
if [ -z "$BRANCH_NAME" ] || [ "$BRANCH_NAME" = "null" ]; then
  echo "ERROR: branchName not found in prd.json"
  exit 1
fi

# Check for epic and circular dependencies
EPIC_NAME=$(jq -r '.epicName // ""' "$PRD_DIR/prd.json")
if [ -n "$EPIC_NAME" ] && [ "$EPIC_NAME" != "null" ]; then
  EPIC_JSON="$PRDS_DIR/$EPIC_NAME/epic.json"
  if [ -f "$EPIC_JSON" ]; then
    check_circular_dependencies "$EPIC_JSON" || exit 1
  fi
fi

# Check if dependencies are satisfied
check_dependencies "$PRD_DIR/prd.json" || exit 1

# Compute worktree path (strip ralph/ prefix for folder name)
WORKTREE_FOLDER=$(echo "$BRANCH_NAME" | sed 's|^ralph/||')
WORKTREE_PATH="$WORKTREE_BASE/$WORKTREE_FOLDER"

print_header "Ralph - Multi-PRD Agent Loop"
echo ""
echo "PRD: $PRD_NAME"
echo "Branch: $BRANCH_NAME"
echo "Worktree: $WORKTREE_PATH"
echo "Max iterations: $MAX_ITERATIONS"

# Setup worktree
print_section "Setting up Worktree"
setup_worktree "$BRANCH_NAME" "$WORKTREE_PATH"

# Initialize work files in worktree
init_work_files "$WORKTREE_PATH" "$PRD_DIR"

# Mark as in_progress
echo "in_progress" > "$PRD_DIR/status"

# === MAIN LOOP ===

for i in $(seq 1 $MAX_ITERATIONS); do
  print_header "Ralph Iteration $i of $MAX_ITERATIONS"

  # Change to worktree and run Claude
  cd "$WORKTREE_PATH"
  OUTPUT=$(cat "$PROMPT_FILE" | claude --dangerously-skip-permissions -p 2>&1 | tee /dev/stderr) || true

  # Sync work files back to PRD dir
  sync_work_files "$WORKTREE_PATH" "$PRD_DIR"

  # Check for completion signal
  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "Ralph completed all tasks!"

    # Run final regression tests
    if run_regression_tests "$WORKTREE_PATH"; then
      print_section "Creating Draft PR"
      create_draft_pr "$WORKTREE_PATH"

      # Mark as complete
      echo "complete" > "$PRD_DIR/status"

      # Sync final state
      sync_work_files "$WORKTREE_PATH" "$PRD_DIR"

      print_section "Cleanup"
      cleanup_worktree "$WORKTREE_PATH" "$PRD_DIR" "$PRD_NAME"

      echo ""
      echo "Ralph completed successfully at iteration $i of $MAX_ITERATIONS"
      exit 0
    else
      echo "Regression tests failed. PR not created."
      echo "error" > "$PRD_DIR/status"
      exit 1
    fi
  fi

  # Run regression tests after each iteration
  run_regression_tests "$WORKTREE_PATH" || true

  # Sync work files
  sync_work_files "$WORKTREE_PATH" "$PRD_DIR"

  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Worktree preserved at: $WORKTREE_PATH"
echo "Check $PRD_DIR/progress.txt for status."
exit 1
