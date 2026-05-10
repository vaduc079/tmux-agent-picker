#!/usr/bin/env bash

[[ -n "${_AGENT_PICKER_AGENT_GENERIC_LIB:-}" ]] && return 0
_AGENT_PICKER_AGENT_GENERIC_LIB=1

agent_picker_parse_payload_fields() {
    local payload="$1"

    jq -r '
      def short_prompt:
        ((.prompt // "") | tostring | split("\n") | .[0] // "")
        | gsub("[\t\r]"; " ")
        | if length > 80 then .[0:77] + "..." else . end;

      [
        (.session_id // ""),
        (.cwd // ""),
        short_prompt,
        (.notification_type // "")
      ]
      | join("\u001f")
    ' <<< "$payload" 2>/dev/null
}
