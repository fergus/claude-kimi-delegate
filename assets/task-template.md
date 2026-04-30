# Task File Template

Copy this file when creating a new delegation from Claude to Kimi.
Name it: `.kimi/delegations/YYYYMMDD-NNN-short-slug.md`

- `YYYYMMDD` — today's date
- `NNN` — sequential daily counter (001, 002, ...)
- `short-slug` — brief task descriptor

---
from: claude
task_id: "YYYYMMDD-NNN"
requested_at: "YYYY-MM-DDTHH:MM:SSZ"
output_path: ".kimi/delegations/YYYYMMDD-NNN-short-slug-result.md"
skill: ""           # optional: target a specific Kimi skill (e.g., "ce-plan", "ce-debug")
context_files: []   # optional: list of repo-relative paths for Kimi to read
---

# Task

[Clear, specific description of what Kimi should do. One concern per delegation.]

Example: "Plan the database schema for user preferences. Include tables for dietary requirements, allergies, and household size. Use SQLite for the MVP."

# Context

[Relevant background that helps Kimi understand the task.]

- Current state: [what exists now]
- Constraints: [technical or business constraints]
- Related files: [repo-relative paths]

# Expected Output

[What the result should contain or look like.]

Example: "A markdown plan with table definitions, column types, indexes, and migration order."
