# claude-plan-hook

Skip the "Ready to code?" prompt. Auto-approve Claude Code plans and optionally archive every plan to [Craft.do](https://craft.do).

## Quick install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/yigitkonur/hooks-claude-approve/main/install.sh)
```

That's it. The installer will ask you to pick a mode:

```
  claude-plan-hook
  Auto-approve Claude Code plans. Archive them to Craft.

Choose a mode:

  1  Auto-approve only
     Plans are approved instantly. No external services.

  2  Auto-approve + publish to Craft.do
     Plans are approved and archived as subpages in Craft.

  3  Craft.do publish only (no auto-approve)
     Plans are archived in Craft but you still approve manually.

> Enter mode [1/2/3]:
```

Restart Claude Code after install. To switch modes, run the installer again.

---

## How it works

```
  You give Claude a task in plan mode
           |
  Claude writes the plan, calls ExitPlanMode
           |
  UI shows "Ready to code?" dialog
           |
  PermissionRequest hook fires  <--- this is the hook
           |
     +-----+-----+
     |             |
  approve       push to
  instantly     Craft.do
     |          (background)
     v               |
  Claude              v
  implements    plan archived
  the plan      as a subpage
```

The plan approval dialog is a `PermissionRequest` event for the `ExitPlanMode` tool. This hook intercepts it and returns `{ behavior: "allow" }` so Claude continues without waiting.

> **Note:** Many implementations try hooking `Stop` and grepping the transcript. That approach doesn't work because the approval dialog fires *before* Claude stops — it's waiting for user input, not stopping.

## Modes

| Mode | Auto-approve | Craft.do | Use case |
|------|:---:|:---:|---|
| **1** Approve only | Yes | No | Just skip the approval dialog |
| **2** Approve + Craft | Yes | Yes | Skip approval and archive every plan |
| **3** Craft only | No | Yes | Archive plans but still approve manually |

## Craft.do setup

Modes 2 and 3 need two things from you:

1. **Craft API URL** — Go to Craft Settings > API, create a connection, copy the endpoint. Looks like `https://connect.craft.do/links/[your-key-id]/api/v1`
2. **Parent page ID** — The UUID of the Craft page where plans will be nested as subpages. Find it in the page URL or via the API.

The installer prompts for both, tests connectivity, and saves them to `~/.claude/hooks/craft-config.env` (permissions `600`). Edit that file anytime to update credentials.

### What gets pushed

Each plan becomes a card subpage under your chosen document:

- **Title:** `[/your/project/path] - [14:30 - 18-02-2026]`
- **Content:** Full plan markdown — headings, tables, code blocks, lists all rendered natively by Craft

## Alternative install

Clone first, then run:

```bash
git clone https://github.com/yigitkonur/hooks-claude-approve.git /tmp/claude-plan-hook \
  && bash /tmp/claude-plan-hook/install.sh \
  && rm -rf /tmp/claude-plan-hook
```

## Uninstall

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/yigitkonur/hooks-claude-approve/main/uninstall.sh)
```

Or manually:

```bash
rm ~/.claude/hooks/claude-plan-hook.sh
# Then remove the PermissionRequest/ExitPlanMode entry from ~/.claude/settings.json
```

## What the installer does

- Checks for `jq` (required) and `curl` (Craft modes)
- Copies the right hook script to `~/.claude/hooks/claude-plan-hook.sh`
- Merges a `PermissionRequest` hook with `ExitPlanMode` matcher into `~/.claude/settings.json`
- Removes old broken `Stop` hook entries from previous versions
- For Craft modes: prompts for credentials, tests the API, saves to `~/.claude/hooks/craft-config.env`
- Re-install safe: switching modes cleanly replaces the hook and settings entry

## Requirements

- macOS or Linux
- [jq](https://jqlang.github.io/jq/) — `brew install jq`
- `curl` (for Craft modes and remote install)
- Claude Code with hooks support

## Troubleshooting

**Plans aren't auto-approving:**
- Restart Claude Code after installing (settings load at session start)
- Verify: `jq '.hooks.PermissionRequest' ~/.claude/settings.json`
- Verify: `ls -la ~/.claude/hooks/claude-plan-hook.sh`

**Plans aren't appearing in Craft:**
- Check credentials: `cat ~/.claude/hooks/craft-config.env`
- Test manually:
  ```bash
  curl -s -X POST "[your-api-url]/blocks" \
    -H "Content-Type: application/json" \
    -d '{"blocks":[{"type":"text","markdown":"test"}],"position":{"position":"end","pageId":"[your-page-id]"}}'
  ```

**Upgrading from the old Stop hook version:**
The installer automatically removes old `Stop` hook entries. No manual cleanup needed.

## License

MIT
