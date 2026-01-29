#!/bin/bash

# Ralph Ryan Stop Hook (Multi-PRD Support)
# Prevents session exit when a ralph-ryan loop is active
# Uses session_hash (SHA256 of transcript_path) for privacy

set -eo pipefail

# Read hook input from stdin (advanced stop hook API)
HOOK_INPUT=$(cat)

# Base directory for ralph-ryan PRDs
RALPH_BASE_DIR=".claude/ralph-ryan"

# Get transcript path from hook input
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // ""')

if [[ -z "$TRANSCRIPT_PATH" ]]; then
  # No transcript path - allow exit
  exit 0
fi

# Hash the transcript path to avoid storing full path (privacy)
SESSION_HASH=$(echo -n "$TRANSCRIPT_PATH" | shasum -a 256 | cut -c1-16)

# Find all active loop state files
STATE_FILES=""
PRD_DIRS=""
STATE_COUNT=0

if [[ -d "$RALPH_BASE_DIR" ]]; then
  for prd_dir in "$RALPH_BASE_DIR"/*/; do
    if [[ -f "${prd_dir}ralph-loop.local.md" ]]; then
      if [[ $STATE_COUNT -eq 0 ]]; then
        STATE_FILES="${prd_dir}ralph-loop.local.md"
        PRD_DIRS="$prd_dir"
      else
        STATE_FILES="$STATE_FILES|${prd_dir}ralph-loop.local.md"
        PRD_DIRS="$PRD_DIRS|$prd_dir"
      fi
      STATE_COUNT=$((STATE_COUNT + 1))
    fi
  done
fi

if [[ $STATE_COUNT -eq 0 ]]; then
  # No active loops - allow exit
  exit 0
fi

# ============================================================
# SESSION HASH MATCHING
# ============================================================
# Each ralph-loop.local.md contains a session_hash field.
# - Empty session_hash: new loop, needs to be claimed
# - Matching session_hash: this session's loop, continue it
# - Non-matching session_hash: different session's loop, skip it

MATCHED_STATE_FILE=""
MATCHED_PRD_DIR=""
EMPTY_STATE_FILE=""
EMPTY_PRD_DIR=""
FIRST_STATE_FILE=""
FIRST_PRD_DIR=""

# Iterate using pipe-delimited strings
IFS='|' read -ra STATE_ARR <<< "$STATE_FILES"
IFS='|' read -ra PRD_ARR <<< "$PRD_DIRS"

for i in "${!STATE_ARR[@]}"; do
  STATE_FILE="${STATE_ARR[$i]}"
  PRD_DIR="${PRD_ARR[$i]}"

  # Save first for fallback
  if [[ -z "$FIRST_STATE_FILE" ]]; then
    FIRST_STATE_FILE="$STATE_FILE"
    FIRST_PRD_DIR="$PRD_DIR"
  fi

  # Parse markdown frontmatter and extract session_hash
  FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE")
  STATE_SESSION_HASH=$(echo "$FRONTMATTER" | grep '^session_hash:' | sed 's/session_hash: *//' | sed 's/^"\(.*\)"$/\1/')

  if [[ -z "$STATE_SESSION_HASH" ]] || [[ "$STATE_SESSION_HASH" == '""' ]]; then
    # Empty session_hash - candidate for claiming
    EMPTY_STATE_FILE="$STATE_FILE"
    EMPTY_PRD_DIR="$PRD_DIR"
  elif [[ "$STATE_SESSION_HASH" == "$SESSION_HASH" ]]; then
    # Exact match - this is our loop
    MATCHED_STATE_FILE="$STATE_FILE"
    MATCHED_PRD_DIR="$PRD_DIR"
    break
  fi
done

# Determine which state file to use
ACTIVE_STATE_FILE=""
ACTIVE_PRD_DIR=""

if [[ -n "$MATCHED_STATE_FILE" ]]; then
  # Found matching session_hash - use it
  ACTIVE_STATE_FILE="$MATCHED_STATE_FILE"
  ACTIVE_PRD_DIR="$MATCHED_PRD_DIR"
elif [[ -n "$EMPTY_STATE_FILE" ]]; then
  # Found empty session_hash - claim it by writing current session_hash
  ACTIVE_STATE_FILE="$EMPTY_STATE_FILE"
  ACTIVE_PRD_DIR="$EMPTY_PRD_DIR"

  # Write session_hash to state file
  TEMP_FILE="${ACTIVE_STATE_FILE}.tmp.$$"
  sed "s|^session_hash:.*|session_hash: \"$SESSION_HASH\"|" "$ACTIVE_STATE_FILE" > "$TEMP_FILE"
  mv "$TEMP_FILE" "$ACTIVE_STATE_FILE"
else
  # No matching or empty state files found
  # There are active loops but none belong to this session
  # Ask user what to do

  # Get PRD info from first state file for the prompt
  FIRST_FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$FIRST_STATE_FILE")
  FIRST_PRD_SLUG=$(echo "$FIRST_FRONTMATTER" | grep '^prd_slug:' | sed 's/prd_slug: *//' | sed 's/^"\(.*\)"$/\1/')

  # Output JSON to ask user
  jq -n \
    --arg prd "$FIRST_PRD_SLUG" \
    --arg file "$FIRST_STATE_FILE" \
    '{
      "decision": "ask",
      "question": "Found active Ralph loop for PRD: \($prd), but it belongs to a different session.\n\nOptions:\n1. Exit anyway (loop will remain for other session)\n2. Take over this loop (continue in current session)\n\nChoose (1 or 2):",
      "options": ["exit", "takeover"]
    }'
  exit 0
fi

# ============================================================
# CONTINUE LOOP LOGIC
# ============================================================

# Parse markdown frontmatter (YAML between ---) and extract values
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$ACTIVE_STATE_FILE")
ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//')
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//')
PRD_SLUG=$(echo "$FRONTMATTER" | grep '^prd_slug:' | sed 's/prd_slug: *//' | sed 's/^"\(.*\)"$/\1/')
COMPLETION_PROMISE=$(echo "$FRONTMATTER" | grep '^completion_promise:' | sed 's/completion_promise: *//' | sed 's/^"\(.*\)"$/\1/')

# Verify transcript file exists
if [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  echo "⚠️  Ralph Ryan loop: Transcript file not found" >&2
  echo "   Ralph loop is stopping." >&2
  rm "$ACTIVE_STATE_FILE"
  exit 0
fi

# Validate numeric fields before arithmetic operations
if [[ ! "$ITERATION" =~ ^[0-9]+$ ]]; then
  echo "⚠️  Ralph Ryan loop: State file corrupted" >&2
  echo "   File: $ACTIVE_STATE_FILE" >&2
  echo "   Problem: 'iteration' field is not a valid number (got: '$ITERATION')" >&2
  echo "" >&2
  echo "   Ralph loop is stopping. Run /ralph-ryan run again to start fresh." >&2
  rm "$ACTIVE_STATE_FILE"
  exit 0
fi

if [[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "⚠️  Ralph Ryan loop: State file corrupted" >&2
  echo "   File: $ACTIVE_STATE_FILE" >&2
  echo "   Problem: 'max_iterations' field is not a valid number (got: '$MAX_ITERATIONS')" >&2
  echo "" >&2
  echo "   Ralph loop is stopping. Run /ralph-ryan run again to start fresh." >&2
  rm "$ACTIVE_STATE_FILE"
  exit 0
fi

# Check if max iterations reached
if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  echo "🛑 Ralph Ryan loop: Max iterations ($MAX_ITERATIONS) reached for PRD: $PRD_SLUG"
  rm "$ACTIVE_STATE_FILE"
  exit 0
fi

# Read last assistant message from transcript (JSONL format - one JSON per line)
if ! grep -q '"role":"assistant"' "$TRANSCRIPT_PATH"; then
  echo "⚠️  Ralph Ryan loop: No assistant messages found in transcript" >&2
  echo "   Ralph loop is stopping." >&2
  rm "$ACTIVE_STATE_FILE"
  exit 0
fi

# Extract last assistant message with explicit error handling
LAST_LINE=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -1)
if [[ -z "$LAST_LINE" ]]; then
  echo "⚠️  Ralph Ryan loop: Failed to extract last assistant message" >&2
  echo "   Ralph loop is stopping." >&2
  rm "$ACTIVE_STATE_FILE"
  exit 0
fi

# Parse JSON with error handling
LAST_OUTPUT=$(echo "$LAST_LINE" | jq -r '
  .message.content |
  map(select(.type == "text")) |
  map(.text) |
  join("\n")
' 2>&1)

# Check if jq succeeded
if [[ $? -ne 0 ]]; then
  echo "⚠️  Ralph Ryan loop: Failed to parse assistant message JSON" >&2
  echo "   Error: $LAST_OUTPUT" >&2
  echo "   Ralph loop is stopping." >&2
  rm "$ACTIVE_STATE_FILE"
  exit 0
fi

if [[ -z "$LAST_OUTPUT" ]]; then
  echo "⚠️  Ralph Ryan loop: Assistant message contained no text content" >&2
  echo "   Ralph loop is stopping." >&2
  rm "$ACTIVE_STATE_FILE"
  exit 0
fi

# Check for completion promise (only if set)
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  # Extract text from <promise> tags using Perl for multiline support
  PROMISE_TEXT=$(echo "$LAST_OUTPUT" | perl -0777 -pe 's/.*?<promise>(.*?)<\/promise>.*/$1/s; s/^\s+|\s+$//g; s/\s+/ /g' 2>/dev/null || echo "")

  # Use = for literal string comparison
  if [[ -n "$PROMISE_TEXT" ]] && [[ "$PROMISE_TEXT" = "$COMPLETION_PROMISE" ]]; then
    echo "✅ Ralph Ryan loop: Detected <promise>$COMPLETION_PROMISE</promise> for PRD: $PRD_SLUG"
    rm "$ACTIVE_STATE_FILE"
    exit 0
  fi
fi

# Not complete - continue loop with SAME PROMPT
NEXT_ITERATION=$((ITERATION + 1))

# Extract prompt (everything after the closing ---)
PROMPT_TEXT=$(awk '/^---$/{i++; next} i>=2' "$ACTIVE_STATE_FILE")

if [[ -z "$PROMPT_TEXT" ]]; then
  echo "⚠️  Ralph Ryan loop: State file corrupted or incomplete" >&2
  echo "   File: $ACTIVE_STATE_FILE" >&2
  echo "   Problem: No prompt text found" >&2
  echo "   Ralph loop is stopping. Run /ralph-ryan run again to start fresh." >&2
  rm "$ACTIVE_STATE_FILE"
  exit 0
fi

# Update iteration in frontmatter (portable across macOS and Linux)
TEMP_FILE="${ACTIVE_STATE_FILE}.tmp.$$"
sed "s/^iteration: .*/iteration: $NEXT_ITERATION/" "$ACTIVE_STATE_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$ACTIVE_STATE_FILE"

# Build system message with iteration count and PRD info
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  SYSTEM_MSG="🔄 Ralph Ryan iteration $NEXT_ITERATION | PRD: $PRD_SLUG | To stop: output <promise>$COMPLETION_PROMISE</promise> (ONLY when TRUE!)"
else
  SYSTEM_MSG="🔄 Ralph Ryan iteration $NEXT_ITERATION | PRD: $PRD_SLUG | No completion promise set"
fi

# Output JSON to block the stop and feed prompt back
jq -n \
  --arg prompt "$PROMPT_TEXT" \
  --arg msg "$SYSTEM_MSG" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }'

exit 0
