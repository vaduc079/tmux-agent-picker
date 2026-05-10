#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/test-helpers.sh"

TMP_CACHE=$(make_temp_dir)
trap 'rm -rf "$TMP_CACHE"' EXIT

export AGENT_PICKER_CACHE_DIR="$TMP_CACHE/cache"
export TMUX_PANE="%1"

FAKE_BIN="$TMP_CACHE/bin"
mkdir -p "$FAKE_BIN"

cat > "$FAKE_BIN/tmux" <<'FAKE_TMUX'
#!/usr/bin/env bash
case "$1" in
    display-message)
        printf '$1\tsess\t@1\t0\twork\t%%1\t0\t/tmp/repo\tclaude\tClaude Pane\n'
        exit 0
        ;;
esac
exit 1
FAKE_TMUX
chmod +x "$FAKE_BIN/tmux"
export AGENT_PICKER_TMUX_BIN="$FAKE_BIN/tmux"

claude_start_payload='{"session_id":"claude-resume-1","cwd":"/tmp/claude-repo","hook_event_name":"SessionStart","source":"resume","model":"claude-sonnet-4-6"}'
output=$(printf '%s' "$claude_start_payload" | "$ROOT_DIR/scripts/agent-hook.sh" claude SessionStart)

assert_eq "" "$output" "Claude SessionStart hook should be output-silent"
assert_file_exists "$AGENT_PICKER_CACHE_DIR/agents.json"
assert_eq "idle" "$(jq -r '."claude:claude-resume-1".status' "$AGENT_PICKER_CACHE_DIR/agents.json")" "Claude SessionStart marks idle"
assert_eq "/tmp/claude-repo" "$(jq -r '."claude:claude-resume-1".cwd' "$AGENT_PICKER_CACHE_DIR/agents.json")" "Claude SessionStart stores cwd"

claude_resumed_payload='{"session_id":"claude-resume-2","cwd":"/tmp/claude-repo","hook_event_name":"SessionStart","source":"resume","model":"claude-sonnet-4-6"}'
output=$(printf '%s' "$claude_resumed_payload" | "$ROOT_DIR/scripts/agent-hook.sh" claude SessionStart)

assert_eq "" "$output" "Claude resumed SessionStart hook should be output-silent"
assert_eq "null" "$(jq -r '."claude:claude-resume-1" // null' "$AGENT_PICKER_CACHE_DIR/agents.json")" "Claude resume replaces old session for same pane"
assert_eq "%1" "$(jq -r '."claude:claude-resume-2".tmux.pane_id' "$AGENT_PICKER_CACHE_DIR/agents.json")" "Claude resume keeps pane ownership"

claude_end_payload='{"session_id":"claude-resume-2","cwd":"/tmp/claude-repo","hook_event_name":"SessionEnd","reason":"prompt_input_exit"}'
output=$(printf '%s' "$claude_end_payload" | "$ROOT_DIR/scripts/agent-hook.sh" claude SessionEnd)

assert_eq "" "$output" "Claude SessionEnd hook should be output-silent"
assert_eq "null" "$(jq -r '."claude:claude-resume-2" // null' "$AGENT_PICKER_CACHE_DIR/agents.json")" "Claude SessionEnd removes agent"

codex_start_payload='{"session_id":"codex-start-1","cwd":"/tmp/codex-repo","hook_event_name":"SessionStart","source":"startup","model":"gpt-5.2-codex"}'
output=$(printf '%s' "$codex_start_payload" | "$ROOT_DIR/scripts/agent-hook.sh" codex SessionStart)

assert_eq "" "$output" "Codex SessionStart hook should be output-silent"
assert_eq "idle" "$(jq -r '."codex:codex-start-1".status' "$AGENT_PICKER_CACHE_DIR/agents.json")" "Codex SessionStart marks idle"
assert_eq "/tmp/codex-repo" "$(jq -r '."codex:codex-start-1".cwd' "$AGENT_PICKER_CACHE_DIR/agents.json")" "Codex SessionStart stores cwd"

payload='{"session_id":"abc123","cwd":"/tmp/repo","hook_event_name":"UserPromptSubmit","prompt":"Build the picker\nwith tests"}'
output=$(printf '%s' "$payload" | "$ROOT_DIR/scripts/agent-hook.sh" codex UserPromptSubmit)

assert_eq "" "$output" "agent hook should be output-silent"
assert_file_exists "$AGENT_PICKER_CACHE_DIR/agents.json"

assert_eq "running" "$(jq -r '."codex:abc123".status' "$AGENT_PICKER_CACHE_DIR/agents.json")" "Codex prompt marks running"
assert_eq "/tmp/repo" "$(jq -r '."codex:abc123".cwd' "$AGENT_PICKER_CACHE_DIR/agents.json")" "Codex prompt stores cwd"
assert_eq "Build the picker" "$(jq -r '."codex:abc123".display_title_hint' "$AGENT_PICKER_CACHE_DIR/agents.json")" "Codex prompt stores short title hint"

printf 'ok - agent hook\n'
