#!/usr/bin/env bash
#
# Claude ↔ Kimi Delegation Bridge
# Usage: ./scripts/kimi-delegate.sh <task-file>
#
# Reads a task file, invokes Kimi in non-interactive mode, validates the result,
# and prints the result file path on success.

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

error() {
    echo "Error: $1" >&2
    shift
    while [ $# -gt 0 ]; do
        echo "$1" >&2
        shift
    done
    exit 1
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

# --help
if [ $# -eq 0 ] || [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    cat <<EOF
Usage: $0 <task-file>

Delegates a task from Claude Code to Kimi Code CLI.

Arguments:
  <task-file>   Path to a markdown task file with YAML frontmatter.
                See .kimi/delegations/TEMPLATE.md for the schema.

Environment:
  The script requires 'yq' and 'kimi' to be installed and on PATH.

Example:
  $0 .kimi/delegations/2026-04-29-001.md
EOF
    exit 0
fi

TASK_FILE="$1"

# ---------------------------------------------------------------------------
# Dependency Checks
# ---------------------------------------------------------------------------

command -v yq >/dev/null 2>&1 || error "yq is required but not installed"
command -v kimi >/dev/null 2>&1 || error "kimi CLI is required but not installed"
command -v timeout >/dev/null 2>&1 || error "timeout (coreutils) is required but not installed"

# ---------------------------------------------------------------------------
# Input Validation
# ---------------------------------------------------------------------------

# Task file must exist and be non-empty
[ -f "$TASK_FILE" ] || error "task file not found: $TASK_FILE"
[ -s "$TASK_FILE" ] || error "task file is empty: $TASK_FILE"

# Task file must be inside project root
TASK_ABS="$(realpath "$TASK_FILE")"
[[ "$TASK_ABS" == "$PROJECT_ROOT"* ]] || error \
    "task file must be inside project root" \
    "  project root: $PROJECT_ROOT" \
    "  task file:    $TASK_ABS"

# Validate filename convention: YYYYMMDD-NNN-short-slug.md
TASK_BASENAME="$(basename "$TASK_FILE")"
if [[ ! "$TASK_BASENAME" =~ ^[0-9]{8}-[0-9]{3}-[a-zA-Z0-9_-]+\.md$ ]]; then
    error "task file name must follow YYYYMMDD-NNN-short-slug.md format: $TASK_BASENAME"
fi
EXPECTED_TASK_ID="$(echo "$TASK_BASENAME" | grep -oE '^[0-9]{8}-[0-9]{3}')"
EXPECTED_OUTPUT_BASENAME="${TASK_BASENAME%.md}-result.md"

# Extract and validate frontmatter
FRONTMATTER="$(extract_frontmatter "$TASK_FILE")"
[ -n "$FRONTMATTER" ] || error "no YAML frontmatter found in task file (expected --- delimited block)"

# Required fields
REQUIRED_FIELDS=(from task_id requested_at output_path)
for field in "${REQUIRED_FIELDS[@]}"; do
    if ! echo "$FRONTMATTER" | grep -qE "^${field}:"; then
        error "missing required frontmatter field: $field"
    fi
done

# Parse fields with yq
OUTPUT_PATH="$(echo "$FRONTMATTER" | yq -r '.output_path // empty')"
TASK_ID="$(echo "$FRONTMATTER" | yq -r '.task_id // empty')"
SKILL="$(echo "$FRONTMATTER" | yq -r '.skill // empty')"
FROM="$(echo "$FRONTMATTER" | yq -r '.from // empty')"

[ -n "$FROM" ] || error "from is empty"
[ "$FROM" == "claude" ] || error "from must be 'claude', got: $FROM"

[ -n "$OUTPUT_PATH" ] || error "output_path is empty"
[ -n "$TASK_ID" ]     || error "task_id is empty"

# Validate task_id matches filename prefix
[ "$TASK_ID" == "$EXPECTED_TASK_ID" ] || error "task_id ($TASK_ID) does not match filename prefix ($EXPECTED_TASK_ID)"

# Validate output_path basename matches convention
OUTPUT_BASENAME="$(basename "$OUTPUT_PATH")"
[ "$OUTPUT_BASENAME" == "$EXPECTED_OUTPUT_BASENAME" ] || error "output_path basename should be $EXPECTED_OUTPUT_BASENAME, got: $OUTPUT_BASENAME"

# output_path must resolve inside .kimi/delegations/
OUTPUT_ABS="$(cd "$PROJECT_ROOT" && realpath -m "$OUTPUT_PATH")"
DELEGATIONS_DIR="$(realpath -m "$PROJECT_ROOT/.kimi/delegations")"

[[ "$OUTPUT_ABS" == "$DELEGATIONS_DIR"* ]] || error \
    "output_path must be inside .kimi/delegations/" \
    "  output_path: $OUTPUT_PATH" \
    "  resolved:    $OUTPUT_ABS"

# Validate context_files if present
CONTEXT_FILES_JSON="$(echo "$FRONTMATTER" | yq -r '.context_files // []')"
CONTEXT_FILES=()
if [ -n "$CONTEXT_FILES_JSON" ] && [ "$CONTEXT_FILES_JSON" != "[]" ]; then
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        CONTEXT_FILE_ABS="$(cd "$PROJECT_ROOT" && realpath -m "$line")"
        [ -f "$CONTEXT_FILE_ABS" ] || error "context_file not found: $line"
        [[ "$CONTEXT_FILE_ABS" == "$PROJECT_ROOT"* ]] || error "context_file must be inside project root: $line"
        CONTEXT_FILES+=("$line")
    done < <(echo "$CONTEXT_FILES_JSON" | yq -r '.[]')
fi

# Ensure parent directory exists
mkdir -p "$(dirname "$OUTPUT_ABS")"

# ---------------------------------------------------------------------------
# Build Delegation Prompt
# ---------------------------------------------------------------------------

TASK_REL="${TASK_ABS#$PROJECT_ROOT/}"

read -r -d '' DELEGATION_PROMPT <<EOF || true
You are in Claude delegation mode.

Please read the task file at: ${TASK_REL}

Follow the claude-delegate skill conventions:
- Be concise. Claude's context window is shared.
- Do not ask clarifying questions. If vague, make one reasonable assumption, note it, and proceed.
- Write the complete result to: ${OUTPUT_PATH}
- Include a # Summary section at the top of the result.
- Use repo-relative paths when referencing files.
- Do not modify the task file.
EOF

if [ ${#CONTEXT_FILES[@]} -gt 0 ]; then
    read -r -d '' CONTEXT_BLOCK <<EOF || true

Read these context files before executing the task:
EOF
    for cf in "${CONTEXT_FILES[@]}"; do
        CONTEXT_BLOCK="${CONTEXT_BLOCK}\n- ${cf}"
    done
    DELEGATION_PROMPT="${DELEGATION_PROMPT}${CONTEXT_BLOCK}"
fi

if [ -n "$SKILL" ]; then
    read -r -d '' SKILL_BLOCK <<EOF || true

Also load the '${SKILL}' skill and follow its workflow before executing the task.
EOF
    DELEGATION_PROMPT="${DELEGATION_PROMPT}${SKILL_BLOCK}"
fi

# ---------------------------------------------------------------------------
# Invoke Kimi
# ---------------------------------------------------------------------------

TASK_BASENAME="$(basename "$TASK_FILE" .md)"
LOG_FILE="$DELEGATIONS_DIR/.${TASK_BASENAME}.log"

# Rename any stale result file so we can recover it if Kimi times out
if [ -f "$OUTPUT_ABS" ]; then
    STALE_FILE="${OUTPUT_ABS}.stale.$(date +%s)"
    mv "$OUTPUT_ABS" "$STALE_FILE"
fi

# Clean up old logs, task files, and result files (7+ days) — best-effort, ignore errors
find "$DELEGATIONS_DIR" -maxdepth 1 -name '.*.log' -mtime +7 -delete 2>/dev/null || true
find "$DELEGATIONS_DIR" -maxdepth 1 -name '*.md' -mtime +7 ! -name 'TEMPLATE.md' ! -name '.gitkeep' -delete 2>/dev/null || true
find "$DELEGATIONS_DIR" -maxdepth 1 -name '*.stale.*' -mtime +7 -delete 2>/dev/null || true

echo "Delegating to Kimi... task_id=$TASK_ID" >&2

set +e
timeout 600 kimi --afk --yolo -w "$PROJECT_ROOT" -p "$DELEGATION_PROMPT" > "$LOG_FILE" 2>&1
KIMI_EXIT=$?
set -e

if [ "$KIMI_EXIT" -eq 124 ]; then
    TIMEOUT_MSG=(
        "Kimi timed out after 600 seconds"
        "Task may be too large or Kimi may have stalled."
    )
    if [ -f "$OUTPUT_ABS" ] && [ -s "$OUTPUT_ABS" ]; then
        TIMEOUT_MSG+=("Partial result was salvaged at: $OUTPUT_PATH")
    elif [ -n "${STALE_FILE:-}" ] && [ -f "$STALE_FILE" ]; then
        TIMEOUT_MSG+=("No partial result was written, but the previous result is available at: $STALE_FILE")
    fi
    TIMEOUT_MSG+=("Last 50 lines of log ($LOG_FILE):" "$(tail -n 50 "$LOG_FILE")")
    error "${TIMEOUT_MSG[@]}"
fi

# ---------------------------------------------------------------------------
# Output Validation
# ---------------------------------------------------------------------------

if [ ! -f "$OUTPUT_ABS" ]; then
    error \
        "Kimi did not produce result file at $OUTPUT_PATH" \
        "Kimi exit code: $KIMI_EXIT" \
        "Last 50 lines of log ($LOG_FILE):" \
        "$(tail -n 50 "$LOG_FILE")"
fi

if [ ! -s "$OUTPUT_ABS" ]; then
    error \
        "result file is empty: $OUTPUT_PATH" \
        "Kimi exit code: $KIMI_EXIT" \
        "Last 50 lines of log ($LOG_FILE):" \
        "$(tail -n 50 "$LOG_FILE")"
fi

# Refusal detection — conservative patterns
REFUSAL_PATTERNS=(
    "I can't help with that"
    "I cannot help"
    "I'm unable to"
    "I don't have enough information"
    "I am not able to"
)
for pattern in "${REFUSAL_PATTERNS[@]}"; do
    if grep -qiF "$pattern" "$OUTPUT_ABS"; then
        error \
            "refusal detected in result file: $OUTPUT_PATH" \
            "Matched pattern: '$pattern'" \
            "Kimi exit code: $KIMI_EXIT" \
            "Last 50 lines of log ($LOG_FILE):" \
            "$(tail -n 50 "$LOG_FILE")"
    fi
done

# Structural validation
if ! grep -qE '^# Summary' "$OUTPUT_ABS"; then
    error \
        "result file missing required # Summary section: $OUTPUT_PATH" \
        "Kimi exit code: $KIMI_EXIT" \
        "Last 50 lines of log ($LOG_FILE):" \
        "$(tail -n 50 "$LOG_FILE")"
fi

# ---------------------------------------------------------------------------
# Success
# ---------------------------------------------------------------------------

echo "$OUTPUT_PATH"
exit 0
