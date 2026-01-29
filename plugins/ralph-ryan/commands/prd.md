---
description: "Create a new PRD for Ralph autonomous execution"
argument-hint: "[feature description]"
allowed-tools: [Read, Write, Glob, Grep, Bash, AskUserQuestion]
---

# Ralph PRD Command

Create a Product Requirements Document for autonomous development.

## Arguments

The user invoked this command with: $ARGUMENTS

## Instructions

1. Read the skill instruction file at `skills/ralph-ryan/prd.md`
2. Follow the PRD generation instructions with the user's feature description

## Usage Examples

```bash
# Create PRD with description
/ralph-ryan:prd Add user authentication with JWT

# Create PRD (will prompt for description)
/ralph-ryan:prd
```
