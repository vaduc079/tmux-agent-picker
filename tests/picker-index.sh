#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/test-helpers.sh"
source "$ROOT_DIR/scripts/lib/cache.sh"
source "$ROOT_DIR/scripts/lib/picker-index.sh"

TMP_DIR=$(make_temp_dir)
trap 'rm -rf "$TMP_DIR"' EXIT

export AGENT_PICKER_CACHE_DIR="$TMP_DIR/cache"

agent_picker_init_cache

cat > "$AGENTS_JSON" <<'JSON'
{
  "codex:idle": {
    "id": "codex:idle",
    "agent_type": "codex",
    "agent_session_id": "idle",
    "status": "idle",
    "display_title": "Idle Codex",
    "tmux": {
      "session_name": "sess",
      "window_index": "1",
      "pane_index": "1"
    },
    "stale": false
  },
  "codex:running": {
    "id": "codex:running",
    "agent_type": "codex",
    "agent_session_id": "running",
    "status": "running",
    "display_title": "Running Codex",
    "tmux": {
      "session_name": "sess",
      "window_index": "1",
      "pane_index": "2"
    },
    "stale": false
  },
  "claude:running": {
    "id": "claude:running",
    "agent_type": "claude",
    "agent_session_id": "running",
    "status": "running",
    "display_title": "Running Claude",
    "tmux": {
      "session_name": "sess",
      "window_index": "1",
      "pane_index": "3"
    },
    "stale": false
  },
  "codex:wait": {
    "id": "codex:wait",
    "agent_type": "codex",
    "agent_session_id": "wait",
    "status": "wait",
    "display_title": "Waiting Codex",
    "tmux": {
      "session_name": "sess",
      "window_index": "1",
      "pane_index": "4"
    },
    "stale": false
  },
  "claude:idle": {
    "id": "claude:idle",
    "agent_type": "claude",
    "agent_session_id": "idle",
    "status": "idle",
    "display_title": "Idle Claude",
    "tmux": {
      "session_name": "sess",
      "window_index": "1",
      "pane_index": "5"
    },
    "stale": false
  }
}
JSON

agent_picker_rebuild_picker_tsv

actual_order=$(awk -F '\t' '{ print $1 }' "$PICKER_TSV")
expected_order=$'codex:wait\nclaude:idle\ncodex:idle\nclaude:running\ncodex:running'

assert_eq "$expected_order" "$actual_order" "picker index sorts rows by reversed status rank then agent type"

printf 'ok - picker index\n'
