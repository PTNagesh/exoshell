# Run Mode (Multi-PRD Support)

Execute Ralph to implement user stories from a selected PRD in a loop.

---

## The Job

1. **List available PRDs** with `prd.json`
2. **Ask user to select** which PRD to execute (or auto-select if only one)
3. **Initialize loop** by creating state file directly
4. Read `prd.json` and `progress.txt`
5. Check Codebase Patterns section first
6. Ensure on correct branch from `branchName`
7. Pick highest priority story where `passes: false`
8. Implement that single story
9. **Track files changed**
10. Run quality checks, commit (only related files), update PRD and progress

---

## Step 1: List Available PRDs

Scan `.claude/ralph-ryan/` for subdirectories containing `prd.json`:

```
Available PRDs for execution:

1. prd-06-risk-management/ [READY]
   └── 2/5 stories done

2. prd-07-model-governance/ [IN USE]
   └── 1/4 stories done, another session running

Which PRD do you want to execute? (enter number or name):
```

**Auto-select:** If only one PRD has `prd.json` and no active loop, select it automatically.

---

## Step 2: Initialize Loop

After PRD selection, create the loop state file directly:

**State file path:** `.claude/ralph-ryan/<prd-slug>/ralph-loop.local.md`

**Create with this exact content:**

```markdown
---
active: true
iteration: 1
max_iterations: <n>
completion_promise: "COMPLETE"
prd_slug: "<prd-slug>"
session_hash: ""
started_at: "<current-utc-timestamp>"
---

Load skill ralph-ryan and execute run mode for <prd-slug>.

IMPORTANT: You are in a Ralph loop. Follow these rules:
1. Read .claude/ralph-ryan/<prd-slug>/prd.json to find the next story (passes: false)
2. Implement ONE story only
3. Run quality checks, commit changes
4. Update prd.json (set passes: true, add filesChanged)
5. Update progress.txt with learnings
6. If ALL stories pass, archive and output <promise>COMPLETE</promise>
7. Otherwise, end normally (loop will continue)
```

Where:
- `<n>` is from user's `--max-iterations` argument (default: 0 for unlimited)
- `<prd-slug>` is the selected PRD directory name
- `session_hash` is left empty - the Stop Hook will automatically fill it with a hash of the current session's transcript path (for privacy)
- `<current-utc-timestamp>` is in ISO 8601 format (e.g., `2026-01-30T10:30:00Z`)

**Note:** The Stop Hook uses `session_hash` to identify which session owns this loop. When empty, the hook claims it for the current session. This ensures only the session that started the loop will continue it.

---

## Step 3: Conflict Detection

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

Read `branchName` and `baseBranch` from `prd.json`:

```bash
git branch --show-current
```

**Branch logic:**

| Condition | Action |
|-----------|--------|
| Current branch == `branchName` | Stay on current branch |
| `baseBranch` exists in prd.json | Create `branchName` from `baseBranch` |
| `baseBranch` not set | Assume using current branch directly |

**Create branch if needed:**

```bash
# If baseBranch is set and branchName doesn't exist
git checkout <baseBranch>
git pull origin <baseBranch>
git checkout -b <branchName>

# If branchName exists but not current
git checkout <branchName>
```

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

## Stop Condition

After completing a story:

- If ALL stories in this PRD have `passes: true`:
  1. **Archive completed PRD:**
     ```bash
     PRD_SLUG=$(basename "$PRD_DIR")
     ARCHIVE_DIR=".claude/ralph-ryan-archived/$(date +%Y-%m-%d)-${PRD_SLUG}"
     mv "$PRD_DIR" "$ARCHIVE_DIR"
     ```
  2. **Commit the archive:**
     ```bash
     # Stage the archived PRD and removed original
     git add "$ARCHIVE_DIR"
     git add "$PRD_DIR" 2>/dev/null || true  # Handle deleted files

     # Commit with descriptive message
     git commit -m "chore: archive completed PRD ${PRD_SLUG}"
     ```
  3. **Output completion promise:**
     ```
     <promise>COMPLETE</promise>
     Archived to: .claude/ralph-ryan-archived/YYYY-MM-DD-<prd-slug>/
     Committed: chore: archive completed PRD <prd-slug>
     ```

- If stories remain with `passes: false`:
  End normally (the Stop Hook will continue the loop automatically)

---

## Checklist

- [ ] Selected PRD to execute
- [ ] Loop state file created (`.claude/ralph-ryan/<prd-slug>/ralph-loop.local.md`)
- [ ] Conflict check passed
- [ ] On correct branch
- [ ] Implemented ONE story
- [ ] Files tracked in prd.json
- [ ] Quality checks passed
- [ ] Committed with story reference
- [ ] progress.txt updated
- [ ] If all done: archived and output `<promise>COMPLETE</promise>`
