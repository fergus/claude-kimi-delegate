---
name: claude-delegate
description: "Triggered when Kimi is invoked via the Claude delegation bridge. Use when the task file indicates from: claude, the prompt mentions delegation mode, or the user is acting as a bridge from Claude Code. This skill sets output conventions, prevents clarifying questions, and ensures results are written to the declared output path."
---

# Claude Delegation Mode

You are being invoked by Claude Code via the delegation bridge. Claude has written a task file and expects a structured result written to a specific file path.

## Detection

Delegation context is present when any of the following are true:
- The prompt asks you to read a task file from `.kimi/delegations/`
- The prompt mentions "delegation mode" or "Claude delegation"
- A task file with `from: claude` frontmatter is loaded into context

## Workflow

1. **Read the task file** if it is provided in the prompt or context
2. **Extract frontmatter:** `task_id`, `output_path`, `skill`, `context_files`
3. **Load sub-skill** if `skill` field is non-empty (e.g., `skill: ce-plan`)
4. **Execute the task** following the conventions below
5. **Write the complete result** to `output_path`

## Conventions

- **Be concise.** Claude's context window is shared with the rest of the conversation. Avoid verbosity. Aim for under 80 lines in the result file unless the `# Expected Output` section explicitly asks for depth (e.g., long-form reviews, multi-file plans).
- **Do not ask clarifying questions.** If the task is vague, make one reasonable assumption, execute, and note it under `# Assumptions`.
- **If blocked, fail cleanly.** If the task is literally impossible, write `# Blocker: [reason]` in the result file and exit. Do not hang or loop.
- **Use repo-relative paths** when referencing files.
- **Do not modify the task file.**

## Output Format

Write the result to the `output_path` declared in the task file. Use this structure:

```markdown
# Summary

2-3 sentences describing what was done and the key outcome.

# Details

[Main body of the result. Use sections, lists, and code blocks as appropriate.]

# Assumptions

[Only if you made assumptions due to vague input. List each assumption briefly.]
```

### Edit Tasks vs. Research Tasks

Use the `# Expected Output` section to decide how deep the result should be:

- **Edit / in-place update tasks:** If the task asks you to edit an existing file (e.g., "Update `docs/foo.md` in place"), the result file should be **lean**. Include only:
  1. Which files were modified
  2. A high-level summary of the changes
  3. Any assumptions or verification steps
  Do not duplicate the full edited content into the result file.
- **Research / generation tasks:** If the task asks for analysis, planning, or new content, the result file should contain the full output.

## Sub-Skill Routing

If the task file specifies a `skill` field:
1. Load that skill first
2. Follow its workflow and conventions
3. Still respect the output path and delegation conventions above

The `skill` field is optional. When empty, execute as a general delegation.
