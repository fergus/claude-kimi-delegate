#!/usr/bin/env bash
#
# Delegation Task File Validator
# Usage: ./scripts/validate-delegation.sh <task-file>
#
# Validates that a task file follows the YYYYMMDD-NNN-short-slug.md naming
# convention and that its frontmatter is consistent with the filename.

set -euo pipefail

error() {
    echo "Error: $1" >&2
    exit 1
}

warn() {
    echo "Warning: $1" >&2
}

# Extract YAML frontmatter from a markdown file (lines between first two ---)
extract_frontmatter() {
    local file="$1"
    awk '
        BEGIN { in_fm = 0; count = 0 }
        /^---$/ {
            count++
            if (count == 1) { in_fm = 1; next }
            if (count == 2) { in_fm = 0; exit }
        }
        in_fm { print }
    ' "$file"
}

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ $# -eq 0 ] || [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    cat <<EOF
Usage: $0 <task-file>

Validates a delegation task file against project conventions:
- Filename follows YYYYMMDD-NNN-short-slug.md
- task_id matches the YYYYMMDD-NNN prefix
- output_path basename matches task filename + -result.md
- Required frontmatter fields present
- context_files exist inside project root

Exits 0 if valid, 1 if invalid.
EOF
    exit 0
fi

TASK_FILE="$1"
ERRORS=0

# ---------------------------------------------------------------------------
# File existence
# ---------------------------------------------------------------------------

if [ ! -f "$TASK_FILE" ]; then
    error "task file not found: $TASK_FILE"
fi

if [ ! -s "$TASK_FILE" ]; then
    error "task file is empty: $TASK_FILE"
fi

TASK_ABS="$(realpath "$TASK_FILE")"
if [[ ! "$TASK_ABS" == "$PROJECT_ROOT"* ]]; then
    error "task file must be inside project root" \
        "  project root: $PROJECT_ROOT" \
        "  task file:    $TASK_ABS"
fi

# ---------------------------------------------------------------------------
# Naming convention: YYYYMMDD-NNN-short-slug.md
# ---------------------------------------------------------------------------

TASK_BASENAME="$(basename "$TASK_FILE")"

if [[ ! "$TASK_BASENAME" =~ ^[0-9]{8}-[0-9]{3}-[a-zA-Z0-9_-]+\.md$ ]]; then
    error "filename must follow YYYYMMDD-NNN-short-slug.md format: $TASK_BASENAME"
fi

EXPECTED_TASK_ID="$(echo "$TASK_BASENAME" | grep -oE '^[0-9]{8}-[0-9]{3}')"
EXPECTED_OUTPUT_BASENAME="${TASK_BASENAME%.md}-result.md"

# ---------------------------------------------------------------------------
# Frontmatter
# ---------------------------------------------------------------------------

FRONTMATTER="$(extract_frontmatter "$TASK_FILE")"
if [ -z "$FRONTMATTER" ]; then
    error "no YAML frontmatter found (expected --- delimited block)"
fi

command -v yq >/dev/null 2>&1 || error "yq is required but not installed"

REQUIRED_FIELDS=(from task_id requested_at output_path)
for field in "${REQUIRED_FIELDS[@]}"; do
    if ! echo "$FRONTMATTER" | grep -qE "^${field}:"; then
        error "missing required frontmatter field: $field"
    fi
done

FROM="$(echo "$FRONTMATTER" | yq -r '.from // empty')"
TASK_ID="$(echo "$FRONTMATTER" | yq -r '.task_id // empty')"
OUTPUT_PATH="$(echo "$FRONTMATTER" | yq -r '.output_path // empty')"
CONTEXT_FILES_JSON="$(echo "$FRONTMATTER" | yq -r '.context_files // []')"

# ---------------------------------------------------------------------------
# Field validation
# ---------------------------------------------------------------------------

if [ -z "$FROM" ]; then
    error "from is empty"
fi

if [ "$FROM" != "claude" ]; then
    error "from must be 'claude', got: $FROM"
fi

if [ -z "$TASK_ID" ]; then
    error "task_id is empty"
fi

if [ "$TASK_ID" != "$EXPECTED_TASK_ID" ]; then
    error "task_id ($TASK_ID) does not match filename prefix ($EXPECTED_TASK_ID)"
fi

if [ -z "$OUTPUT_PATH" ]; then
    error "output_path is empty"
fi

OUTPUT_ABS="$(cd "$PROJECT_ROOT" && realpath -m "$OUTPUT_PATH")"
DELEGATIONS_DIR="$(realpath -m "$PROJECT_ROOT/.kimi/delegations")"

if [[ ! "$OUTPUT_ABS" == "$DELEGATIONS_DIR"* ]]; then
    error "output_path must be inside .kimi/delegations/" \
        "  output_path: $OUTPUT_PATH" \
        "  resolved:    $OUTPUT_ABS"
fi

OUTPUT_BASENAME="$(basename "$OUTPUT_PATH")"
if [ "$OUTPUT_BASENAME" != "$EXPECTED_OUTPUT_BASENAME" ]; then
    error "output_path basename should be $EXPECTED_OUTPUT_BASENAME, got: $OUTPUT_BASENAME"
fi

# ---------------------------------------------------------------------------
# context_files
# ---------------------------------------------------------------------------

if [ -n "$CONTEXT_FILES_JSON" ] && [ "$CONTEXT_FILES_JSON" != "[]" ]; then
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        CONTEXT_FILE_ABS="$(cd "$PROJECT_ROOT" && realpath -m "$line")"
        if [ ! -f "$CONTEXT_FILE_ABS" ]; then
            error "context_file not found: $line"
        fi
        if [[ ! "$CONTEXT_FILE_ABS" == "$PROJECT_ROOT"* ]]; then
            error "context_file must be inside project root: $line"
        fi
    done < <(echo "$CONTEXT_FILES_JSON" | yq -r '.[]')
fi

# ---------------------------------------------------------------------------
# Success
# ---------------------------------------------------------------------------

echo "Valid: $TASK_FILE"
echo "  task_id:    $TASK_ID"
echo "  output:     $OUTPUT_PATH"
exit 0
