---
description: "Ralph autonomous agent for iterative development"
argument-hint: "<mode> [args] [--max-iterations N]"
allowed-tools: [Read, Write, Glob, Grep, Bash, AskUserQuestion]
---

# Ralph Ryan Command

Execute Ralph autonomous development agent.

## Arguments

The user invoked this command with: $ARGUMENTS

## Modes

Parse the first argument to determine mode:

| Mode | Keywords | Description |
|------|----------|-------------|
| **prd** | prd, create | Create a new PRD |
| **prep** | prep, prepare | Prepare PRD for execution |
| **run** | run, execute, go | Execute stories in a loop |
| **status** | status, list | Show PRD status overview |

## Instructions

1. Read the skill file at `skills/ralph-ryan/SKILL.md` to understand routing
2. Based on the detected mode, read the corresponding instruction file:
   - prd → `skills/ralph-ryan/prd.md`
   - prep → `skills/ralph-ryan/prep.md`
   - run → `skills/ralph-ryan/run.md`
   - status → `skills/ralph-ryan/status.md`
3. Follow the instructions with any additional arguments

## Run Mode Options

When mode is `run`:
- `[prd-slug]` - Optional PRD to execute (will prompt if not provided)
- `--max-iterations N` - Maximum iterations before stopping (default: unlimited)

## Usage Examples

```bash
# Create PRD
/ralph-ryan prd Add a task priority system with filtering

# Prepare PRD
/ralph-ryan prep

# Execute (auto-select PRD if only one)
/ralph-ryan run

# Execute specific PRD with iteration limit
/ralph-ryan run prd-06-risk-management --max-iterations 10

# Check status
/ralph-ryan status
```

To stop a running loop: press Ctrl+C.
