#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/test-helpers.sh"
source "$ROOT_DIR/scripts/lib/cache.sh"

TMP_CACHE=$(make_temp_dir)
trap 'rm -rf "$TMP_CACHE"' EXIT

export AGENT_PICKER_CACHE_DIR="$TMP_CACHE/cache"
assert_eq "$TMP_CACHE/home/home-cache" "$(HOME="$TMP_CACHE/home" AGENT_PICKER_CACHE_DIR="~/home-cache" agent_picker_cache_dir)" "tilde cache path expands"

agent_picker_init_cache

assert_file_exists "$AGENTS_JSON"
assert_file_exists "$TMUX_PANES_JSON"
assert_file_exists "$PICKER_TSV"

assert_eq "{}" "$(jq -c . "$AGENTS_JSON")" "agents json starts as object"
assert_eq "{}" "$(jq -c . "$TMUX_PANES_JSON")" "tmux panes json starts as object"

printf '{"broken":' > "$AGENTS_JSON"
agent_picker_ensure_json_object "$AGENTS_JSON"
assert_eq "{}" "$(jq -c . "$AGENTS_JSON")" "malformed json is reset"

printf 'hello\n' | agent_picker_atomic_write "$PICKER_TSV"
assert_eq "hello" "$(cat "$PICKER_TSV")" "atomic write replaces file"

agent_picker_lock cache || fail "cache lock should be acquired"
[ -n "${AGENT_PICKER_HELD_LOCK:-}" ] || fail "held lock path should be set"
agent_picker_unlock
[ -z "${AGENT_PICKER_HELD_LOCK:-}" ] || fail "held lock path should be cleared"

mkdir "$LOCK_DIR/cache.lock"
touch -t 200001010000 "$LOCK_DIR/cache.lock"
agent_picker_lock cache || fail "stale cache lock should be recovered"
agent_picker_unlock

printf 'ok - cache helpers\n'
