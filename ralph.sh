#!/bin/bash
# Ralph Wiggum - Long-running AI agent loop
# Usage: ./ralph.sh [max_iterations]

set -e

# Parse arguments
TOOL="claude"
MAX_ITERATIONS=10

while [[ $# -gt 0 ]]; do
  case $1 in
    --tool)
      TOOL="$2"
      shift 2
      ;;
    --tool=*)
      TOOL="${1#*=}"
      shift
      ;;
    *)
      # Assume it's max_iterations if it's a number
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS="$1"
      fi
      shift
      ;;
  esac
done

# Validate tool choice
if [[ "$TOOL" != "claude" ]]; then
  echo "Error: Invalid tool '$TOOL'. Only 'claude' is supported."
  exit 1
fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_FILE="$SCRIPT_DIR/prd.json"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
ARCHIVE_DIR="$SCRIPT_DIR/archive"
LAST_BRANCH_FILE="$SCRIPT_DIR/.last-branch"

# Validate required files exist
if [ ! -f "$PRD_FILE" ] || [ ! -s "$PRD_FILE" ]; then
  echo "Error: PRD file not found or empty at $PRD_FILE"
  echo "  If prd.json is a symlink, check the target exists."
  echo "  Run: ls -la $PRD_FILE"
  exit 1
fi

if [ ! -f "$SCRIPT_DIR/CLAUDE.md" ]; then
  echo "Error: CLAUDE.md not found at $SCRIPT_DIR/CLAUDE.md"
  exit 1
fi

# Archive previous run if branch changed
if [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")
  
  if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
    # Archive the previous run
    DATE=$(date +%Y-%m-%d)
    # Strip "ralph/" prefix from branch name for folder
    FOLDER_NAME=$(echo "$LAST_BRANCH" | sed 's|^ralph/||')
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"
    
    echo "Archiving previous run: $LAST_BRANCH"
    mkdir -p "$ARCHIVE_FOLDER"
    [ -f "$PRD_FILE" ] && cp "$PRD_FILE" "$ARCHIVE_FOLDER/"
    [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
    echo "   Archived to: $ARCHIVE_FOLDER"
    
    # Reset progress file for new run
    echo "# Ralph Progress Log" > "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
  fi
fi

# Track current branch
if [ -f "$PRD_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  if [ -n "$CURRENT_BRANCH" ]; then
    echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"
  fi
fi

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

echo "Starting Ralph - Tool: $TOOL - Max iterations: $MAX_ITERATIONS"

# Display PRD info
PRD_BRANCH=$(jq -r '.branchName // "No branch"' "$PRD_FILE")
PRD_DESC=$(jq -r '.description // "No description"' "$PRD_FILE")
echo "Branch: $PRD_BRANCH"
echo "Description: $PRD_DESC"

for i in $(seq 1 $MAX_ITERATIONS); do
  ITERATION_START=$(date +"%H:%M:%S")
  ITERATION_START_EPOCH=$(date +%s)

  echo ""
  echo "==============================================================="
  echo "  Ralph Iteration $i of $MAX_ITERATIONS ($TOOL)"
  echo "  Started at: $ITERATION_START"
  echo "==============================================================="

  # Start loading indicator in background
  (
    while true; do
      ELAPSED=$(($(date +%s) - ITERATION_START_EPOCH))
      MINS=$((ELAPSED / 60))
      SECS=$((ELAPSED % 60))
      printf "\r⏳ Processing... [%02d:%02d elapsed since %s]  " $MINS $SECS "$ITERATION_START"
      sleep 1
    done
  ) &
  LOADING_PID=$!

  # Cleanup loading indicator on exit
  trap "kill $LOADING_PID 2>/dev/null" EXIT

  # Run Claude Code with retry on transient errors
  MAX_RETRIES=3
  RETRY_COUNT=0
  OUTPUT=""

  while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
    OUTPUT=$(claude --dangerously-skip-permissions --print < "$SCRIPT_DIR/CLAUDE.md" 2>&1 | tee /dev/stderr) && break || EXIT_CODE=$?

    # Check for transient errors that warrant a retry
    if echo "$OUTPUT" | grep -qE "(No messages returned|ECONNRESET|ETIMEDOUT|rate limit|503|502)"; then
      RETRY_COUNT=$((RETRY_COUNT + 1))
      if [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; then
        echo ""
        echo "⚠️  Transient error detected (attempt $RETRY_COUNT/$MAX_RETRIES). Retrying in 10 seconds..."
        sleep 10
        continue
      else
        echo ""
        echo "⚠️  Max retries reached. Continuing to next iteration..."
        break
      fi
    else
      # Non-transient error or success, break out of retry loop
      break
    fi
  done

  # Stop loading indicator
  kill $LOADING_PID 2>/dev/null
  wait $LOADING_PID 2>/dev/null
  printf "\r                                                              \r"

  # Calculate total iteration time
  ITERATION_END_EPOCH=$(date +%s)
  TOTAL_ELAPSED=$((ITERATION_END_EPOCH - ITERATION_START_EPOCH))
  TOTAL_MINS=$((TOTAL_ELAPSED / 60))
  TOTAL_SECS=$((TOTAL_ELAPSED % 60))
  echo "✅ Iteration $i finished in ${TOTAL_MINS}m ${TOTAL_SECS}s"

  # Check for completion signal
  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "🎉 Ralph completed all tasks!"
    echo "Finished at iteration $i of $MAX_ITERATIONS"
    exit 0
  fi

  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status."
exit 1
