# Setup Guide

## Manual Installation

If you prefer not to use the install script, set up the bridge manually:

### 1. Bridge Script

Copy `scripts/kimi-delegate.sh` to your project's `scripts/kimi-delegate.sh`:

```bash
mkdir -p scripts
cp /path/to/claude-kimi-delegate/scripts/kimi-delegate.sh scripts/
chmod +x scripts/kimi-delegate.sh
```

### 2. Kimi Skill

Copy the Kimi skill into your project's `.kimi/skills/` directory:

```bash
mkdir -p .kimi/skills/claude-delegate/references
cp /path/to/claude-kimi-delegate/kimiskill/SKILL.md .kimi/skills/claude-delegate/
cp /path/to/claude-kimi-delegate/kimiskill/references/delegation-format.md .kimi/skills/claude-delegate/references/
```

### 3. Task File Template

Create the delegations directory and copy the template:

```bash
mkdir -p .kimi/delegations
cp /path/to/claude-kimi-delegate/assets/task-template.md .kimi/delegations/TEMPLATE.md
touch .kimi/delegations/.gitkeep
```

### 4. Git Ignore

Add to your project's `.gitignore`:

```gitignore
# Delegation bridge artifacts (keep directory and template, ignore runtime files)
.kimi/delegations/*.md
.kimi/delegations/.*.log
.kimi/delegations/*.stale.*
!.kimi/delegations/TEMPLATE.md
!.kimi/delegations/.gitkeep
```

### 5. Claude Instructions

Add the contents of `assets/claude-instructions.md` to your project's `CLAUDE.md` or `.claude/CLAUDE.md`.

### 6. Dependencies

Ensure these are installed and on `PATH`:

```bash
which yq      # YAML parser
which kimi    # Kimi Code CLI
which timeout # coreutils
```

## Permissions (Claude Code)

If Claude Code asks for permission to run the bridge script, approve it or add to `.claude/settings.local.json`:

```json
{
  "permissions": {
    "allow": [
      "Bash(./scripts/kimi-delegate.sh *)"
    ]
  }
}
```

## Verification

Test the setup:

```bash
# Validate a task file
./scripts/validate-delegation.sh .kimi/delegations/TEMPLATE.md

# Run a real delegation (requires kimi CLI)
./scripts/kimi-delegate.sh .kimi/delegations/20260429-001-your-task.md
```
