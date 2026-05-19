#!/usr/bin/env bash

[[ -n "${_AGENT_PICKER_PICKER_INDEX_LIB:-}" ]] && return 0
_AGENT_PICKER_PICKER_INDEX_LIB=1

agent_picker_rebuild_picker_tsv() {
    jq -r '
      def status_label($status):
        if $status == "idle" then "🟢 idle"
        elif $status == "running" then "🔵 running"
        elif $status == "wait" then "🟡 wait"
        elif $status == "error" then "🔴 error"
        else "⚪ " + $status
        end;

      def status_rank($status):
        if $status == "running" then 0
        elif $status == "idle" then 1
        elif $status == "wait" then 2
        elif $status == "error" then 3
        else 4
        end;

      def compact_cwd($cwd):
        ($cwd // "") as $path |
        if $path == "" then
          ""
        else
          ($path | split("/") | map(select(. != ""))) as $parts |
          if ($parts | length) <= 2 then
            $path
          else
            ".../" + ($parts[-2:] | join("/"))
          end
        end;

      to_entries
      | sort_by([
          status_rank(.value.status // "idle"),
          (.value.agent_type // "agent"),
          (.value.display_title // .value.display_title_hint // .value.agent_session_id // .value.id),
          .key
        ])
      | .[]
      | select(.value.stale != true)
      | .value as $agent
      | ($agent.status // "idle") as $status
      | ($agent.cwd // "") as $cwd
      | [
          $agent.id,
          status_label($status),
          ($agent.agent_type // "agent"),
          ($agent.display_title // $agent.display_title_hint // $agent.agent_session_id // $agent.id),
          compact_cwd($cwd),
          (($agent.tmux.session_name // "?") + ":" + ($agent.tmux.window_index // "?") + "." + ($agent.tmux.pane_index // "?"))
        ]
      | @tsv
    ' "$AGENTS_JSON" | agent_picker_atomic_write "$PICKER_TSV"
}
