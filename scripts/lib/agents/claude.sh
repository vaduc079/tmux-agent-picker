#!/usr/bin/env bash

[[ -n "${_AGENT_PICKER_AGENT_CLAUDE_LIB:-}" ]] && return 0
_AGENT_PICKER_AGENT_CLAUDE_LIB=1

agent_picker_claude_status_for_event() {
    local event="$1"
    local notification_type="${2:-}"

    case "$event" in
        SessionStart|Stop)
            printf 'idle\n'
            ;;
        UserPromptSubmit|PreToolUse)
            printf 'running\n'
            ;;
        StopFailure)
            printf 'error\n'
            ;;
        PermissionRequest)
            printf 'wait\n'
            ;;
        Notification)
            case "$notification_type" in
                permission_prompt|elicitation_dialog)
                    printf 'wait\n'
                    ;;
                *)
                    return 1
                    ;;
            esac
            ;;
        *)
            return 1
            ;;
    esac
}

agent_picker_adapter_normalize() {
    local event="$1"
    local status=""

    AGENT_PICKER_UPDATE_ACTION="upsert"
    if [ "$event" = "SessionEnd" ]; then
        AGENT_PICKER_UPDATE_ACTION="delete"
        AGENT_PICKER_UPDATE_STATUS="idle"
        AGENT_PICKER_UPDATE_SESSION_ID="$AGENT_PICKER_PAYLOAD_SESSION_ID"
        AGENT_PICKER_UPDATE_CWD="$AGENT_PICKER_PAYLOAD_CWD"
        AGENT_PICKER_UPDATE_TITLE_HINT=""
        return 0
    fi

    status=$(agent_picker_claude_status_for_event "$event" "$AGENT_PICKER_PAYLOAD_NOTIFICATION_TYPE") || return 1
    AGENT_PICKER_UPDATE_STATUS="$status"
    AGENT_PICKER_UPDATE_SESSION_ID="$AGENT_PICKER_PAYLOAD_SESSION_ID"
    AGENT_PICKER_UPDATE_CWD="$AGENT_PICKER_PAYLOAD_CWD"
    AGENT_PICKER_UPDATE_TITLE_HINT="$AGENT_PICKER_PAYLOAD_TITLE_HINT"
}
