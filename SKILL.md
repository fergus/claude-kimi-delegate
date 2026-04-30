---
name: claude-kimi-delegate
description: "Use when the user wants to delegate a task to Kimi Code CLI. Triggered by phrases like 'Kimi, ...', 'Hand this to Kimi', or when the user explicitly asks to send work to Kimi. This skill manages the delegation bridge, task file creation, and result handling."
---

# Claude ↔ Kimi Delegation Bridge

You are the Claude-side operator of the Claude ↔ Kimi Delegation Bridge. Your job is to hand off specific tasks to Kimi Code CLI and return structured results to the user.

## Detection

Load this skill when any of the following are true:
- The user says **"Kimi, ..."** (e.g., "Kimi, plan this feature")
- The user says **"Hand this to Kimi"** or **"Send this to Kimi"**
- The user explicitly asks to delegate, run, or pass a task to Kimi

## Setup Check

Before delegating, verify the bridge is installed in the current project:

1. Check if `./scripts/kimi-delegate.sh` exists
2. Check if `.kimi/skills/claude-delegate/SKILL.md` exists
3. Check if `.kimi/delegations/TEMPLATE.md` exists

If any are missing, **run the setup** first:
```bash
bash /path/to/claude-kimi-delegate/scripts/install.sh
```

Or, if the skill repo is not locally cloned, guide the user to clone it and run the install script.

## Prerequisites

Ensure these are on PATH before delegating:
- `yq` — YAML parser
- `kimi` — Kimi Code CLI
- `timeout` — coreutils

## Delegation Workflow

### Step 1: Create a Task File

Create a file in `.kimi/delegations/` named:
```
YYYYMMDD-NNN-short-slug.md
```

- `YYYYMMDD` — today's date
- `NNN` — sequential daily counter (001, 002, ...)
- `short-slug` — brief descriptor

Use `.kimi/delegations/TEMPLATE.md` as the starting point.

### Step 2: Fill Frontmatter

```yaml
---
from: claude
task_id: "YYYYMMDD-NNN"
requested_at: "YYYY-MM-DDTHH:MM:SSZ"
output_path: ".kimi/delegations/YYYYMMDD-NNN-short-slug-result.md"
skill: ""           # optional: target a specific Kimi skill (e.g., "ce-plan", "ce-debug")
context_files: []   # optional: repo-relative paths for Kimi to read
---
```

Rules:
- `output_path` must be inside `.kimi/delegations/` and end in `-result.md`
- `task_id` must match the `YYYYMMDD-NNN` prefix of the filename
- `skill` is optional; leave empty for general delegation
- `context_files` is optional; list repo-relative paths for Kimi to read

### Step 3: Write Clear Sections

```markdown
# Task

One clear, specific request. One concern per delegation.

# Context

Background, constraints, related files, current state.

# Expected Output

What the result should contain or look like.
```

### Step 4: Validate (Optional but Recommended)

```bash
./scripts/validate-delegation.sh .kimi/delegations/YYYYMMDD-NNN-short-slug.md
```

### Step 5: Run the Bridge

```bash
./scripts/kimi-delegate.sh .kimi/delegations/YYYYMMDD-NNN-short-slug.md
```

### Step 6: Handle the Result

**If the script exits 0:**
- Read the result file (path printed to stdout)
- Summarize the key findings for the user
- Incorporate the result into your ongoing work

**If the script exits non-zero:**
- Read the diagnostic error
- Do not silently retry
- Report the error to the user and suggest refining the task

## Conventions

- **Only delegate where Kimi adds clear value**: planning, debugging, research, code review. Do not delegate trivial inline tasks.
- **One concern per delegation**: keep task files focused.
- **Be specific in `# Expected Output`**: this drives whether Kimi writes a lean edit summary or a full research result.
- **Clean up old files**: delegation files older than a few days can be removed unless the user wants to keep them.

## Example

User: "Kimi, plan the authentication flow."

You:
1. Create `.kimi/delegations/20260429-002-auth-flow.md`
2. Fill frontmatter with `output_path: .kimi/delegations/20260429-002-auth-flow-result.md` and `skill: ce-plan`
3. Write `# Task: Plan the authentication flow for the MVP...`
4. Run `./scripts/kimi-delegate.sh .kimi/delegations/20260429-002-auth-flow.md`
5. Read result, summarize: "Kimi produced a 3-phase plan using OAuth2 + session tokens..."
