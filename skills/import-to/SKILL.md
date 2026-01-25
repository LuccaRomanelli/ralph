---
name: import-to
description: "Import Ralph to another project. Usage: /import-to /path/to/project. Run from the Ralph repository to copy Ralph files into a target project."
---

# Import Ralph to Project

Import Ralph into another project by copying the necessary files and creating the folder structure.

**Usage:** `/import-to /path/to/target/project`

---

## Prerequisites

- Run this skill from the Ralph repository directory
- Target must be an existing git repository

---

## The Job

1. **Validate the target path argument**
   - Must receive exactly one argument (the target path)
   - Path must exist and be a directory
   - Path must be a git repository (verify with `git -C $PATH rev-parse`)

2. **Check for existing installation**
   - If `.ralph/` already exists in target, ask if user wants to update
   - If user declines, abort

3. **Create directory structure in target:**
   ```
   .ralph/
   .claude/skills/prd/
   .claude/skills/ralph/
   prds/
   ```

4. **Copy core files to `.ralph/`:**
   - `ralph.sh`
   - `prompt.md`
   - `fix-prompt.template.md`
   - `prd.json.example`
   - `regression-tests.json.example`
   - `update.sh`

5. **Create VERSION file in `.ralph/`:**
   ```
   source: local
   copied_from: /path/to/ralph/repo
   copied_at: ISO-8601 timestamp
   ```

6. **Create wrapper script `ralph` in project root:**
   ```bash
   #!/bin/bash
   # Ralph wrapper - runs ralph.sh from .ralph/
   exec "$(dirname "$0")/.ralph/ralph.sh" "$@"
   ```
   Make it executable with `chmod +x`

7. **Copy skills to `.claude/skills/`:**
   - Copy `skills/prd/SKILL.md` to `.claude/skills/prd/SKILL.md`
   - Copy `skills/ralph/SKILL.md` to `.claude/skills/ralph/SKILL.md`
   - **IMPORTANT:** Preserve any existing skills that are not prd or ralph

8. **Update `.gitignore`:**
   - Add entries if not already present:
     ```
     # Ralph work files (legacy - root level)
     prd.json
     progress.txt
     regression-tests.json
     .last-branch

     # Ralph work files (multi-PRD structure)
     prds/*/progress.txt
     prds/*/regression-tests.json
     prds/*/status

     # Ralph directories
     .worktrees/
     archive/
     ```

9. **Create example files if they don't exist:**
   - Copy `prd.json.example` to target root (don't overwrite if exists)
   - Copy `regression-tests.json.example` to target root (don't overwrite if exists)

---

## Implementation Steps

### Step 1: Parse and validate argument

```bash
TARGET_PATH="$1"

if [ -z "$TARGET_PATH" ]; then
  echo "Error: Target path required"
  echo "Usage: /import-to /path/to/project"
  exit 1
fi

if [ ! -d "$TARGET_PATH" ]; then
  echo "Error: Target path does not exist or is not a directory: $TARGET_PATH"
  exit 1
fi

# Verify it's a git repository
if ! git -C "$TARGET_PATH" rev-parse --git-dir > /dev/null 2>&1; then
  echo "Error: Target is not a git repository: $TARGET_PATH"
  exit 1
fi
```

### Step 2: Check for existing installation

If `.ralph/` exists, ask user:
- "Ralph is already installed. Update? (y/n)"
- If no, abort

### Step 3: Determine Ralph source directory

The current working directory should be the Ralph repository. Get its absolute path:

```bash
RALPH_SOURCE="$(pwd)"

# Verify this is the Ralph repo by checking for key files
if [ ! -f "$RALPH_SOURCE/ralph.sh" ] || [ ! -f "$RALPH_SOURCE/prompt.md" ]; then
  echo "Error: Current directory does not appear to be the Ralph repository"
  echo "Please run this skill from the Ralph repository directory"
  exit 1
fi
```

### Step 4: Create directories

```bash
mkdir -p "$TARGET_PATH/.ralph"
mkdir -p "$TARGET_PATH/.claude/skills/prd"
mkdir -p "$TARGET_PATH/.claude/skills/ralph"
mkdir -p "$TARGET_PATH/prds"
```

### Step 5: Copy core files

```bash
cp "$RALPH_SOURCE/ralph.sh" "$TARGET_PATH/.ralph/"
cp "$RALPH_SOURCE/prompt.md" "$TARGET_PATH/.ralph/"
cp "$RALPH_SOURCE/fix-prompt.template.md" "$TARGET_PATH/.ralph/"
cp "$RALPH_SOURCE/prd.json.example" "$TARGET_PATH/.ralph/"
cp "$RALPH_SOURCE/regression-tests.json.example" "$TARGET_PATH/.ralph/"
cp "$RALPH_SOURCE/update.sh" "$TARGET_PATH/.ralph/"
chmod +x "$TARGET_PATH/.ralph/ralph.sh"
chmod +x "$TARGET_PATH/.ralph/update.sh"
```

### Step 6: Create VERSION file

```bash
cat > "$TARGET_PATH/.ralph/VERSION" << EOF
source: local
copied_from: $RALPH_SOURCE
copied_at: $(date -Iseconds)
EOF
```

### Step 7: Create wrapper script

```bash
cat > "$TARGET_PATH/ralph" << 'EOF'
#!/bin/bash
# Ralph wrapper - runs ralph.sh from .ralph/
exec "$(dirname "$0")/.ralph/ralph.sh" "$@"
EOF
chmod +x "$TARGET_PATH/ralph"
```

### Step 8: Copy skills

```bash
cp "$RALPH_SOURCE/skills/prd/SKILL.md" "$TARGET_PATH/.claude/skills/prd/SKILL.md"
cp "$RALPH_SOURCE/skills/ralph/SKILL.md" "$TARGET_PATH/.claude/skills/ralph/SKILL.md"
```

### Step 9: Update .gitignore

Check if each entry exists before adding:

```bash
GITIGNORE="$TARGET_PATH/.gitignore"

add_gitignore() {
  local entry="$1"
  if ! grep -qxF "$entry" "$GITIGNORE" 2>/dev/null; then
    echo "$entry" >> "$GITIGNORE"
  fi
}

# Add header comment if .gitignore doesn't exist or doesn't have Ralph section
if ! grep -q "# Ralph work files" "$GITIGNORE" 2>/dev/null; then
  echo "" >> "$GITIGNORE"
  echo "# Ralph work files (legacy - root level)" >> "$GITIGNORE"
fi

add_gitignore "prd.json"
add_gitignore "progress.txt"
add_gitignore "regression-tests.json"
add_gitignore ".last-branch"

# Add multi-PRD section
if ! grep -q "# Ralph work files (multi-PRD" "$GITIGNORE" 2>/dev/null; then
  echo "" >> "$GITIGNORE"
  echo "# Ralph work files (multi-PRD structure)" >> "$GITIGNORE"
fi

add_gitignore "prds/*/progress.txt"
add_gitignore "prds/*/regression-tests.json"
add_gitignore "prds/*/status"

# Add directories section
if ! grep -q "# Ralph directories" "$GITIGNORE" 2>/dev/null; then
  echo "" >> "$GITIGNORE"
  echo "# Ralph directories" >> "$GITIGNORE"
fi

add_gitignore ".worktrees/"
add_gitignore "archive/"
```

### Step 10: Copy examples (if not exist)

```bash
[ ! -f "$TARGET_PATH/prd.json.example" ] && cp "$RALPH_SOURCE/prd.json.example" "$TARGET_PATH/"
[ ! -f "$TARGET_PATH/regression-tests.json.example" ] && cp "$RALPH_SOURCE/regression-tests.json.example" "$TARGET_PATH/"
```

---

## Output

After successful import, display:

```
Ralph imported successfully to: $TARGET_PATH

Files created:
  .ralph/ralph.sh
  .ralph/prompt.md
  .ralph/fix-prompt.template.md
  .ralph/update.sh
  .ralph/VERSION
  ralph (wrapper script)
  .claude/skills/prd/SKILL.md
  .claude/skills/ralph/SKILL.md
  prds/ (directory for PRDs)

To get started:
  1. cd $TARGET_PATH
  2. Use /prd to create a PRD for your feature
  3. Use /ralph to convert it to prd.json
  4. Run ./ralph to start the autonomous loop

Commands:
  ./ralph              # Run with interactive PRD selection
  ./ralph 10 my-prd    # Run specific PRD with 10 iterations
  ./ralph --list       # List all PRDs and status
  ./ralph --status     # Show current PRD status

To update Ralph later:
  .ralph/update.sh
```

---

## Error Handling

- If target path is invalid: Display clear error message
- If not a git repo: Suggest initializing git first
- If current dir is not Ralph repo: Suggest navigating to Ralph repo first
- If copy fails: Display which file failed and suggest checking permissions

---

## Notes

- This skill copies files from the local Ralph repository, not from GitHub
- For updates from GitHub, use the `.ralph/update.sh` script after import
- The skill preserves existing `.claude/` contents and only adds/updates Ralph-related skills
- The `prds/` directory is created for the new multi-PRD workflow
- Legacy single-prd format is still supported and will auto-migrate on first run
