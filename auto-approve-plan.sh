#!/bin/bash
INPUT=$(cat)

# Prevent infinite loop
if [ "$(echo "$INPUT" | jq -r '.stop_hook_active')" = "true" ]; then
  exit 0
fi

# Only act in plan mode
if [ "$(echo "$INPUT" | jq -r '.permission_mode')" != "plan" ]; then
  exit 0
fi

# Check transcript: only auto-approve if ExitPlanMode was actually called
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path')
if [ -f "$TRANSCRIPT" ]; then
  # Check last 10KB of transcript for ExitPlanMode tool call
  if tail -c 10000 "$TRANSCRIPT" | grep -q '"name":"ExitPlanMode"\|"name": "ExitPlanMode"'; then
    echo '{"decision": "block", "reason": "Plan auto-approved by hook. Proceed with implementation now."}'
    exit 0
  fi
fi

exit 0
