#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/test-helpers.sh"
source "$ROOT_DIR/scripts/lib/agents/generic.sh"

source "$ROOT_DIR/scripts/lib/agents/claude.sh"
assert_eq "idle" "$(agent_picker_claude_status_for_event SessionStart '{}')" "Claude SessionStart maps to idle"
assert_eq "running" "$(agent_picker_claude_status_for_event UserPromptSubmit '{}')" "Claude UserPromptSubmit maps to running"
assert_eq "wait" "$(agent_picker_claude_status_for_event PermissionRequest '{}')" "Claude PermissionRequest maps to wait"
assert_eq "wait" "$(agent_picker_claude_status_for_event Notification permission_prompt)" "Claude permission notification maps to wait"
if agent_picker_claude_status_for_event Notification idle_prompt >/dev/null 2>&1; then
    fail "Claude idle_prompt should not change status"
fi
AGENT_PICKER_PAYLOAD_SESSION_ID="abc"
AGENT_PICKER_PAYLOAD_CWD=""
AGENT_PICKER_PAYLOAD_TITLE_HINT=""
AGENT_PICKER_PAYLOAD_NOTIFICATION_TYPE=""
agent_picker_adapter_normalize SessionEnd
assert_eq "delete" "$AGENT_PICKER_UPDATE_ACTION" "Claude SessionEnd deletes agent"
unset -f agent_picker_adapter_normalize

source "$ROOT_DIR/scripts/lib/agents/codex.sh"
assert_eq "idle" "$(agent_picker_codex_status_for_event SessionStart)" "Codex SessionStart maps to idle"
assert_eq "running" "$(agent_picker_codex_status_for_event PostToolUse)" "Codex PostToolUse maps to running"
assert_eq "wait" "$(agent_picker_codex_status_for_event PermissionRequest)" "Codex PermissionRequest maps to wait"

prompt_payload='{"prompt":"Implement cache helpers\nwith tests","session_id":"abc","cwd":"/tmp/repo"}'
fields=$(agent_picker_parse_payload_fields "$prompt_payload")
IFS=$'\037' read -r session_id cwd title_hint _ <<< "$fields"
assert_eq "abc" "$session_id" "payload parser extracts session id"
assert_eq "/tmp/repo" "$cwd" "payload parser extracts cwd"
assert_eq "Implement cache helpers" "$title_hint" "short prompt uses first line"

fields=$(agent_picker_parse_payload_fields '{"session_id":"abc"}')
IFS=$'\037' read -r session_id _ title_hint _ <<< "$fields"
assert_eq "abc" "$session_id" "payload parser handles missing optional fields"
assert_eq "" "$title_hint" "short prompt tolerates missing prompt"

fields=$(agent_picker_parse_payload_fields '{"cwd":"/tmp/no-session"}')
IFS=$'\037' read -r session_id cwd _ _ <<< "$fields"
assert_eq "" "$session_id" "payload parser preserves missing leading session id"
assert_eq "/tmp/no-session" "$cwd" "payload parser keeps cwd when session id is missing"

printf 'ok - agent adapters\n'
