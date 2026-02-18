#!/bin/bash
set -e

HOOK_DIR="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing auto-approve-plan hook for Claude Code..."

# 1. Create hooks directory if missing
mkdir -p "$HOOK_DIR"

# 2. Copy hook script
cp "$SCRIPT_DIR/auto-approve-plan.sh" "$HOOK_DIR/auto-approve-plan.sh"
chmod +x "$HOOK_DIR/auto-approve-plan.sh"
echo "  ✓ Hook script installed to $HOOK_DIR/auto-approve-plan.sh"

# 3. Merge Stop hook config into settings.json
if ! command -v jq &>/dev/null; then
  echo "  ✗ jq is required but not installed. Install it with: brew install jq"
  exit 1
fi

HOOK_ENTRY='{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"~/.claude/hooks/auto-approve-plan.sh"}]}]}}'

if [ -f "$SETTINGS" ]; then
  # Merge into existing settings
  MERGED=$(jq --argjson new "$HOOK_ENTRY" '. * $new' "$SETTINGS")
  echo "$MERGED" > "$SETTINGS"
  echo "  ✓ Stop hook merged into $SETTINGS"
else
  # Create minimal settings with just the hook
  echo "$HOOK_ENTRY" | jq '.' > "$SETTINGS"
  echo "  ✓ Created $SETTINGS with Stop hook"
fi

echo ""
echo "Done! The auto-approve-plan hook is now active."
echo "When Claude calls ExitPlanMode in plan mode, the plan will be auto-approved."
echo "Research/exploration stops in plan mode will NOT be blocked."
