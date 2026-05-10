#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmux_bin="${AGENT_PICKER_TMUX_BIN:-$(command -v tmux 2>/dev/null || printf 'tmux')}"
fzf_bin="${AGENT_PICKER_FZF_BIN:-$(command -v fzf 2>/dev/null || printf 'fzf')}"

tmux_cmd() {
    "$tmux_bin" "$@"
}

default_picker_key="A"
default_window_name="agent-picker"

picker_key=$(tmux_cmd show-option -gqv "@agent-picker-key")
window_name=$(tmux_cmd show-option -gqv "@agent-picker-window-name")

[ -n "$picker_key" ] || picker_key="$default_picker_key"
[ -n "$window_name" ] || window_name="$default_window_name"

tmux_cmd bind-key "$picker_key" new-window -n "$window_name" "AGENT_PICKER_TMUX_BIN=$tmux_bin AGENT_PICKER_FZF_BIN=$fzf_bin $CURRENT_DIR/scripts/picker.sh"

collector_cmd="$CURRENT_DIR/scripts/tmux-collector.sh --once"
collector_cmd="AGENT_PICKER_TMUX_BIN=$tmux_bin $collector_cmd"

set_collector_hook() {
    local hook_name="$1"

    if tmux_cmd show-hooks -g "$hook_name" 2>/dev/null | grep -F -- "$collector_cmd" >/dev/null 2>&1; then
        return 0
    fi

    tmux_cmd set-hook -ga "$hook_name" "run-shell -b '$collector_cmd'"
}

set_collector_hook session-created
set_collector_hook session-closed
set_collector_hook session-renamed
set_collector_hook after-new-window
set_collector_hook after-rename-window
set_collector_hook after-split-window
set_collector_hook after-kill-pane
set_collector_hook pane-exited
set_collector_hook after-resize-pane
set_collector_hook after-select-layout
set_collector_hook window-layout-changed
set_collector_hook window-pane-changed
set_collector_hook window-linked
set_collector_hook window-unlinked
set_collector_hook client-attached
set_collector_hook client-detached
set_collector_hook client-session-changed
set_collector_hook after-select-pane
set_collector_hook after-select-window

AGENT_PICKER_TMUX_BIN="$tmux_bin" "$CURRENT_DIR/scripts/tmux-collector.sh" --once >/dev/null 2>&1 || true
