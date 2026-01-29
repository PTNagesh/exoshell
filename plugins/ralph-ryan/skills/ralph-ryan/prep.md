# Prep Mode (Multi-PRD Support)

Prepare Ralph execution environment by converting PRD and initializing files.

---

## The Job

1. **List available PRDs** in `.claude/ralph-ryan/`
2. **Ask user to select** which PRD to prepare
3. **Ask branch strategy** (current / new from current / new from main)
4. Read selected PRD's `prd.md`
5. Convert to `prd.json`
6. Initialize `progress.txt` (if not exists)

---

## Step 1: List Available PRDs

Scan `.claude/ralph-ryan/` for subdirectories containing `prd.md`:

```bash
ls -d .claude/ralph-ryan/*/
```

Display to user:

```
Available PRDs:

1. prd-06-risk-management/
   └── prd.md exists, prd.json: NO

2. prd-07-model-governance/
   └── prd.md exists, prd.json: YES (3/5 stories done)

Which PRD do you want to prepare? (enter number or name):
```

---

## Step 2: Validate Selection

- Check `prd.md` exists in selected directory
- If `prd.json` already exists, ask if user wants to regenerate

---

## Step 3: Branch Strategy

First, get current branch info:

```bash
git branch --show-current
git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main"
```

Then ask user to choose branch strategy:

```
Current branch: <current-branch>

Branch strategy for this PRD:

A. Use current branch (<current-branch>)
   └── Work directly on current branch, no new branch created

B. Create new branch from current (<current-branch>)
   └── New branch: ralph/<prd-slug> (based on <current-branch>)

C. Create new branch from main/master
   └── New branch: ralph/<prd-slug> (based on main)

Which branch strategy? (A/B/C):
```

**Branch name rules based on selection:**

| Choice | branchName in prd.json | Action in Run mode |
|--------|------------------------|-------------------|
| A | `<current-branch>` | Stay on current branch |
| B | `ralph/<prd-slug>` | Create from current, set `baseBranch: "<current-branch>"` |
| C | `ralph/<prd-slug>` | Create from main/master, set `baseBranch: "main"` |

---

## Step 4: Output Format

```json
{
  "project": "[Project Name]",
  "featureName": "[feature-name-kebab-case]",
  "prdSlug": "[prd-slug]",
  "branchName": "[determined by branch strategy]",
  "baseBranch": "[base branch for creation, omit if using current]",
  "description": "[Feature description]",
  "userStories": [
    {
      "id": "US-001",
      "title": "[Story title]",
      "description": "As a [user], I want [feature] so that [benefit]",
      "acceptanceCriteria": [
        "Criterion 1",
        "Typecheck passes"
      ],
      "priority": 1,
      "passes": false,
      "notes": "",
      "filesChanged": []
    }
  ]
}
```

**New fields:**
- `prdSlug`: The PRD directory name
- `branchName`: Target branch (current branch or `ralph/<prd-slug>`)
- `baseBranch`: Base branch for creation (only present if creating new branch)
- `filesChanged`: Array to track files modified by each story (initially empty)

---

## Conversion Rules

1. Each user story → one JSON entry
2. IDs: Sequential (US-001, US-002, ...)
3. Priority: Based on dependency order, then document order
4. All stories: `passes: false`, empty `notes`, empty `filesChanged`
5. featureName: kebab-case (e.g., "risk-management")
6. prdSlug: The directory name (e.g., "prd-06-risk-management")
7. branchName: Based on user's branch strategy choice
8. baseBranch: Only set if creating new branch (choice B or C)
9. Always include "Typecheck passes" in acceptance criteria

---

## Initialize progress.txt

If `.claude/ralph-ryan/<prd-slug>/progress.txt` doesn't exist, create it:

```markdown
## Codebase Patterns

(Patterns discovered during implementation will be added here)

---

# Progress Log

```

---

## Archiving Previous Runs

**Note:** With multi-PRD support, archiving happens per-PRD when ALL stories complete (handled in run.md), not during prep.

---

## Checklist

Before saving:
- [ ] Listed available PRDs
- [ ] User selected a specific PRD
- [ ] User selected branch strategy
- [ ] prdSlug matches directory name
- [ ] branchName set according to branch strategy
- [ ] baseBranch set if creating new branch
- [ ] featureName is kebab-case
- [ ] Each story completable in one iteration
- [ ] Stories ordered by dependency
- [ ] Every story has "Typecheck passes"
- [ ] UI stories have "Verify in browser using dev-browser skill"
- [ ] progress.txt initialized
- [ ] Saved to `.claude/ralph-ryan/<prd-slug>/prd.json`
