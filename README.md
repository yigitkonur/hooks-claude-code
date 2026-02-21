auto-approves Claude Code's "ready to code?" plan dialog so you stop clicking a button 50 times a day. optionally archives every plan to Craft.do as a timestamped card. pure bash, no dependencies beyond `jq`.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/yigitkonur/hooks-claude-code/main/install.sh)
```

[![bash](https://img.shields.io/badge/bash-pure_shell-93450a.svg?style=flat-square)](https://www.gnu.org/software/bash/)
[![platform](https://img.shields.io/badge/platform-macOS_|_Linux-93450a.svg?style=flat-square)](#)
[![license](https://img.shields.io/badge/license-MIT-grey.svg?style=flat-square)](https://opensource.org/licenses/MIT)

---

## the problem

Claude Code has a plan mode. when Claude finishes writing a plan and calls `ExitPlanMode`, it fires a `PermissionRequest` event and waits for you to click approve. every single time. this hooks into that event and returns `{"behavior":"allow"}` immediately.

## three modes

the installer asks you to pick one:

| mode | what it does |
|:---|:---|
| **1 — auto-approve only** | approves every plan instantly. no network calls, no logging. install and forget |
| **2 — auto-approve + Craft** | approves instantly and archives the plan to a Craft.do page in the background |
| **3 — Craft only** | archives to Craft but still shows the manual approval dialog |

## install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/yigitkonur/hooks-claude-code/main/install.sh)
```

or clone first:

```bash
git clone https://github.com/yigitkonur/hooks-claude-code.git /tmp/claude-plan-hook \
  && bash /tmp/claude-plan-hook/install.sh \
  && rm -rf /tmp/claude-plan-hook
```

requires `jq` (`brew install jq` / `apt install jq`). installer is idempotent — re-run to switch modes.

## how it works

hooks into Claude Code's `PermissionRequest` event with matcher `ExitPlanMode`. the hook script:

1. consumes stdin (required by hook protocol)
2. (modes 2 & 3) parses `.tool_input.plan` from the JSON payload
3. (modes 2 & 3) fires the Craft API call in a background subshell — zero blocking
4. (modes 1 & 2) prints the allow decision to stdout
5. Claude Code reads stdout, skips the dialog, starts implementing

the Craft publish runs in `( ... ) &` so approval latency is zero even on slow connections. all JSON is built inside `jq`, never via shell string concatenation — handles newlines, quotes, and unicode in plan text correctly.

## Craft setup

modes 2 and 3 need a Craft.do API URL and page ID. the installer prompts for both and writes them to `~/.claude/hooks/craft-config.env` (permissions `600`). edit that file directly to update credentials without re-running the installer.

each plan gets archived as a card-style subpage:

```
title:   [~/project/path] - [14:32 - 20-02-2026]
content: full plan markdown
```

the installer posts a connectivity test block during setup to verify credentials work.

## what gets installed

```
~/.claude/hooks/claude-plan-hook.sh    — the active hook script (one of three modes)
~/.claude/hooks/craft-config.env       — Craft credentials (modes 2 & 3 only)
~/.claude/settings.json                — hook registration merged via jq
```

the installer merges into `settings.json` without destroying existing hooks or settings.

## project structure

```
hooks-claude-code/
  install.sh                — interactive installer
  uninstall.sh              — uninstaller
  hooks/
    auto-approve-plan.sh    — mode 1: auto-approve only
    auto-approve-craft.sh   — mode 2: auto-approve + Craft archive
    craft-only.sh           — mode 3: Craft archive, manual approve
```

## uninstall

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/yigitkonur/hooks-claude-code/main/uninstall.sh)
```

or manually:

```bash
rm ~/.claude/hooks/claude-plan-hook.sh
rm ~/.claude/hooks/craft-config.env
# then remove the ExitPlanMode entry from ~/.claude/settings.json
```

## why not hook the Stop event?

earlier approaches tried hooking `Stop` and grepping the conversation transcript. that doesn't work — the approval dialog fires while Claude is paused waiting for input, not in a stopped state. the correct hook point is `PermissionRequest` with matcher `ExitPlanMode`.

## license

MIT
