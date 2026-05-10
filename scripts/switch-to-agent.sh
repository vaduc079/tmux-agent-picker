#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/cache.sh
source "$SCRIPT_DIR/lib/cache.sh"
# shellcheck source=lib/tmux.sh
source "$SCRIPT_DIR/lib/tmux.sh"

AGENT_ID="${1:-}"
[ -n "$AGENT_ID" ] || exit 0

agent_picker_init_cache

TARGET_JSON=$(jq -c --arg id "$AGENT_ID" '.[$id] // empty' "$AGENTS_JSON" 2>/dev/null || true)
[ -n "$TARGET_JSON" ] || exit 0

PANE_ID=$(jq -r '.tmux.pane_id // empty' <<< "$TARGET_JSON")
WINDOW_ID=$(jq -r '.tmux.window_id // empty' <<< "$TARGET_JSON")
SESSION_ID=$(jq -r '.tmux.session_id // empty' <<< "$TARGET_JSON")

if ! agent_picker_tmux_has_pane "$PANE_ID"; then
    "$SCRIPT_DIR/tmux-collector.sh" --once >/dev/null 2>&1 || true
    exit 1
fi

agent_picker_switch_to_pane "$SESSION_ID" "$WINDOW_ID" "$PANE_ID"

