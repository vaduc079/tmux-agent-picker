#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/test-helpers.sh"

TMP_DIR=$(make_temp_dir)
trap 'rm -rf "$TMP_DIR"' EXIT

FAKE_BIN="$TMP_DIR/bin"
mkdir -p "$FAKE_BIN"

cat > "$FAKE_BIN/tmux" <<'FAKE_TMUX'
#!/usr/bin/env bash
case "$1" in
    list-sessions)
        exit 0
        ;;
    list-panes)
        if [ "${FAKE_TMUX_EMPTY:-0}" = "1" ]; then
            exit 0
        fi
        printf '$1\tsess\t@1\t0\twork\t%%1\t0\t/Users/duc.vu/projects/personal/tmux-agent-picker\t%s\tAgent Pane\n' "${FAKE_TMUX_COMMAND:-codex}"
        exit 0
        ;;
esac
exit 1
FAKE_TMUX
chmod +x "$FAKE_BIN/tmux"

export PATH="$FAKE_BIN:$PATH"
export AGENT_PICKER_CACHE_DIR="$TMP_DIR/cache"

mkdir -p "$AGENT_PICKER_CACHE_DIR"
cat > "$AGENT_PICKER_CACHE_DIR/agents.json" <<'JSON'
{
  "codex:abc123": {
    "id": "codex:abc123",
    "agent_type": "codex",
    "agent_session_id": "abc123",
    "status": "running",
    "cwd": "/Users/duc.vu/projects/personal/tmux-agent-picker",
    "tmux": {
      "pane_id": "%1"
    },
    "created_at": 1,
    "updated_at": 1,
    "last_seen_at": 1,
    "stale": false
  },
  "codex:old": {
    "id": "codex:old",
    "agent_type": "codex",
    "agent_session_id": "old",
    "status": "idle",
    "cwd": "/Users/duc.vu/projects/personal/tmux-agent-picker",
    "tmux": {
      "pane_id": "%1"
    },
    "created_at": 0,
    "updated_at": 0,
    "last_seen_at": 0,
    "stale": false
  }
}
JSON

"$ROOT_DIR/scripts/tmux-collector.sh" --once

assert_eq "false" "$(jq -r '."codex:abc123".stale' "$AGENT_PICKER_CACHE_DIR/agents.json")" "live pane is not stale"
assert_eq "Agent Pane" "$(jq -r '."codex:abc123".display_title' "$AGENT_PICKER_CACHE_DIR/agents.json")" "collector derives display title"
assert_eq "null" "$(jq -r '."codex:old" // null' "$AGENT_PICKER_CACHE_DIR/agents.json")" "collector prunes duplicate pane records"

picker_line=$(cat "$AGENT_PICKER_CACHE_DIR/picker.tsv")
case "$picker_line" in
    *$'codex:abc123	🔵 running	codex	Agent Pane	.../personal/tmux-agent-picker	sess:0.0'*)
        ;;
    *)
        fail "picker row should include live agent: $picker_line"
        ;;
esac

export FAKE_TMUX_COMMAND=zsh
"$ROOT_DIR/scripts/tmux-collector.sh" --once

assert_eq "null" "$(jq -r '."codex:abc123" // null' "$AGENT_PICKER_CACHE_DIR/agents.json")" "collector prunes exited Codex process"
assert_eq "" "$(cat "$AGENT_PICKER_CACHE_DIR/picker.tsv")" "exited Codex process is removed from picker"

printf '{}\n' > "$AGENT_PICKER_CACHE_DIR/agents.json"
export FAKE_TMUX_COMMAND=codex-aarch64-a
"$ROOT_DIR/scripts/tmux-collector.sh" --once

assert_eq "idle" "$(jq -r '."codex:%1".status' "$AGENT_PICKER_CACHE_DIR/agents.json")" "collector discovers live Codex pane"
assert_eq "%1" "$(jq -r '."codex:%1".tmux.pane_id' "$AGENT_PICKER_CACHE_DIR/agents.json")" "discovered Codex pane keeps pane id"

cat > "$AGENT_PICKER_CACHE_DIR/agents.json" <<'JSON'
{
  "codex:abc123": {
    "id": "codex:abc123",
    "agent_type": "codex",
    "agent_session_id": "abc123",
    "status": "running",
    "cwd": "/Users/duc.vu/projects/personal/tmux-agent-picker",
    "tmux": {
      "pane_id": "%1"
    },
    "created_at": 1,
    "updated_at": 1,
    "last_seen_at": 1,
    "stale": false
  }
}
JSON

export FAKE_TMUX_EMPTY=1
"$ROOT_DIR/scripts/tmux-collector.sh" --once

assert_eq "null" "$(jq -r '."codex:abc123" // null' "$AGENT_PICKER_CACHE_DIR/agents.json")" "missing pane is pruned"
assert_eq "" "$(cat "$AGENT_PICKER_CACHE_DIR/picker.tsv")" "stale pane is removed from picker"

printf 'ok - collector\n'
