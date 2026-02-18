#!/bin/bash
INPUT=$(cat)
LOG="$HOME/.claude/hooks/stop-hook-debug.log"

# ── Log every single Stop event ──────────────────────────────
{
  echo "════════════════════════════════════════════════════"
  echo "STOP HOOK FIRED: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "────────────────────────────────────────────────────"
  echo "FULL INPUT JSON:"
  echo "$INPUT" | jq '.' 2>/dev/null || echo "$INPUT"
  echo "────────────────────────────────────────────────────"
  echo "KEY FIELDS:"
  echo "  stop_hook_active = $(echo "$INPUT" | jq -r '.stop_hook_active // "MISSING"')"
  echo "  permission_mode  = $(echo "$INPUT" | jq -r '.permission_mode // "MISSING"')"
  echo "  session_id       = $(echo "$INPUT" | jq -r '.session_id // "MISSING"')"
  echo "  transcript_path  = $(echo "$INPUT" | jq -r '.transcript_path // "MISSING"')"
  echo "  hook_event_name  = $(echo "$INPUT" | jq -r '.hook_event_name // "MISSING"')"
  echo "  cwd              = $(echo "$INPUT" | jq -r '.cwd // "MISSING"')"
  echo "  ALL TOP-LEVEL KEYS: $(echo "$INPUT" | jq -r 'keys | join(", ")' 2>/dev/null || echo "PARSE_FAILED")"
  echo "────────────────────────────────────────────────────"
} >> "$LOG"

# ── Prevent infinite loop ────────────────────────────────────
STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // "false"')
if [ "$STOP_ACTIVE" = "true" ]; then
  echo "DECISION: exit 0 (stop_hook_active=true, prevent loop)" >> "$LOG"
  echo "" >> "$LOG"
  exit 0
fi

# ── Check permission mode ────────────────────────────────────
PERM_MODE=$(echo "$INPUT" | jq -r '.permission_mode // "MISSING"')
echo "CHECKING: permission_mode='$PERM_MODE'" >> "$LOG"

if [ "$PERM_MODE" = "plan" ]; then
  # In plan mode — check transcript for ExitPlanMode
  TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // ""')
  echo "CHECKING: transcript='$TRANSCRIPT'" >> "$LOG"

  if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
    HAS_EXIT=$(tail -c 20000 "$TRANSCRIPT" | grep -c 'ExitPlanMode' || true)
    echo "CHECKING: ExitPlanMode occurrences in last 20KB = $HAS_EXIT" >> "$LOG"

    if [ "$HAS_EXIT" -gt 0 ]; then
      echo "DECISION: BLOCKING (auto-approve plan)" >> "$LOG"
      echo "" >> "$LOG"
      echo '{"decision": "block", "reason": "Plan auto-approved by hook. Proceed with implementation now."}'
      exit 0
    else
      echo "DECISION: exit 0 (plan mode but no ExitPlanMode in transcript)" >> "$LOG"
    fi
  else
    echo "DECISION: exit 0 (transcript not found: '$TRANSCRIPT')" >> "$LOG"
  fi
else
  echo "DECISION: exit 0 (not plan mode: '$PERM_MODE')" >> "$LOG"
fi

echo "" >> "$LOG"
exit 0
