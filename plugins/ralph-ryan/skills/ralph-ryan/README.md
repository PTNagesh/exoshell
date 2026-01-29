# Ralph Ryan

Autonomous AI agent that implements features iteratively through PRD-driven development with **multi-PRD parallel support**.

Based on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/) and [Ryan Carson's implementation](https://x.com/ryancarson/status/2008548371712135632).

## Overview

Ralph is an autonomous loop that runs Claude Code repeatedly until all PRD items are complete. Each iteration is a fresh instance with clean context. Memory persists via git history, `progress.txt`, and `prd.json`.

**Key Features:**
- Multi-PRD parallel development support
- Built-in loop execution (no external dependencies)
- Session-based isolation to prevent conflicts
- File tracking for precise commits

## Workflow

```bash
# Check status of all PRDs
/ralph-ryan:status

# Create a new PRD (will ask for slug name)
/ralph-ryan:prd [describe your feature]

# Prepare a PRD for execution (will list available PRDs)
/ralph-ryan:prep

# Execute stories in a loop
/ralph-ryan:run [prd-slug] [--max-iterations N]
```

To stop a running loop: press Ctrl+C.

## Directory Structure (Multi-PRD)

```
.claude/ralph-ryan/
├── prd-06-risk-management/          # PRD subdirectory
│   ├── prd.md                       # Human-readable PRD
│   ├── prd.json                     # Machine-readable stories
│   ├── progress.txt                 # Learnings for future iterations
│   └── ralph-loop.local.md          # Loop state (when running)
├── prd-07-model-governance/
│   └── ...
└── ...

.claude/ralph-ryan-archived/
└── 2026-01-29-prd-05-market-data/   # Archived after completion
```

## Commands

### 1. Check Status

```bash
/ralph-ryan:status
```

Shows overview of all PRDs:
- Progress (X/Y stories done)
- Lock status
- Conflict warnings
- Next story to execute

### 2. Generate PRD

```bash
/ralph-ryan:prd Add a task priority system with filtering
```

Creates `.claude/ralph-ryan/<prd-slug>/prd.md` with:
- Clarifying questions (lettered options)
- User stories sized for single iterations
- Verifiable acceptance criteria

### 3. Prepare for Execution

```bash
/ralph-ryan:prep
```

- Lists available PRDs
- Converts selected `prd.md` → `prd.json`
- Initializes `progress.txt`

### 4. Execute

```bash
# Execute with auto-select (if only one PRD)
/ralph-ryan:run

# Execute specific PRD
/ralph-ryan:run prd-06-risk-management

# With iteration limit
/ralph-ryan:run prd-06-risk-management --max-iterations 10
```

Ralph will:
1. Initialize loop state for the selected PRD
2. Read prd.json and progress.txt
3. Pick highest priority story where `passes: false`
4. Implement that single story
5. Track files changed
6. Run quality checks
7. Commit only related files
8. Update prd.json to mark story complete
9. Append learnings to progress.txt
10. Repeat until all stories pass (loop continues automatically)

To stop: press Ctrl+C.

## Multi-PRD Parallel Development

You can run multiple PRDs simultaneously in different terminals:

```bash
# Terminal 1: Execute PRD-06
/ralph-ryan:run prd-06-risk-management --max-iterations 10

# Terminal 2: Execute PRD-07
/ralph-ryan:run prd-07-model-governance --max-iterations 10
```

### Session Isolation

Each loop state file (`ralph-loop.local.md`) contains a `session_hash` field. The Stop Hook automatically fills this with a SHA256 hash of the current session's transcript path on first iteration. This ensures:
- Only the session that started the loop will continue it
- Other sessions won't interfere with running loops
- Privacy: no full paths are stored, only a 16-char hash
- If a different session tries to exit with an active loop, it will be prompted to choose: exit or take over

### File Tracking

Each story records modified files:

```json
{
  "id": "US-003",
  "passes": true,
  "filesChanged": [
    "app/risk/greeks/page.tsx",
    "components/charts/greeks-heatmap.tsx"
  ]
}
```

Benefits:
- Precise commits (only related files)
- Conflict detection across PRDs

### Conflict Detection

When multiple PRDs modify the same file, you'll see a warning:

```
⚠️ Potential conflict detected!

File: components/charts/heatmap.tsx
- Modified by: prd-06-risk-management (US-002)
- Also tracked by: prd-07-model-governance (US-003)
```

## Key Concepts

### Each Iteration = Fresh Context

Each iteration spawns a **new instance** with clean context. Memory persists only via:
- Git history (commits from previous iterations)
- `progress.txt` (learnings and patterns)
- `prd.json` (which stories are done)

### Small Tasks

Each story must complete in **one context window**. If too big, the LLM runs out of context and produces poor code.

**Right-sized:**
- Add a database column and migration
- Add a UI component to existing page
- Update a server action

**Too big (split these):**
- "Build entire dashboard"
- "Add authentication"

### Stop Condition

When all stories have `passes: true`, Ralph outputs `<promise>COMPLETE</promise>` and the loop exits.

## Debugging

```bash
# See status of all PRDs
/ralph-ryan:status

# See which stories are done in a specific PRD
cat .claude/ralph-ryan/prd-06-risk-management/prd.json | jq '.userStories[] | {id, title, passes}'

# See learnings from previous iterations
cat .claude/ralph-ryan/prd-06-risk-management/progress.txt

# Check git history
git log --oneline -10

# Check active loops
ls -la .claude/ralph-ryan/*/ralph-loop.local.md
```

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | Entry point with routing logic |
| `prd.md` | PRD generation instructions |
| `prep.md` | Preparation/conversion instructions |
| `run.md` | Execution instructions |
| `status.md` | Status overview instructions |
