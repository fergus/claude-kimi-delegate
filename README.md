# Claude ↔ Kimi Delegation Bridge

A production-ready Claude Code skill that enables seamless handoff from Claude Code to Kimi Code CLI. One task file in, one structured result out. No terminal switching, no context loss.

## What It Does

When you're working in Claude Code and want Kimi's take on a task — planning, debugging, research, or anything where Kimi's skills add value — this bridge handles the entire round-trip:

1. **Claude writes a task file** with YAML frontmatter and clear instructions
2. **The bridge script invokes Kimi** non-interactively (`kimi --afk --yolo`)
3. **Kimi produces a structured result** written to a predictable file path
4. **Claude reads the result** and summarizes it for you

## Quick Start

### Prerequisites

- `kimi` CLI installed and on `PATH`
- `yq` installed and on `PATH`
- `timeout` (coreutils) installed and on `PATH`

### Installation

From within any project where you want to use the bridge:

```bash
# Clone the skill repo (or install via marketplace)
git clone https://github.com/YOUR_USERNAME/claude-kimi-delegate.git /tmp/claude-kimi-delegate

# Run the install script
cd your-project
bash /tmp/claude-kimi-delegate/scripts/install.sh
```

Or let Claude do it — the skill includes auto-setup detection.

### Usage

Just say:

> "Kimi, plan the authentication flow."

Claude will:
1. Create `.kimi/delegations/YYYYMMDD-NNN-short-slug.md`
2. Run `./scripts/kimi-delegate.sh .kimi/delegations/YYYYMMDD-NNN-short-slug.md`
3. Read the result and present it to you

## Project Structure

```
claude-kimi-delegate/
├── SKILL.md                          # Claude Code skill (main artifact)
├── plugin.json                       # Marketplace plugin manifest
├── scripts/
│   ├── install.sh                    # One-command setup for target projects
│   └── kimi-delegate.sh              # The bridge script
├── assets/
│   ├── task-template.md              # Task file template
│   └── claude-instructions.md        # Snippet for project's CLAUDE.md
├── references/
│   └── setup-guide.md                # Detailed installation guide
└── kimiskill/                        # Kimi-side skill
    ├── SKILL.md
    └── references/
        └── delegation-format.md
```

## Naming Convention

All delegation files follow `YYYYMMDD-NNN-short-slug`:

- `YYYYMMDD` — today's date
- `NNN` — sequential daily counter (001, 002, ...)
- `short-slug` — brief task descriptor

Examples:
- Task: `20260429-001-plan-onboarding.md`
- Result: `20260429-001-plan-onboarding-result.md`
- Log: `.20260429-001-plan-onboarding.log`

## Validation

The install script validates your environment. You can also run the standalone validator:

```bash
./scripts/validate-delegation.sh .kimi/delegations/20260429-001-plan-onboarding.md
```

## License

MIT
