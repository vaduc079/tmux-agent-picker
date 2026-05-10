#!/usr/bin/env bash

[[ -n "${_AGENT_PICKER_TMUX_LIB:-}" ]] && return 0
_AGENT_PICKER_TMUX_LIB=1

if ! declare -F agent_picker_tmux_cmd >/dev/null 2>&1; then
    agent_picker_tmux_cmd() {
        "${AGENT_PICKER_TMUX_BIN:-tmux}" "$@"
    }
fi

agent_picker_tmux_has_pane() {
    local pane_id="$1"
    [ -n "$pane_id" ] || return 1
    agent_picker_tmux_cmd display-message -p -t "$pane_id" "#{pane_id}" >/dev/null 2>&1
}

agent_picker_current_pane_id() {
    if [ -n "${TMUX_PANE:-}" ]; then
        printf '%s\n' "$TMUX_PANE"
        return 0
    fi

    agent_picker_tmux_cmd display-message -p "#{pane_id}" 2>/dev/null
}

agent_picker_pane_json() {
    local pane_id="$1"
    local format
    local line

    [ -n "$pane_id" ] || return 1

    format='#{session_id}	#{session_name}	#{window_id}	#{window_index}	#{window_name}	#{pane_id}	#{pane_index}	#{pane_current_path}	#{pane_current_command}	#{pane_title}'
    line=$(agent_picker_tmux_cmd display-message -p -t "$pane_id" "$format" 2>/dev/null) || return 1

    AGENT_PICKER_TMUX_LINE="$line" jq -Rn '
      (env.AGENT_PICKER_TMUX_LINE | split("\t")) as $p |
      {
        session_id: $p[0],
        session_name: $p[1],
        window_id: $p[2],
        window_index: $p[3],
        window_name: $p[4],
        pane_id: $p[5],
        pane_index: $p[6],
        pane_current_path: $p[7],
        pane_current_command: $p[8],
        pane_title: $p[9]
      }
    '
}

agent_picker_switch_to_pane() {
    local session_id="$1"
    local window_id="$2"
    local pane_id="$3"

    [ -n "$pane_id" ] || return 1
    agent_picker_tmux_has_pane "$pane_id" || return 1

    if [ -n "$session_id" ]; then
        agent_picker_tmux_cmd switch-client -t "$session_id" 2>/dev/null || true
    fi

    if [ -n "$window_id" ]; then
        agent_picker_tmux_cmd select-window -t "$window_id" 2>/dev/null || true
    fi

    agent_picker_tmux_cmd select-pane -t "$pane_id"
}
