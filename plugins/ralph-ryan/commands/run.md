---
description: "Execute Ralph loop to implement PRD stories"
argument-hint: "[prd-slug] [--max-iterations N]"
allowed-tools: [Read, Write, Glob, Grep, Bash, AskUserQuestion]
---

# Ralph Run Command

Execute the Ralph autonomous loop to implement user stories.

## Arguments

The user invoked this command with: $ARGUMENTS

Parse arguments:
- `[prd-slug]` - Optional PRD to execute (will list and prompt if not provided)
- `--max-iterations N` - Maximum iterations before stopping (default: unlimited)

## Instructions

1. Read the skill instruction file at `skills/ralph-ryan/run.md`
2. Follow the execution instructions

## Usage Examples

```bash
# Auto-select PRD if only one, run until complete
/ralph-ryan:run

# Execute specific PRD
/ralph-ryan:run prd-06-risk-management

# Execute with iteration limit
/ralph-ryan:run prd-06-risk-management --max-iterations 10

# Just limit iterations (auto-select PRD)
/ralph-ryan:run --max-iterations 5
```

To stop a running loop: press Ctrl+C.
