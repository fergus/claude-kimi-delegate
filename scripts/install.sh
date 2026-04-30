#!/usr/bin/env bash
#
# Claude ↔ Kimi Delegation Bridge — Install Script
# Usage: bash /path/to/claude-kimi-delegate/scripts/install.sh
#
# Scaffolds the delegation bridge into the current project.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(pwd)"

echo "Installing Claude ↔ Kimi Delegation Bridge into: $PROJECT_ROOT"

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------

echo "Checking dependencies..."

MISSING=()

command -v yq >/dev/null 2>&1 || MISSING+=("yq")
command -v kimi >/dev/null 2>&1 || MISSING+=("kimi")
command -v timeout >/dev/null 2>&1 || MISSING+=("timeout")

if [ ${#MISSING[@]} -gt 0 ]; then
    echo "Warning: The following dependencies are missing: ${MISSING[*]}"
    echo "The bridge will not work until they are installed and on PATH."
fi

# ---------------------------------------------------------------------------
# Bridge script
# ---------------------------------------------------------------------------

echo "Installing bridge script..."
mkdir -p "$PROJECT_ROOT/scripts"
cp "$SKILL_ROOT/scripts/kimi-delegate.sh" "$PROJECT_ROOT/scripts/kimi-delegate.sh"
chmod +x "$PROJECT_ROOT/scripts/kimi-delegate.sh"
cp "$SKILL_ROOT/scripts/validate-delegation.sh" "$PROJECT_ROOT/scripts/validate-delegation.sh"
chmod +x "$PROJECT_ROOT/scripts/validate-delegation.sh"

# ---------------------------------------------------------------------------
# Kimi skill
# ---------------------------------------------------------------------------

echo "Installing Kimi skill..."
mkdir -p "$PROJECT_ROOT/.kimi/skills/claude-delegate/references"
cp "$SKILL_ROOT/kimiskill/SKILL.md" "$PROJECT_ROOT/.kimi/skills/claude-delegate/SKILL.md"
cp "$SKILL_ROOT/kimiskill/references/delegation-format.md" "$PROJECT_ROOT/.kimi/skills/claude-delegate/references/delegation-format.md"

# ---------------------------------------------------------------------------
# Task template and delegations directory
# ---------------------------------------------------------------------------

echo "Installing task template..."
mkdir -p "$PROJECT_ROOT/.kimi/delegations"
cp "$SKILL_ROOT/assets/task-template.md" "$PROJECT_ROOT/.kimi/delegations/TEMPLATE.md"
touch "$PROJECT_ROOT/.kimi/delegations/.gitkeep"

# ---------------------------------------------------------------------------
# Git ignore
# ---------------------------------------------------------------------------

echo "Updating .gitignore..."
GITIGNORE="$PROJECT_ROOT/.gitignore"
IGNORE_BLOCK="# Delegation bridge artifacts (keep directory and template, ignore runtime files)
.kimi/delegations/*.md
.kimi/delegations/.*.log
.kimi/delegations/*.stale.*
!.kimi/delegations/TEMPLATE.md
!.kimi/delegations/.gitkeep"

if [ -f "$GITIGNORE" ]; then
    if ! grep -qF "Delegation bridge artifacts" "$GITIGNORE"; then
        echo "" >> "$GITIGNORE"
        echo "$IGNORE_BLOCK" >> "$GITIGNORE"
    else
        echo ".gitignore already contains delegation bridge rules. Skipping."
    fi
else
    echo "$IGNORE_BLOCK" > "$GITIGNORE"
fi

# ---------------------------------------------------------------------------
# Claude instructions
# ---------------------------------------------------------------------------

echo "Installing Claude instructions..."

CLAUDE_FILE=""
if [ -f "$PROJECT_ROOT/.claude/CLAUDE.md" ]; then
    CLAUDE_FILE="$PROJECT_ROOT/.claude/CLAUDE.md"
elif [ -f "$PROJECT_ROOT/CLAUDE.md" ]; then
    CLAUDE_FILE="$PROJECT_ROOT/CLAUDE.md"
fi

INSTRUCTIONS_MARKER="<!-- claude-kimi-delegate instructions -->"

if [ -n "$CLAUDE_FILE" ]; then
    if ! grep -qF "$INSTRUCTIONS_MARKER" "$CLAUDE_FILE"; then
        echo "" >> "$CLAUDE_FILE"
        echo "$INSTRUCTIONS_MARKER" >> "$CLAUDE_FILE"
        cat "$SKILL_ROOT/assets/claude-instructions.md" >> "$CLAUDE_FILE"
        echo "<!-- /claude-kimi-delegate instructions -->" >> "$CLAUDE_FILE"
    else
        echo "Claude instructions already present. Skipping."
    fi
else
    mkdir -p "$PROJECT_ROOT/.claude"
    echo "$INSTRUCTIONS_MARKER" > "$PROJECT_ROOT/.claude/CLAUDE.md"
    cat "$SKILL_ROOT/assets/claude-instructions.md" >> "$PROJECT_ROOT/.claude/CLAUDE.md"
    echo "<!-- /claude-kimi-delegate instructions -->" >> "$PROJECT_ROOT/.claude/CLAUDE.md"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

echo ""
echo "Installation complete."
echo ""
echo "Files installed:"
echo "  scripts/kimi-delegate.sh"
echo "  scripts/validate-delegation.sh"
echo "  .kimi/skills/claude-delegate/SKILL.md"
echo "  .kimi/delegations/TEMPLATE.md"
echo ""

if [ ${#MISSING[@]} -gt 0 ]; then
    echo "Please install missing dependencies: ${MISSING[*]}"
    exit 1
fi

echo "Ready to delegate. Try saying: 'Kimi, plan the onboarding flow.'"
