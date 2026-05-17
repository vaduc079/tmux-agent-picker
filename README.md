# tmux-agent-picker

Event-driven tmux picker for Claude Code and Codex CLI agent panes.

`tmux-agent-picker` keeps a local cache of agent status from Claude/Codex hooks and tmux pane metadata from tmux hooks. Press the picker key to open an `fzf` list in a tmux popup, choose an agent, and jump to the pane that owns it.

## Requirements

- Bash
- tmux 3.x
- [fzf](https://github.com/junegunn/fzf)
- [jq](https://jqlang.github.io/jq/)
- Claude Code and/or Codex CLI with hooks enabled

Runtime cache defaults to:

```text
$XDG_CACHE_HOME/tmux-agent-picker
```

or:

```text
~/.cache/tmux-agent-picker
```

## Install

With TPM:

```tmux
set -g @plugin 'vaduc079/tmux-agent-picker'
```

Local development install:

```tmux
run-shell '/path/to/tmux-agent-picker/tmux-agent-picker.tmux'
```

Default binding:

```text
prefix + A
```

Configuration:

```tmux
set -g @agent-picker-key "A"
set -g @agent-picker-popup-width "50%"
set -g @agent-picker-popup-height "50%"
set -g @agent-picker-status-width "12"
set -g @agent-picker-agent-width "10"
set -g @agent-picker-title-width "auto"
set -g @agent-picker-cwd-width "auto"
set -g @agent-picker-tmux-width "auto"
set -g @agent-picker-cache-dir "~/.cache/tmux-agent-picker"
```

`status` and `agent` use fixed widths. `title`, `cwd`, and `tmux` default to dynamic widths based on the longest visible value in the current picker rows, capped so the rendered row fits the current popup/window width. Set any dynamic column option to a positive integer to use that value as a per-column maximum.

## Claude Code Hooks

Add command hooks that call the shared dispatcher:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.tmux/plugins/tmux-agent-picker/scripts/agent-hook.sh claude SessionStart"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.tmux/plugins/tmux-agent-picker/scripts/agent-hook.sh claude UserPromptSubmit"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.tmux/plugins/tmux-agent-picker/scripts/agent-hook.sh claude PreToolUse"
          }
        ]
      }
    ],
    "PermissionRequest": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.tmux/plugins/tmux-agent-picker/scripts/agent-hook.sh claude PermissionRequest"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "permission_prompt|elicitation_dialog|idle_prompt|auth_success|elicitation_complete|elicitation_response",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.tmux/plugins/tmux-agent-picker/scripts/agent-hook.sh claude Notification"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.tmux/plugins/tmux-agent-picker/scripts/agent-hook.sh claude Stop"
          }
        ]
      }
    ],
    "StopFailure": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.tmux/plugins/tmux-agent-picker/scripts/agent-hook.sh claude StopFailure"
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "matcher": "clear|resume|logout|prompt_input_exit|bypass_permissions_disabled|other",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.tmux/plugins/tmux-agent-picker/scripts/agent-hook.sh claude SessionEnd"
          }
        ]
      }
    ]
  }
}
```

## Codex Hooks

Enable Codex hooks in `~/.codex/config.toml`:

```toml
[features]
codex_hooks = true
```

Add hooks in `~/.codex/hooks.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.tmux/plugins/tmux-agent-picker/scripts/agent-hook.sh codex SessionStart"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.tmux/plugins/tmux-agent-picker/scripts/agent-hook.sh codex UserPromptSubmit"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.tmux/plugins/tmux-agent-picker/scripts/agent-hook.sh codex PreToolUse"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.tmux/plugins/tmux-agent-picker/scripts/agent-hook.sh codex PostToolUse"
          }
        ]
      }
    ],
    "PermissionRequest": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.tmux/plugins/tmux-agent-picker/scripts/agent-hook.sh codex PermissionRequest"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.tmux/plugins/tmux-agent-picker/scripts/agent-hook.sh codex Stop"
          }
        ]
      }
    ]
  }
}
```

Codex does not currently expose a session-exit hook. The tmux collector removes Codex entries when the pane remains open but its foreground command has returned to a shell after Codex exits.

Hooks only update tmux-agent-picker cache state. They intentionally produce no control output and should not change Claude or Codex behavior.

## Test

```bash
tests/run.sh
```
