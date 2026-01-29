---
description: "Prepare a PRD for Ralph execution (convert prd.md to prd.json)"
argument-hint: "[prd-slug]"
allowed-tools: [Read, Write, Glob, Grep, Bash, AskUserQuestion]
---

# Ralph Prep Command

Prepare a PRD for autonomous execution by converting it to JSON format.

## Arguments

The user invoked this command with: $ARGUMENTS

If a PRD slug is provided, prepare that specific PRD. Otherwise, list available PRDs and let user select.

## Instructions

1. Read the skill instruction file at `skills/ralph-ryan/prep.md`
2. Follow the preparation instructions

## Usage Examples

```bash
# List PRDs and select interactively
/ralph-ryan:prep

# Prepare specific PRD
/ralph-ryan:prep prd-06-risk-management
```
