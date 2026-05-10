#!/usr/bin/env bash

# Output from Claude/Codex hooks can affect agent behavior. Keep this script
# silent in normal operation and exit successfully on best-effort failures.

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

AGENT_TYPE="${1:-}"
EVENT_NAME="${2:-}"
PAYLOAD=$(cat 2>/dev/null || true)

[ -n "$PAYLOAD" ] || PAYLOAD="{}"

if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

if ! jq -e . >/dev/null 2>&1 <<< "$PAYLOAD"; then
    PAYLOAD="{}"
fi

# shellcheck source=lib/cache.sh
source "$LIB_DIR/cache.sh" || exit 0
# shellcheck source=lib/tmux.sh
source "$LIB_DIR/tmux.sh" || exit 0
# shellcheck source=lib/agents/generic.sh
source "$LIB_DIR/agents/generic.sh" || exit 0

case "$AGENT_TYPE" in
    claude|codex)
        # shellcheck source=/dev/null
        source "$LIB_DIR/agents/$AGENT_TYPE.sh" || exit 0
        ;;
    *)
        exit 0
        ;;
esac

PAYLOAD_FIELDS=$(agent_picker_parse_payload_fields "$PAYLOAD") || PAYLOAD_FIELDS=$'\037\037\037'
IFS=$'\037' read -r \
    AGENT_PICKER_PAYLOAD_SESSION_ID \
    AGENT_PICKER_PAYLOAD_CWD \
    AGENT_PICKER_PAYLOAD_TITLE_HINT \
    AGENT_PICKER_PAYLOAD_NOTIFICATION_TYPE \
    <<< "$PAYLOAD_FIELDS"

agent_picker_adapter_normalize "$EVENT_NAME" || exit 0

agent_picker_init_cache || exit 0
agent_picker_lock cache || exit 0
trap 'agent_picker_unlock' EXIT

PANE_ID=$(agent_picker_current_pane_id 2>/dev/null || true)
PANE_JSON="{}"
if [ -n "$PANE_ID" ]; then
    PANE_JSON=$(agent_picker_pane_json "$PANE_ID" 2>/dev/null || printf '{}')
fi

NOW=$(date +%s)
SESSION_KEY="$AGENT_PICKER_UPDATE_SESSION_ID"
[ -n "$SESSION_KEY" ] || SESSION_KEY="$PANE_ID"
[ -n "$SESSION_KEY" ] || exit 0

AGENT_ID="$AGENT_TYPE:$SESSION_KEY"
UPDATE_ACTION="${AGENT_PICKER_UPDATE_ACTION:-upsert}"

if [ "$UPDATE_ACTION" = "delete" ]; then
    jq \
      --arg id "$AGENT_ID" \
      --arg agent_type "$AGENT_TYPE" \
      --arg pane_id "$PANE_ID" '
        del(.[$id])
        | if $pane_id != "" then
            with_entries(
              select(
                ((.value.agent_type // "") != $agent_type)
                or ((.value.tmux.pane_id // "") != $pane_id)
              )
            )
          else
            .
          end
      ' "$AGENTS_JSON" | agent_picker_atomic_write "$AGENTS_JSON"
    exit 0
fi

jq \
  --arg id "$AGENT_ID" \
  --arg agent_type "$AGENT_TYPE" \
  --arg agent_session_id "$SESSION_KEY" \
  --arg event_name "$EVENT_NAME" \
  --arg status "$AGENT_PICKER_UPDATE_STATUS" \
  --arg cwd "$AGENT_PICKER_UPDATE_CWD" \
  --arg title_hint "$AGENT_PICKER_UPDATE_TITLE_HINT" \
  --arg pane_id "$PANE_ID" \
  --argjson pane "$PANE_JSON" \
  --argjson now "$NOW" '
    if $pane_id != "" then
      with_entries(
        select(
          (.key == $id)
          or ((.value.agent_type // "") != $agent_type)
          or ((.value.tmux.pane_id // "") != $pane_id)
        )
      )
    else
      .
    end |
    .[$id] as $existing |
    .[$id] = (($existing // {}) + {
      id: $id,
      agent_type: $agent_type,
      agent_session_id: $agent_session_id,
      status: $status,
      source_event: $event_name,
      updated_at: $now,
      last_seen_at: $now,
      stale: false
    }) |
    .[$id].created_at = (($existing.created_at // $now)) |
    .[$id].cwd = (
      if $cwd != "" then $cwd
      elif ($pane.pane_current_path // "") != "" then $pane.pane_current_path
      else ($existing.cwd // "")
      end
    ) |
    .[$id].display_title_hint = (
      if $title_hint != "" then $title_hint
      else ($existing.display_title_hint // "")
      end
    ) |
    .[$id].tmux = (
      if ($pane | length) > 0 then {
        session_id: ($pane.session_id // ""),
        session_name: ($pane.session_name // ""),
        window_id: ($pane.window_id // ""),
        window_index: ($pane.window_index // ""),
        window_name: ($pane.window_name // ""),
        pane_id: ($pane.pane_id // ""),
        pane_index: ($pane.pane_index // "")
      } else ($existing.tmux // {}) end
    )
  ' "$AGENTS_JSON" | agent_picker_atomic_write "$AGENTS_JSON"

exit 0
