#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmux_bin="${AGENT_PICKER_TMUX_BIN:-$(command -v tmux 2>/dev/null || printf 'tmux')}"
fzf_bin="${AGENT_PICKER_FZF_BIN:-$(command -v fzf 2>/dev/null || printf 'fzf')}"

tmux_cmd() {
    "$tmux_bin" "$@"
}

shell_quote() {
    printf '%q' "$1"
}

tmux_double_quote() {
    local value="$1"

    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    printf '"%s"' "$value"
}

default_picker_key="A"
default_window_name="agent-picker"

picker_key=$(tmux_cmd show-option -gqv "@agent-picker-key")
window_name=$(tmux_cmd show-option -gqv "@agent-picker-window-name")
cache_dir="${AGENT_PICKER_CACHE_DIR:-$(tmux_cmd show-option -gqv "@agent-picker-cache-dir")}"

[ -n "$picker_key" ] || picker_key="$default_picker_key"
[ -n "$window_name" ] || window_name="$default_window_name"

expand_path() {
    case "$1" in
        "~")
            printf '%s\n' "$HOME"
            ;;
        "~/"*)
            printf '%s/%s\n' "$HOME" "${1#\~/}"
            ;;
        *)
            printf '%s\n' "$1"
            ;;
    esac
}

if [ -n "$cache_dir" ]; then
    cache_dir=$(expand_path "$cache_dir")
elif [ -n "${XDG_CACHE_HOME:-}" ]; then
    cache_dir="$XDG_CACHE_HOME/tmux-agent-picker"
else
    cache_dir="$HOME/.cache/tmux-agent-picker"
fi

quoted_tmux_bin=$(shell_quote "$tmux_bin")
quoted_fzf_bin=$(shell_quote "$fzf_bin")
quoted_cache_dir=$(shell_quote "$cache_dir")
quoted_picker_script=$(shell_quote "$CURRENT_DIR/scripts/picker.sh")
quoted_collector_script=$(shell_quote "$CURRENT_DIR/scripts/tmux-collector.sh")

picker_cmd="AGENT_PICKER_TMUX_BIN=$quoted_tmux_bin AGENT_PICKER_FZF_BIN=$quoted_fzf_bin AGENT_PICKER_CACHE_DIR=$quoted_cache_dir $quoted_picker_script"
tmux_cmd bind-key "$picker_key" new-window -n "$window_name" "$picker_cmd"

collector_cmd="AGENT_PICKER_TMUX_BIN=$quoted_tmux_bin $quoted_collector_script --once"
quoted_collector_cmd=$(tmux_double_quote "$collector_cmd")
collector_hook_cmd="run-shell -b $quoted_collector_cmd"

set_collector_hook() {
    local hook_name="$1"

    if tmux_cmd show-hooks -g "$hook_name" 2>/dev/null | grep -F -- "$collector_hook_cmd" >/dev/null 2>&1; then
        return 0
    fi

    tmux_cmd set-hook -ga "$hook_name" "$collector_hook_cmd"
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

AGENT_PICKER_TMUX_BIN="$tmux_bin" AGENT_PICKER_CACHE_DIR="$cache_dir" "$CURRENT_DIR/scripts/tmux-collector.sh" --once --wait-lock >/dev/null 2>&1 || true
