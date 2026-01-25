#!/bin/bash
# Ralph Parallel - Run multiple Ralph loops in parallel via tmux
#
# Usage:
#   ./ralph-parallel.sh              # Run all PRDs with satisfied dependencies
#   ./ralph-parallel.sh --max 3      # Limit to 3 simultaneous PRDs
#   ./ralph-parallel.sh --epic NAME  # Only PRDs from a specific epic
#   ./ralph-parallel.sh --status     # Show status of all PRDs
#   ./ralph-parallel.sh --attach     # Attach to existing session
#   ./ralph-parallel.sh --stop       # Stop all running PRDs

set -e

# === CONFIGURATION ===

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect if running from .ralph/ or directly
if [[ "$(basename "$SCRIPT_DIR")" == ".ralph" ]]; then
  PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
else
  PROJECT_ROOT="$SCRIPT_DIR"
fi

PRDS_DIR="$PROJECT_ROOT/prds"
TMUX_SESSION="ralph-parallel"
MAX_PARALLEL=${MAX_PARALLEL:-0}  # 0 = unlimited
EPIC_FILTER=""
POLL_INTERVAL=10  # seconds between status checks

# === UTILITY FUNCTIONS ===

print_header() {
  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "  $1"
  echo "═══════════════════════════════════════════════════════"
}

print_status() {
  echo ""
  echo "───────────────────────────────────────────────────────"
  printf "  %-20s %-12s %s\n" "PRD" "STATUS" "PROGRESS"
  echo "───────────────────────────────────────────────────────"

  for dir in "$PRDS_DIR"/*/; do
    [ ! -d "$dir" ] && continue
    [ -f "$dir/epic.json" ] && continue  # Skip epic folders

    local name=$(basename "$dir")
    local status=$(cat "$dir/status" 2>/dev/null || echo "unknown")
    local total=$(jq '.userStories | length' "$dir/prd.json" 2>/dev/null || echo "?")
    local done=$(jq '[.userStories[] | select(.passes == true)] | length' "$dir/prd.json" 2>/dev/null || echo "?")
    local epic=$(jq -r '.epicName // "-"' "$dir/prd.json" 2>/dev/null || echo "-")

    # Apply epic filter if set
    if [ -n "$EPIC_FILTER" ] && [ "$epic" != "$EPIC_FILTER" ]; then
      continue
    fi

    printf "  %-20s %-12s %s/%s\n" "$name" "[$status]" "$done" "$total"
  done
  echo "───────────────────────────────────────────────────────"
}

# === DEPENDENCY FUNCTIONS ===

# Check if a PRD's dependencies are satisfied (all complete)
dependencies_satisfied() {
  local PRD_DIR="$1"
  local PRD_JSON="$PRD_DIR/prd.json"

  if [ ! -f "$PRD_JSON" ]; then
    return 1
  fi

  local DEPENDS_ON=$(jq -r '.dependsOn // [] | .[]' "$PRD_JSON" 2>/dev/null)

  if [ -z "$DEPENDS_ON" ]; then
    return 0  # No dependencies
  fi

  for DEP in $DEPENDS_ON; do
    local DEP_DIR="$PRDS_DIR/$DEP"
    local DEP_STATUS=""

    if [ -f "$DEP_DIR/status" ]; then
      DEP_STATUS=$(cat "$DEP_DIR/status")
    fi

    if [ "$DEP_STATUS" != "complete" ]; then
      return 1  # Dependency not satisfied
    fi
  done

  return 0
}

# Find PRDs that can be started (unstarted + dependencies satisfied)
find_runnable_prds() {
  local RUNNABLE=()

  for dir in "$PRDS_DIR"/*/; do
    [ ! -d "$dir" ] && continue
    [ -f "$dir/epic.json" ] && continue  # Skip epic folders
    [ ! -f "$dir/prd.json" ] && continue

    local name=$(basename "$dir")
    local status=$(cat "$dir/status" 2>/dev/null || echo "unknown")

    # Apply epic filter if set
    if [ -n "$EPIC_FILTER" ]; then
      local epic=$(jq -r '.epicName // ""' "$dir/prd.json" 2>/dev/null || echo "")
      if [ "$epic" != "$EPIC_FILTER" ]; then
        continue
      fi
    fi

    # Only consider unstarted PRDs
    if [ "$status" != "unstarted" ]; then
      continue
    fi

    # Check dependencies
    if dependencies_satisfied "$dir"; then
      RUNNABLE+=("$name")
    fi
  done

  echo "${RUNNABLE[@]}"
}

# Find PRDs currently in progress
find_in_progress_prds() {
  local IN_PROGRESS=()

  for dir in "$PRDS_DIR"/*/; do
    [ ! -d "$dir" ] && continue
    [ -f "$dir/epic.json" ] && continue

    local name=$(basename "$dir")
    local status=$(cat "$dir/status" 2>/dev/null || echo "unknown")

    if [ "$status" = "in_progress" ]; then
      IN_PROGRESS+=("$name")
    fi
  done

  echo "${IN_PROGRESS[@]}"
}

# Count PRDs by status
count_prds_by_status() {
  local STATUS="$1"
  local COUNT=0

  for dir in "$PRDS_DIR"/*/; do
    [ ! -d "$dir" ] && continue
    [ -f "$dir/epic.json" ] && continue

    local current_status=$(cat "$dir/status" 2>/dev/null || echo "unknown")

    # Apply epic filter if set
    if [ -n "$EPIC_FILTER" ]; then
      local epic=$(jq -r '.epicName // ""' "$dir/prd.json" 2>/dev/null || echo "")
      if [ "$epic" != "$EPIC_FILTER" ]; then
        continue
      fi
    fi

    if [ "$current_status" = "$STATUS" ]; then
      COUNT=$((COUNT + 1))
    fi
  done

  echo "$COUNT"
}

# === TMUX FUNCTIONS ===

# Check if tmux is installed
check_tmux() {
  if ! command -v tmux &> /dev/null; then
    echo "ERROR: tmux is not installed."
    echo ""
    echo "Install tmux:"
    echo "  macOS:  brew install tmux"
    echo "  Ubuntu: sudo apt install tmux"
    echo "  Arch:   sudo pacman -S tmux"
    exit 1
  fi
}

# Check if session already exists
session_exists() {
  tmux has-session -t "$TMUX_SESSION" 2>/dev/null
}

# Create the main tmux session with status window
create_session() {
  if session_exists; then
    echo "Session '$TMUX_SESSION' already exists."
    echo "Use --attach to reconnect or --stop to terminate."
    exit 1
  fi

  echo "Creating tmux session: $TMUX_SESSION"

  # Create session with status window
  tmux new-session -d -s "$TMUX_SESSION" -n "status" \
    "watch -n 5 '$SCRIPT_DIR/ralph-parallel.sh --status'"
}

# Spawn a new window for a PRD
spawn_prd_window() {
  local PRD_NAME="$1"

  if ! session_exists; then
    echo "ERROR: No tmux session. Run without --attach first."
    return 1
  fi

  echo "Spawning window for PRD: $PRD_NAME"

  # Create new window running ralph.sh for this PRD
  tmux new-window -t "$TMUX_SESSION" -n "$PRD_NAME" \
    "$SCRIPT_DIR/ralph.sh 50 $PRD_NAME; echo 'Press Enter to close'; read"
}

# Kill a specific PRD window
kill_prd_window() {
  local PRD_NAME="$1"

  if session_exists; then
    tmux kill-window -t "$TMUX_SESSION:$PRD_NAME" 2>/dev/null || true
  fi
}

# Stop all and clean up
stop_all() {
  if session_exists; then
    echo "Stopping Ralph Parallel session..."

    # Mark all in_progress PRDs as error (interrupted)
    for dir in "$PRDS_DIR"/*/; do
      [ ! -d "$dir" ] && continue
      local status=$(cat "$dir/status" 2>/dev/null || echo "")
      if [ "$status" = "in_progress" ]; then
        echo "interrupted" > "$dir/status"
      fi
    done

    tmux kill-session -t "$TMUX_SESSION"
    echo "Session stopped."
  else
    echo "No active session found."
  fi
}

# === MONITOR LOOP ===

# Main monitoring loop that spawns new PRDs as dependencies complete
monitor_loop() {
  print_header "Ralph Parallel - Monitor Loop"
  echo ""
  echo "Epic filter: ${EPIC_FILTER:-none}"
  echo "Max parallel: ${MAX_PARALLEL:-unlimited}"
  echo "Poll interval: ${POLL_INTERVAL}s"
  echo ""
  echo "Press Ctrl+C to stop monitoring (PRDs will continue running)"
  echo ""

  # Trap SIGINT for graceful shutdown
  trap 'echo ""; echo "Monitor stopped. PRDs continue in tmux."; echo "Use --attach to reconnect or --stop to terminate."; exit 0' INT

  while true; do
    local IN_PROGRESS=($(find_in_progress_prds))
    local RUNNABLE=($(find_runnable_prds))
    local COMPLETE=$(count_prds_by_status "complete")
    local ERRORS=$(count_prds_by_status "error")

    # Calculate how many we can spawn
    local CURRENT_COUNT=${#IN_PROGRESS[@]}
    local CAN_SPAWN=999

    if [ "$MAX_PARALLEL" -gt 0 ]; then
      CAN_SPAWN=$((MAX_PARALLEL - CURRENT_COUNT))
    fi

    # Show current status
    echo "[$(date '+%H:%M:%S')] Running: $CURRENT_COUNT | Queued: ${#RUNNABLE[@]} | Complete: $COMPLETE | Errors: $ERRORS"

    # Spawn new PRDs if we have capacity and runnable PRDs
    local SPAWNED=0
    for PRD_NAME in "${RUNNABLE[@]}"; do
      if [ "$CAN_SPAWN" -le 0 ]; then
        break
      fi

      spawn_prd_window "$PRD_NAME"
      CAN_SPAWN=$((CAN_SPAWN - 1))
      SPAWNED=$((SPAWNED + 1))
    done

    if [ "$SPAWNED" -gt 0 ]; then
      echo "  -> Spawned $SPAWNED new PRD(s)"
    fi

    # Check if we're done
    local TOTAL_ACTIVE=$((CURRENT_COUNT + ${#RUNNABLE[@]}))
    if [ "$TOTAL_ACTIVE" -eq 0 ]; then
      echo ""
      echo "All PRDs completed or blocked!"
      print_status
      break
    fi

    sleep "$POLL_INTERVAL"
  done
}

# === MAIN ===

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --max)
      MAX_PARALLEL="$2"
      shift 2
      ;;
    --epic)
      EPIC_FILTER="$2"
      shift 2
      ;;
    --status|-s)
      print_status
      exit 0
      ;;
    --attach|-a)
      check_tmux
      if session_exists; then
        tmux attach-session -t "$TMUX_SESSION"
      else
        echo "No active session. Start with: ./ralph-parallel.sh"
      fi
      exit 0
      ;;
    --stop)
      stop_all
      exit 0
      ;;
    --help|-h)
      echo "Usage: ./ralph-parallel.sh [options]"
      echo ""
      echo "Options:"
      echo "  --max N       Limit to N simultaneous PRDs (default: unlimited)"
      echo "  --epic NAME   Only run PRDs from specified epic"
      echo "  --status, -s  Show status of all PRDs"
      echo "  --attach, -a  Attach to existing tmux session"
      echo "  --stop        Stop all running PRDs"
      echo "  --help, -h    Show this help"
      echo ""
      echo "Examples:"
      echo "  ./ralph-parallel.sh                # Run all eligible PRDs"
      echo "  ./ralph-parallel.sh --max 2        # Max 2 concurrent"
      echo "  ./ralph-parallel.sh --epic auth    # Only PRDs in 'auth' epic"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information."
      exit 1
      ;;
  esac
done

# Pre-flight checks
check_tmux

if [ ! -d "$PRDS_DIR" ]; then
  echo "ERROR: No prds/ directory found."
  echo "Create PRDs with /prd or /epic skill first."
  exit 1
fi

# Show initial status
print_header "Ralph Parallel Execution"
print_status

# Find initial runnable PRDs
RUNNABLE=($(find_runnable_prds))

if [ ${#RUNNABLE[@]} -eq 0 ]; then
  echo ""
  echo "No runnable PRDs found."
  echo ""
  echo "Possible reasons:"
  echo "  - All PRDs are already complete or in_progress"
  echo "  - All PRDs have unmet dependencies"
  echo "  - No PRDs match the epic filter"
  echo ""
  echo "Use --status to see current state."
  exit 0
fi

echo ""
echo "Found ${#RUNNABLE[@]} PRD(s) ready to run:"
for PRD in "${RUNNABLE[@]}"; do
  echo "  - $PRD"
done
echo ""

read -p "Start parallel execution? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

# Create tmux session
create_session

# Start monitor loop (runs in background, spawns PRDs)
# We spawn the initial batch, then monitor for completions
IN_PROGRESS=($(find_in_progress_prds))
CURRENT_COUNT=${#IN_PROGRESS[@]}
CAN_SPAWN=${MAX_PARALLEL:-999}

if [ "$MAX_PARALLEL" -gt 0 ]; then
  CAN_SPAWN=$((MAX_PARALLEL - CURRENT_COUNT))
fi

# Spawn initial batch
SPAWNED=0
for PRD_NAME in "${RUNNABLE[@]}"; do
  if [ "$CAN_SPAWN" -le 0 ]; then
    break
  fi

  spawn_prd_window "$PRD_NAME"
  CAN_SPAWN=$((CAN_SPAWN - 1))
  SPAWNED=$((SPAWNED + 1))
done

echo ""
echo "Spawned $SPAWNED PRD(s) in tmux session '$TMUX_SESSION'"
echo ""
echo "Commands:"
echo "  Attach to session:  ./ralph-parallel.sh --attach"
echo "  Check status:       ./ralph-parallel.sh --status"
echo "  Stop all:           ./ralph-parallel.sh --stop"
echo ""
echo "Starting monitor loop..."
echo ""

# Run monitor loop
monitor_loop
