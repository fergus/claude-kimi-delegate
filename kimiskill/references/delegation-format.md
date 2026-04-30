# Delegation Format Reference

Complete specification of the task file schema and result file conventions used by the Claude ↔ Kimi delegation bridge.

## Task File Schema

Task files are markdown with YAML frontmatter.

### Required Frontmatter Fields

| Field | Type | Description |
|---|---|---|
| `from` | string | Always `"claude"`. Identifies the sender. |
| `task_id` | string | Unique identifier. Format: `YYYYMMDD-NNN` or any unique string. |
| `requested_at` | string | ISO 8601 timestamp. |
| `output_path` | string | Repo-relative path where Kimi must write the result. Must be inside `.kimi/delegations/`. |

### Optional Frontmatter Fields

| Field | Type | Description |
|---|---|---|
| `skill` | string | Name of a Kimi skill to load before executing (e.g., `ce-plan`, `ce-debug`). Empty string or omitted = no sub-skill. |
| `context_files` | list of strings | Repo-relative paths to files Kimi should read for context. |

### Body Sections

```markdown
# Task

[Clear, specific description of what to do.]

# Context

[Background, constraints, related files.]

# Expected Output

[What the result should contain or look like.]
```

## Result File Conventions

Kimi writes the result to the `output_path` declared in the task file.

### Required Structure

```markdown
# Summary

Brief description of what was done.

# Details

Main body.
```

### Optional Sections

- `# Assumptions` — List any assumptions made due to vague input
- `# Blocker` — If the task is impossible, write the reason here and stop

### Validation Rules

The wrapper script validates results before returning to Claude:
- File must exist
- File must be non-empty
- File must not contain refusal patterns (e.g., "I can't help with that")

## Example

### Task File

`.kimi/delegations/2026-04-29-001.md`

```markdown
---
from: claude
task_id: "2026-04-29-001"
requested_at: "2026-04-29T10:58:00Z"
output_path: ".kimi/delegations/2026-04-29-001-result.md"
skill: ""
context_files: []
---

# Task

Write a hello-world Python script.

# Context

MVP project. No existing Python files.

# Expected Output

A single `hello.py` file with a main guard.
```

### Result File

`.kimi/delegations/2026-04-29-001-result.md`

```markdown
# Summary

Created `hello.py` with a standard hello-world implementation and `if __name__ == '__main__'` guard.

# Details

```python
#!/usr/bin/env python3

def main():
    print("Hello, world!")

if __name__ == "__main__":
    main()
```

The script is executable and follows PEP 8 conventions.
```
