# Claude ↔ Kimi Delegation Bridge — Project Instructions

## When to Delegate

When the user says **"Kimi, ..."** or **"Hand this to Kimi"**, delegate the task to Kimi Code CLI via the bridge script.

Only delegate tasks where Kimi adds clear value:
- Planning (`ce-plan` workflow)
- Debugging (`ce-debug` workflow)
- Code review (`ce-code-review` workflow)
- Research or exploration
- Tasks that benefit from Kimi's specific skills

Do **not** delegate trivial tasks you can handle inline.

## How to Delegate

### 1. Create a Task File

Create a file in `.kimi/delegations/` named:
```
YYYYMMDD-NNN-short-slug.md
```

Example: `.kimi/delegations/20260429-001-plan-onboarding.md`

Use `.kimi/delegations/TEMPLATE.md` as a starting point.

### 2. Fill in Frontmatter

```yaml
---
from: claude
task_id: "20260429-001"
requested_at: "2026-04-29T10:58:00Z"
output_path: ".kimi/delegations/20260429-001-plan-onboarding-result.md"
skill: ""           # optional: ce-plan, ce-debug, etc.
context_files: []   # optional: repo-relative paths for Kimi to read
---
```

Rules:
- `output_path` must be inside `.kimi/delegations/` and end in `-result.md`
- `task_id` should be unique within the day
- `skill` is optional; leave empty for general delegation

### 3. Write Clear Sections

```markdown
# Task

One clear, specific request. One concern per delegation.

# Context

Background, constraints, related files, current state.

# Expected Output

What the result should contain.
```

### 4. Run the Bridge Script

```bash
./scripts/kimi-delegate.sh .kimi/delegations/<your-task-file>.md
```

### 5. Handle the Result

**If the script exits 0:**
- It prints the result file path
- Read the result file
- Summarize the key findings for the user
- Incorporate the result into your ongoing work

**If the script exits non-zero:**
- It prints a diagnostic error
- Do not silently retry
- Report the error to the user and suggest refining the task (more specific, different scope, etc.)

## Cleanup

Old delegation files accumulate in `.kimi/delegations/`. Clean up files older than a few days unless the user wants to keep them for reference.

## Example

User: "Kimi, plan the authentication flow."

You:
1. Create `.kimi/delegations/20260429-002-auth-flow.md`
2. Fill frontmatter with `output_path: .kimi/delegations/20260429-002-auth-flow-result.md` and `skill: ce-plan`
3. Write `# Task: Plan the authentication flow for the MVP...`
4. Run `./scripts/kimi-delegate.sh .kimi/delegations/20260429-002-auth-flow.md`
5. Read result, summarize: "Kimi produced a 3-phase plan using OAuth2 + session tokens..."
