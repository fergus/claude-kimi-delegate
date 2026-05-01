---
name: kimi
description: "Delegate a task to Kimi Code CLI. Usage: /kimi <task description>. Accepts freeform task text as an argument, or prompts if none given."
---

# /kimi — Delegate to Kimi

You are executing a one-shot delegation from Claude to Kimi Code CLI.

## Step 1: Get the task

If the user provided arguments to `/kimi`, that is the task. If they ran `/kimi` with no arguments, ask: "What should I delegate to Kimi?"

## Step 2: Check bridge setup

Verify the bridge is installed in the current project:
- `./scripts/kimi-delegate.sh` exists
- `.kimi/delegations/TEMPLATE.md` exists

If missing, run the install script first:
```bash
bash /home/fstevens/.claude/plugins/marketplaces/claude-kimi-delegate/scripts/install.sh
```

## Step 3: Create the task file

Create `.kimi/delegations/YYYYMMDD-NNN-short-slug.md` where:
- `YYYYMMDD` is today's date
- `NNN` is the next available daily counter (check existing files in `.kimi/delegations/`)
- `short-slug` is a 2-4 word kebab-case summary of the task

Frontmatter:
```yaml
---
from: claude
task_id: "YYYYMMDD-NNN"
requested_at: "YYYY-MM-DDTHH:MM:SSZ"
output_path: ".kimi/delegations/YYYYMMDD-NNN-short-slug-result.md"
skill: ""
context_files: []
---
```

Body:
```markdown
# Task

<the task, written as a clear single instruction>

# Context

<any relevant context from the current conversation or codebase>

# Expected Output

<what a good result looks like>
```

## Step 4: Run the bridge

```bash
./scripts/kimi-delegate.sh .kimi/delegations/<filename>.md
```

## Step 5: Handle the result

If exit 0: read the result file (path is printed to stdout), then summarize the key findings for the user.

If non-zero: report the error verbatim. Do not retry silently.
