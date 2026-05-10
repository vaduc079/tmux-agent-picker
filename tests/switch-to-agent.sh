#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/test-helpers.sh"

TMP_DIR=$(make_temp_dir)
trap 'rm -rf "$TMP_DIR"' EXIT

FAKE_BIN="$TMP_DIR/bin"
TMUX_LOG="$TMP_DIR/tmux.log"
mkdir -p "$FAKE_BIN"

cat > "$FAKE_BIN/tmux" <<'FAKE_TMUX'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_TMUX_LOG"
case "$1" in
    display-message)
        printf '%%1\n'
        exit 0
        ;;
    switch-client|select-window|select-pane)
        exit 0
        ;;
esac
exit 1
FAKE_TMUX
chmod +x "$FAKE_BIN/tmux"

export PATH="$FAKE_BIN:$PATH"
export FAKE_TMUX_LOG="$TMUX_LOG"
export AGENT_PICKER_CACHE_DIR="$TMP_DIR/cache"

mkdir -p "$AGENT_PICKER_CACHE_DIR"
cat > "$AGENT_PICKER_CACHE_DIR/agents.json" <<'JSON'
{
  "codex:abc123": {
    "id": "codex:abc123",
    "agent_type": "codex",
    "agent_session_id": "abc123",
    "status": "idle",
    "tmux": {
      "session_id": "$1",
      "window_id": "@1",
      "pane_id": "%1"
    },
    "stale": false
  }
}
JSON
printf '{}\n' > "$AGENT_PICKER_CACHE_DIR/tmux-panes.json"
: > "$AGENT_PICKER_CACHE_DIR/picker.tsv"

"$ROOT_DIR/scripts/switch-to-agent.sh" "codex:abc123"

grep -Fq 'switch-client -t $1' "$TMUX_LOG" || fail "switch-client should target session id"
grep -Fq 'select-window -t @1' "$TMUX_LOG" || fail "select-window should target window id"
grep -Fq 'select-pane -t %1' "$TMUX_LOG" || fail "select-pane should target pane id"

printf 'ok - switch to agent\n'

