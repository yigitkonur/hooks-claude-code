#!/bin/bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════════╗
# ║  claude-plan-hook installer                                     ║
# ║  Auto-approve Claude Code plans + optional Craft.do archiving  ║
# ╚══════════════════════════════════════════════════════════════════╝

HOOK_DIR="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"
CRAFT_CONFIG="$HOOK_DIR/craft-config.env"
HOOK_SCRIPT="$HOOK_DIR/claude-plan-hook.sh"

# GitHub raw URL for remote install (curl | bash)
REPO_RAW="https://raw.githubusercontent.com/yigitkonur/hooks-claude-approve/main"

# ── Colors ───────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

ok()   { printf "${GREEN}[ok]${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}[!!]${NC} %s\n" "$1"; }
err()  { printf "${RED}[err]${NC} %s\n" "$1"; }
info() { printf "${CYAN}[..]${NC} %s\n" "$1"; }

# ── Banner ───────────────────────────────────────────────────────────
printf "\n"
printf "${BOLD}  claude-plan-hook${NC}\n"
printf "${DIM}  Auto-approve Claude Code plans. Archive them to Craft.${NC}\n"
printf "\n"

# ── Prerequisites ────────────────────────────────────────────────────
if ! command -v jq &>/dev/null; then
  err "jq is required but not installed."
  printf "  ${DIM}brew install jq${NC}   # macOS\n"
  printf "  ${DIM}sudo apt install jq${NC}   # Debian/Ubuntu\n"
  exit 1
fi

# ── Detect existing install ──────────────────────────────────────────
CURRENT_MODE=""
if [ -f "$HOOK_SCRIPT" ]; then
  if head -5 "$HOOK_SCRIPT" | grep -q "Mode 1"; then
    CURRENT_MODE="1"
  elif head -5 "$HOOK_SCRIPT" | grep -q "Mode 2"; then
    CURRENT_MODE="2"
  elif head -5 "$HOOK_SCRIPT" | grep -q "Mode 3"; then
    CURRENT_MODE="3"
  else
    CURRENT_MODE="unknown"
  fi
fi

if [ -n "$CURRENT_MODE" ]; then
  case "$CURRENT_MODE" in
    1) warn "Already installed: Mode 1 (auto-approve only)" ;;
    2) warn "Already installed: Mode 2 (auto-approve + Craft)" ;;
    3) warn "Already installed: Mode 3 (Craft only)" ;;
    *) warn "Already installed: unrecognized version" ;;
  esac
  printf "\n"
fi

# ── Mode selection ───────────────────────────────────────────────────
printf "${BOLD}Choose a mode:${NC}\n\n"
printf "  ${BOLD}1${NC}  Auto-approve only\n"
printf "     ${DIM}Plans are approved instantly. No external services.${NC}\n\n"
printf "  ${BOLD}2${NC}  Auto-approve + publish to Craft.do\n"
printf "     ${DIM}Plans are approved and archived as subpages in Craft.${NC}\n\n"
printf "  ${BOLD}3${NC}  Craft.do publish only (no auto-approve)\n"
printf "     ${DIM}Plans are archived in Craft but you still approve manually.${NC}\n\n"

while true; do
  printf "${CYAN}>${NC} Enter mode [1/2/3]: "
  read -r MODE
  case "$MODE" in
    1|2|3) break ;;
    *) err "Please enter 1, 2, or 3." ;;
  esac
done
printf "\n"

# ── Craft credentials (modes 2 and 3) ───────────────────────────────
CRAFT_API_URL=""
CRAFT_PAGE_ID=""

if [ "$MODE" = "2" ] || [ "$MODE" = "3" ]; then
  if ! command -v curl &>/dev/null; then
    err "curl is required for Craft integration but not found."
    exit 1
  fi

  printf "${BOLD}Craft.do setup${NC}\n"
  printf "${DIM}You need a Craft API connection URL and a parent page ID.${NC}\n"
  printf "${DIM}Create an API connection in Craft Settings > API, then copy the endpoint.${NC}\n\n"

  # Load existing values as defaults
  if [ -f "$CRAFT_CONFIG" ]; then
    source "$CRAFT_CONFIG" 2>/dev/null || true
  fi

  # API URL
  if [ -n "$CRAFT_API_URL" ]; then
    printf "${CYAN}>${NC} Craft API URL ${DIM}[${CRAFT_API_URL}]${NC}: "
    read -r INPUT_URL
    [ -n "$INPUT_URL" ] && CRAFT_API_URL="$INPUT_URL"
  else
    printf "${CYAN}>${NC} Craft API URL (e.g. https://connect.craft.do/links/[your-key-id]/api/v1): "
    read -r CRAFT_API_URL
  fi

  # Strip trailing slash and /blocks suffix
  CRAFT_API_URL="${CRAFT_API_URL%/}"
  CRAFT_API_URL="${CRAFT_API_URL%/blocks}"

  if [ -z "$CRAFT_API_URL" ]; then
    err "Craft API URL is required for this mode."
    exit 1
  fi

  # Page ID
  if [ -n "$CRAFT_PAGE_ID" ]; then
    printf "${CYAN}>${NC} Parent page ID ${DIM}[${CRAFT_PAGE_ID}]${NC}: "
    read -r INPUT_PID
    [ -n "$INPUT_PID" ] && CRAFT_PAGE_ID="$INPUT_PID"
  else
    printf "${CYAN}>${NC} Parent page ID (UUID of the Craft page to nest plans under): "
    read -r CRAFT_PAGE_ID
  fi

  if [ -z "$CRAFT_PAGE_ID" ]; then
    err "Parent page ID is required for this mode."
    exit 1
  fi

  printf "\n"

  # Test connectivity
  info "Testing Craft API connectivity..."
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${CRAFT_API_URL}/blocks" \
    -H "Content-Type: application/json" \
    -d "{\"blocks\":[{\"type\":\"text\",\"markdown\":\"connectivity test — safe to delete\"}],\"position\":{\"position\":\"end\",\"pageId\":\"${CRAFT_PAGE_ID}\"}}" 2>/dev/null || echo "000")

  if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    ok "Craft API reachable (HTTP ${HTTP_CODE})"
  else
    warn "Craft API returned HTTP ${HTTP_CODE}. Check your URL and page ID."
    printf "  ${DIM}Continuing anyway — you can fix credentials later in:${NC}\n"
    printf "  ${DIM}${CRAFT_CONFIG}${NC}\n\n"
  fi

  # Save credentials
  mkdir -p "$HOOK_DIR"
  cat > "$CRAFT_CONFIG" <<ENVEOF
# claude-plan-hook: Craft.do credentials
# Generated by install.sh — edit freely
CRAFT_API_URL="${CRAFT_API_URL}"
CRAFT_PAGE_ID="${CRAFT_PAGE_ID}"
ENVEOF
  chmod 600 "$CRAFT_CONFIG"
  ok "Craft credentials saved to ${CRAFT_CONFIG}"
fi

# ── Install hook script ─────────────────────────────────────────────
mkdir -p "$HOOK_DIR"

# Determine hook source file
case "$MODE" in
  1) HOOK_SRC="hooks/auto-approve-plan.sh" ;;
  2) HOOK_SRC="hooks/auto-approve-craft.sh" ;;
  3) HOOK_SRC="hooks/craft-only.sh" ;;
esac

# Try local copy first (cloned repo), fall back to curl (pipe install)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)"
if [ -f "${SCRIPT_DIR}/${HOOK_SRC}" ]; then
  cp -f "${SCRIPT_DIR}/${HOOK_SRC}" "$HOOK_SCRIPT"
else
  info "Downloading hook script from GitHub..."
  curl -fsSL "${REPO_RAW}/${HOOK_SRC}" -o "$HOOK_SCRIPT"
fi
chmod +x "$HOOK_SCRIPT"
ok "Hook script installed to ${HOOK_SCRIPT}"

# ── Update settings.json ────────────────────────────────────────────
HOOK_CMD="~/.claude/hooks/claude-plan-hook.sh"

if [ ! -f "$SETTINGS" ]; then
  # Create a minimal settings.json
  cat > "$SETTINGS" <<ENDJSON
{
  "hooks": {
    "PermissionRequest": [
      {
        "matcher": "ExitPlanMode",
        "hooks": [
          {
            "type": "command",
            "command": "${HOOK_CMD}"
          }
        ]
      }
    ]
  }
}
ENDJSON
  ok "Created ${SETTINGS}"
else
  TMP=$(mktemp)

  jq --arg cmd "$HOOK_CMD" '
    # Ensure hooks object exists
    .hooks //= {} |

    # Ensure PermissionRequest array exists
    .hooks.PermissionRequest //= [] |

    # Remove any existing ExitPlanMode matcher entries (clean swap)
    .hooks.PermissionRequest = [
      .hooks.PermissionRequest[] |
      select(.matcher != "ExitPlanMode")
    ] |

    # Add the new ExitPlanMode entry
    .hooks.PermissionRequest += [{
      "matcher": "ExitPlanMode",
      "hooks": [{
        "type": "command",
        "command": $cmd
      }]
    }] |

    # Remove old broken Stop hook entries referencing auto-approve
    if .hooks.Stop then
      .hooks.Stop = [
        .hooks.Stop[] |
        .hooks = [.hooks[] | select(.command | test("auto-approve"; "i") | not)]
      ] |
      .hooks.Stop = [.hooks.Stop[] | select(.hooks | length > 0)]
    else . end |

    # Clean up empty Stop array
    if .hooks.Stop == [] then del(.hooks.Stop) else . end
  ' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"

  ok "Updated ${SETTINGS}"
fi

# ── Summary ──────────────────────────────────────────────────────────
printf "\n"
printf "${GREEN}${BOLD}Installed!${NC}\n\n"

case "$MODE" in
  1)
    printf "  Mode:   ${BOLD}Auto-approve only${NC}\n"
    printf "  Effect: Plans are approved instantly when Claude calls ExitPlanMode.\n"
    ;;
  2)
    printf "  Mode:   ${BOLD}Auto-approve + Craft${NC}\n"
    printf "  Effect: Plans are approved instantly AND archived in Craft.do.\n"
    printf "  Craft:  ${DIM}${CRAFT_API_URL}${NC}\n"
    ;;
  3)
    printf "  Mode:   ${BOLD}Craft publish only${NC}\n"
    printf "  Effect: Plans are archived in Craft.do. You still approve manually.\n"
    printf "  Craft:  ${DIM}${CRAFT_API_URL}${NC}\n"
    ;;
esac

printf "\n"
printf "  ${DIM}Restart Claude Code for changes to take effect.${NC}\n"
printf "  ${DIM}To change modes, run the installer again.${NC}\n"
printf "  ${DIM}To uninstall: curl -fsSL ${REPO_RAW}/uninstall.sh | bash${NC}\n"
printf "\n"
