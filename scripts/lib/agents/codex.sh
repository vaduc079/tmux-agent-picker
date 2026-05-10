#!/usr/bin/env bash

[[ -n "${_AGENT_PICKER_AGENT_CODEX_LIB:-}" ]] && return 0
_AGENT_PICKER_AGENT_CODEX_LIB=1

agent_picker_codex_status_for_event() {
    case "$1" in
        SessionStart|Stop)
            printf 'idle\n'
            ;;
        UserPromptSubmit|PreToolUse|PostToolUse)
            printf 'running\n'
            ;;
        PermissionRequest)
            printf 'wait\n'
            ;;
        *)
            return 1
            ;;
    esac
}

agent_picker_adapter_normalize() {
    local event="$1"
    local status=""

    status=$(agent_picker_codex_status_for_event "$event") || return 1
    AGENT_PICKER_UPDATE_STATUS="$status"
    AGENT_PICKER_UPDATE_SESSION_ID="$AGENT_PICKER_PAYLOAD_SESSION_ID"
    AGENT_PICKER_UPDATE_CWD="$AGENT_PICKER_PAYLOAD_CWD"
    AGENT_PICKER_UPDATE_TITLE_HINT="$AGENT_PICKER_PAYLOAD_TITLE_HINT"
}
