#!/bin/bash
# Ralph Update Script
# Downloads the latest Ralph files from GitHub and updates the local installation
# Preserves work files (prd.json, progress.txt, etc.)

set -e

RALPH_REPO="https://raw.githubusercontent.com/LuccaRomanelli/ralph/main"

# Determine paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if running from .ralph/ directory
if [[ "$(basename "$SCRIPT_DIR")" == ".ralph" ]]; then
  RALPH_DIR="$SCRIPT_DIR"
  PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
else
  echo "Error: This script should be run from the .ralph/ directory"
  echo "Usage: .ralph/update.sh"
  exit 1
fi

SKILLS_DIR="$PROJECT_ROOT/.claude/skills"

echo "Updating Ralph..."
echo "Project root: $PROJECT_ROOT"
echo ""

# Create backup of current version
BACKUP_DIR="$RALPH_DIR/backup-$(date +%Y%m%d-%H%M%S)"
echo "Creating backup at: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
cp "$RALPH_DIR/ralph.sh" "$BACKUP_DIR/" 2>/dev/null || true
cp "$RALPH_DIR/prompt.md" "$BACKUP_DIR/" 2>/dev/null || true
cp "$RALPH_DIR/fix-prompt.template.md" "$BACKUP_DIR/" 2>/dev/null || true
cp "$RALPH_DIR/VERSION" "$BACKUP_DIR/" 2>/dev/null || true

# Download core files to .ralph/
echo ""
echo "Downloading core files..."

download_file() {
  local filename="$1"
  local dest="$2"
  echo "  Downloading $filename..."
  if curl -sSfL "$RALPH_REPO/$filename" -o "$dest/$filename"; then
    echo "    OK"
  else
    echo "    FAILED - keeping existing file"
  fi
}

download_file "ralph.sh" "$RALPH_DIR"
download_file "prompt.md" "$RALPH_DIR"
download_file "fix-prompt.template.md" "$RALPH_DIR"
download_file "prd.json.example" "$RALPH_DIR"
download_file "regression-tests.json.example" "$RALPH_DIR"
download_file "update.sh" "$RALPH_DIR"

# Make scripts executable
chmod +x "$RALPH_DIR/ralph.sh"
chmod +x "$RALPH_DIR/update.sh"

# Download skills
echo ""
echo "Downloading skills..."
mkdir -p "$SKILLS_DIR/prd"
mkdir -p "$SKILLS_DIR/ralph"

if curl -sSfL "$RALPH_REPO/skills/prd/SKILL.md" -o "$SKILLS_DIR/prd/SKILL.md"; then
  echo "  skills/prd/SKILL.md - OK"
else
  echo "  skills/prd/SKILL.md - FAILED"
fi

if curl -sSfL "$RALPH_REPO/skills/ralph/SKILL.md" -o "$SKILLS_DIR/ralph/SKILL.md"; then
  echo "  skills/ralph/SKILL.md - OK"
else
  echo "  skills/ralph/SKILL.md - FAILED"
fi

# Update VERSION file
echo ""
echo "Updating VERSION..."
cat > "$RALPH_DIR/VERSION" << EOF
source: github
repo: $RALPH_REPO
updated_at: $(date -Iseconds)
EOF

# Update examples in project root if they don't exist
echo ""
echo "Checking examples..."
if [ ! -f "$PROJECT_ROOT/prd.json.example" ]; then
  cp "$RALPH_DIR/prd.json.example" "$PROJECT_ROOT/" 2>/dev/null && echo "  Created prd.json.example" || true
fi
if [ ! -f "$PROJECT_ROOT/regression-tests.json.example" ]; then
  cp "$RALPH_DIR/regression-tests.json.example" "$PROJECT_ROOT/" 2>/dev/null && echo "  Created regression-tests.json.example" || true
fi

echo ""
echo "=========================================="
echo "Ralph updated successfully!"
echo ""
echo "Backup saved to: $BACKUP_DIR"
echo ""
echo "Work files preserved:"
echo "  - prd.json"
echo "  - progress.txt"
echo "  - regression-tests.json"
echo "  - archive/"
echo "=========================================="
