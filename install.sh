#!/bin/bash
set -euo pipefail

HOOK_DIR="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_SCRIPT="$HOOK_DIR/auto-approve-plan.sh"

echo "=== Auto-Approve Plan Hook for Claude Code ==="
echo ""

# ── Prerequisites ──────────────────────────────────────────────
if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required but not installed."
  echo "  brew install jq   # macOS"
  echo "  sudo apt install jq   # Ubuntu/Debian"
  exit 1
fi

# ── Install hook script ───────────────────────────────────────
mkdir -p "$HOOK_DIR"
cp -f "$SCRIPT_DIR/auto-approve-plan.sh" "$HOOK_SCRIPT"
chmod +x "$HOOK_SCRIPT"
echo "[ok] Hook script installed to $HOOK_SCRIPT"

# ── Merge hook config into settings.json ──────────────────────
HOOK_CMD="~/.claude/hooks/auto-approve-plan.sh"

if [ ! -f "$SETTINGS" ]; then
  cat > "$SETTINGS" <<'ENDJSON'
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/auto-approve-plan.sh"
          }
        ]
      }
    ]
  }
}
ENDJSON
  echo "[ok] Created $SETTINGS with Stop hook"
else
  if jq -e '.hooks.Stop[]?.hooks[]? | select(.command == "~/.claude/hooks/auto-approve-plan.sh")' "$SETTINGS" &>/dev/null; then
    echo "[ok] Stop hook already present in $SETTINGS (no change)"
  else
    TMP=$(mktemp)
    jq '
      .hooks //= {} |
      .hooks.Stop //= [] |
      .hooks.Stop += [{"hooks": [{"type": "command", "command": "~/.claude/hooks/auto-approve-plan.sh"}]}]
    ' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
    echo "[ok] Stop hook added to $SETTINGS"
  fi
fi

echo ""
echo "Done! Usage:"
echo "  1. Open Claude Code"
echo "  2. Enter plan mode (Shift+Tab)"
echo "  3. Give it a task — when it calls ExitPlanMode, the plan auto-approves"
echo "  4. Research/exploration stops are NOT blocked"
echo ""
echo "Debug log: ~/.claude/hooks/stop-hook-debug.log"
echo "  Every Stop event is logged there with full JSON payload."
