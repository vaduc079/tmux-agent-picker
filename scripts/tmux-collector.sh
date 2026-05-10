#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/cache.sh
source "$SCRIPT_DIR/lib/cache.sh"

agent_picker_init_cache
agent_picker_lock cache
trap 'agent_picker_unlock' EXIT

if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

if ! agent_picker_tmux_cmd list-sessions >/dev/null 2>&1; then
    printf '{}\n' | agent_picker_atomic_write "$TMUX_PANES_JSON"
    : > "$PICKER_TSV"
    exit 0
fi

FORMAT='#{session_id}	#{session_name}	#{window_id}	#{window_index}	#{window_name}	#{pane_id}	#{pane_index}	#{pane_current_path}	#{pane_current_command}	#{pane_title}'
PANE_LINES=$(agent_picker_tmux_cmd list-panes -a -F "$FORMAT" 2>/dev/null || true)
NOW=$(date +%s)

printf '%s\n' "$PANE_LINES" | jq -Rn '
  reduce inputs as $line ({};
    if $line == "" then .
    else
      ($line | split("\t")) as $p |
      .[$p[5]] = {
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
    end
  )
' | agent_picker_atomic_write "$TMUX_PANES_JSON"

jq --slurpfile panes "$TMUX_PANES_JSON" --argjson now "$NOW" '
  def display_title($agent; $pane):
    ($pane.pane_title // "") as $pane_title |
    ($pane.pane_current_command // "") as $pane_command |
    ($pane.window_name // "") as $window_name |
    ($agent.display_title_hint // "") as $title_hint |
    ($agent.agent_session_id // "") as $session_id |
    if ($pane_title != "" and $pane_title != $pane_command and $pane_title != "zsh" and $pane_title != "bash" and $pane_title != "fish") then
      $pane_title
    elif $window_name != "" then
      $window_name
    elif $title_hint != "" then
      $title_hint
    else
      $session_id
    end;

  def shell_foreground_command($command):
    ["sh", "bash", "zsh", "fish", "nu", "pwsh", "tmux"] | index($command);

  def codex_foreground_command($command):
    ($command // "") | startswith("codex");

  def agent_process_exited($agent; $pane):
    ($agent.agent_type // "") as $agent_type |
    ($pane.pane_current_command // "") as $pane_command |
    if $agent_type == "codex" then
      shell_foreground_command($pane_command)
    else
      false
    end;

  def has_agent_for_pane($pane_id):
    any(.[]?; (.tmux.pane_id // "") == $pane_id);

  def discover_codex_panes($pane_map; $now):
    reduce ($pane_map | to_entries[]) as $entry (.;
      ($entry.value // {}) as $pane |
      ($pane.pane_id // "") as $pane_id |
      ($pane.pane_current_command // "") as $pane_command |
      ("codex:" + $pane_id) as $id |
      if $pane_id != "" and codex_foreground_command($pane_command) and (has_agent_for_pane($pane_id) | not) then
        .[$id] = {
          id: $id,
          agent_type: "codex",
          agent_session_id: $pane_id,
          status: "idle",
          source_event: "tmux-collector",
          created_at: $now,
          updated_at: $now,
          last_seen_at: $now,
          stale: false,
          cwd: ($pane.pane_current_path // ""),
          display_title: display_title({agent_session_id: $pane_id}; $pane),
          tmux: {
            session_id: ($pane.session_id // ""),
            session_name: ($pane.session_name // ""),
            window_id: ($pane.window_id // ""),
            window_index: ($pane.window_index // ""),
            window_name: ($pane.window_name // ""),
            pane_id: ($pane.pane_id // ""),
            pane_index: ($pane.pane_index // "")
          }
        }
      else
        .
      end
    );

  def prune_duplicate_panes:
    reduce (to_entries | sort_by([(.value._dedupe_rank // .value.updated_at // 0), .key]))[] as $entry
      ({records: ., keep_by_pane: {}};
        ($entry.value.tmux.pane_id // "") as $pane_id |
        if $pane_id == "" then
          .
        elif .keep_by_pane[$pane_id] then
          (.keep_by_pane[$pane_id]) as $old_id |
          del(.records[$old_id]) |
          .keep_by_pane[$pane_id] = $entry.key
        else
          .keep_by_pane[$pane_id] = $entry.key
        end
      )
    | .records
    | map_values(del(._dedupe_rank));

  ($panes[0] // {}) as $pane_map |
  (reduce (keys[]) as $id (.;
    .[$id] as $agent |
    ($agent.tmux.pane_id // "") as $pane_id |
    ($pane_map[$pane_id] // null) as $pane |
    if $pane == null or agent_process_exited($agent; $pane) then
      del(.[$id])
    else
      .[$id] = ($agent + {
        stale: false,
        _dedupe_rank: ($agent.updated_at // 0),
        last_seen_at: $now,
        updated_at: $now,
        cwd: (($agent.cwd // "") as $cwd | if $cwd != "" then $cwd else ($pane.pane_current_path // "") end),
        display_title: display_title($agent; $pane),
        tmux: {
          session_id: ($pane.session_id // ""),
          session_name: ($pane.session_name // ""),
          window_id: ($pane.window_id // ""),
          window_index: ($pane.window_index // ""),
          window_name: ($pane.window_name // ""),
          pane_id: ($pane.pane_id // ""),
          pane_index: ($pane.pane_index // "")
        }
      })
    end
  ))
  | prune_duplicate_panes
  | discover_codex_panes($pane_map; $now)
' "$AGENTS_JSON" | agent_picker_atomic_write "$AGENTS_JSON"

jq -r '
  def status_label($status):
    if $status == "idle" then "🟢 idle"
    elif $status == "running" then "🔵 running"
    elif $status == "wait" then "🟡 wait"
    elif $status == "error" then "🔴 error"
    else "⚪ " + $status
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

  to_entries[]
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
