#!/usr/bin/env bash

set -euo pipefail

fail() {
    printf 'not ok - %s\n' "$*" >&2
    exit 1
}

assert_eq() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    if [ "$expected" != "$actual" ]; then
        fail "$message: expected '$expected', got '$actual'"
    fi
}

assert_file_exists() {
    local path="$1"
    [ -f "$path" ] || fail "expected file to exist: $path"
}

make_temp_dir() {
    mktemp -d "${TMPDIR:-/tmp}/tmux-agent-picker-test.XXXXXX"
}

