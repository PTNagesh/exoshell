# Run Mode (Multi-PRD Support)

Execute Ralph to implement user stories from a selected PRD in a loop.

---

## The Job

1. **List available PRDs** with `prd.json`
2. **Ask user to select** which PRD to execute (or auto-select if only one)
3. **Initialize loop** via setup script
4. **Check/acquire lock** for selected PRD
5. Read `prd.json` and `progress.txt`
6. Check Codebase Patterns section first
7. Ensure on correct branch from `branchName`
8. Pick highest priority story where `passes: false`
9. Implement that single story
10. **Track files changed**
11. Run quality checks, commit (only related files), update PRD and progress
12. **Release lock**

---

## Step 1: List Available PRDs

Scan `.claude/ralph-ryan/` for subdirectories containing `prd.json`:

```
Available PRDs for execution:

1. prd-06-risk-management/ [READY]
   └── 2/5 stories done, no lock

2. prd-07-model-governance/ [LOCKED]
   └── 1/4 stories done, locked by agent-xyz at 10:30

Which PRD do you want to execute? (enter number or name):
```

**Auto-select:** If only one PRD has `prd.json` and is unlocked, select it automatically.

---

## Step 2: Initialize Loop

After PRD selection, execute the setup script to initialize the loop:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-ryan-loop.sh" <prd-slug> --max-iterations <n>
```

Where `<n>` is from user's `--max-iterations` argument (default: 0 for unlimited).

**Note:** The setup script creates the state file at `.claude/ralph-ryan/<prd-slug>/ralph-loop.local.md`. The Stop Hook will detect this and continue the loop after each iteration.

---

## Step 3: Lock Acquisition

Before starting work, create/check lock file:

```json
// .claude/ralph-ryan/<prd-slug>/lock.json
{
  "lockedBy": "session-<random-id>",
  "lockedAt": "2026-01-29T10:30:00Z",
  "storyId": "US-003"
}
```

**Lock rules:**
- If no lock exists → create lock
- If lock exists and < 30 minutes old → STOP, ask user
- If lock exists and > 30 minutes old → warn and override (stale lock)

---

## Step 4: Conflict Detection

Before implementing, check if any files this PRD might touch are also tracked by other PRDs:

```bash
# Check filesChanged across all prd.json files
```

If overlap detected, warn user:

```
⚠️ Potential conflict detected!

File: components/charts/greeks-heatmap.tsx
- Modified by: prd-06-risk-management (US-002)
- Also tracked by: prd-05-market-data (US-004)

Proceed anyway? (y/n)
```

---

## Branch Setup

- Check current branch matches PRD `branchName`
- If not, checkout or create from main
- **Note:** Multiple PRDs can share the same branch (e.g., `jeff/dev-2`)

---

## Implementation Rules

- **ONE story per iteration** - Ralph spawns fresh each time
- **Keep changes minimal** - Only what the story requires
- **Follow existing patterns** - Match codebase conventions
- **ALL commits must pass** - typecheck, lint, test

---

## After Implementation

### Track Files Changed

Before committing, record all modified files (staged + unstaged + untracked):

```bash
git status --porcelain | awk '{print $2}'
```

Update prd.json with `filesChanged` for the completed story:

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

### Update prd.json
Set `passes: true` and populate `filesChanged` for completed story.

### Append to progress.txt
```
## [Date/Time] - [Story ID]
- What was implemented
- Files changed: [list files]
- **Learnings:**
  - Patterns discovered
  - Gotchas encountered
---
```

### Commit Message (Only Related Files)

**IMPORTANT:** Only commit files related to this story, not all changes.

```bash
# Stage only the files changed by this story
git add <file1> <file2> ...

# Commit with story reference
git commit -m "feat: [Story ID] - [Story Title]"
```

Do NOT use `git add -A` or `git add .` - be explicit about which files to commit.

---

## Codebase Patterns

If you discover **reusable patterns**, add to `## Codebase Patterns` section at TOP of progress.txt:

```
## Codebase Patterns
- Use `sql<number>` template for aggregations
- Always use `IF NOT EXISTS` for migrations
```

Only add patterns that are **general and reusable**.

---

## Update AGENTS.md

Before committing, check if edited directories have learnings worth preserving:

**Add:**
- API patterns or conventions
- Gotchas or non-obvious requirements
- Dependencies between files

**Don't add:**
- Story-specific details
- Temporary debugging notes

---

## Browser Testing (Frontend Stories)

For UI changes, MUST verify in browser:

1. Load the `dev-browser` skill
2. Navigate to relevant page
3. Verify UI changes work
4. Screenshot if helpful

**Frontend stories NOT complete until browser verified.**

---

## Release Lock

After completing a story (success or failure), delete the lock file:

```bash
rm .claude/ralph-ryan/<prd-slug>/lock.json
```

---

## Stop Condition

After completing a story:

- If ALL stories in this PRD have `passes: true`:
  1. **Archive completed PRD:**
     ```bash
     PRD_SLUG=$(basename "$PRD_DIR")
     mv "$PRD_DIR" ".claude/ralph-ryan-archived/$(date +%Y-%m-%d)-${PRD_SLUG}"
     ```
  2. **Output completion promise:**
     ```
     <promise>COMPLETE</promise>
     Archived to: .claude/ralph-ryan-archived/YYYY-MM-DD-<prd-slug>/
     ```

- If stories remain with `passes: false`:
  End normally (the Stop Hook will continue the loop automatically)

---

## Checklist

- [ ] Selected PRD to execute
- [ ] Loop initialized via setup script
- [ ] Lock acquired
- [ ] Conflict check passed
- [ ] On correct branch
- [ ] Implemented ONE story
- [ ] Files tracked in prd.json
- [ ] Quality checks passed
- [ ] Committed with story reference
- [ ] progress.txt updated
- [ ] Lock released
- [ ] If all done: archived and output `<promise>COMPLETE</promise>`
