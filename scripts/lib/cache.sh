#!/usr/bin/env bash

[[ -n "${_AGENT_PICKER_CACHE_LIB:-}" ]] && return 0
_AGENT_PICKER_CACHE_LIB=1

agent_picker_tmux_cmd() {
    "${AGENT_PICKER_TMUX_BIN:-tmux}" "$@"
}

agent_picker_cache_dir() {
    if [ -n "${AGENT_PICKER_CACHE_DIR:-}" ]; then
        agent_picker_expand_path "$AGENT_PICKER_CACHE_DIR"
        return 0
    fi

    local tmux_cache_dir=""
    tmux_cache_dir=$(agent_picker_tmux_cmd show-option -gqv "@agent-picker-cache-dir" 2>/dev/null || true)
    if [ -n "$tmux_cache_dir" ]; then
        agent_picker_expand_path "$tmux_cache_dir"
        return 0
    fi

    if [ -n "${XDG_CACHE_HOME:-}" ]; then
        printf '%s/tmux-agent-picker\n' "$XDG_CACHE_HOME"
        return 0
    fi

    printf '%s/.cache/tmux-agent-picker\n' "$HOME"
}

agent_picker_expand_path() {
    case "$1" in
        "~")
            printf '%s\n' "$HOME"
            ;;
        "~/"*)
            printf '%s/%s\n' "$HOME" "${1#\~/}"
            ;;
        *)
            printf '%s\n' "$1"
            ;;
    esac
}

agent_picker_init_cache() {
    AGENT_PICKER_CACHE_DIR_RESOLVED=$(agent_picker_cache_dir)
    AGENTS_JSON="$AGENT_PICKER_CACHE_DIR_RESOLVED/agents.json"
    TMUX_PANES_JSON="$AGENT_PICKER_CACHE_DIR_RESOLVED/tmux-panes.json"
    PICKER_TSV="$AGENT_PICKER_CACHE_DIR_RESOLVED/picker.tsv"
    LOCK_DIR="$AGENT_PICKER_CACHE_DIR_RESOLVED/locks"

    mkdir -p "$AGENT_PICKER_CACHE_DIR_RESOLVED" "$LOCK_DIR"
    agent_picker_ensure_json_object "$AGENTS_JSON"
    agent_picker_ensure_json_object "$TMUX_PANES_JSON"
    [ -f "$PICKER_TSV" ] || : > "$PICKER_TSV"
}

agent_picker_ensure_json_object() {
    local path="$1"

    if [ ! -s "$path" ] || ! jq -e 'type == "object"' "$path" >/dev/null 2>&1; then
        printf '{}\n' > "$path"
    fi
}

agent_picker_atomic_write() {
    local path="$1"
    local tmp_path="${path}.tmp.$$"

    cat > "$tmp_path"
    mv -f "$tmp_path" "$path"
}

agent_picker_lock() {
    local name="${1:-cache}"
    local max_attempts="${2:-100}"
    local sleep_seconds="${3:-0.05}"
    local lock_path="$LOCK_DIR/$name.lock"
    local attempts=0

    while ! mkdir "$lock_path" 2>/dev/null; do
        attempts=$((attempts + 1))
        if agent_picker_lock_is_stale "$lock_path"; then
            rmdir "$lock_path" 2>/dev/null || true
            continue
        fi
        if [ "$attempts" -ge "$max_attempts" ]; then
            return 1
        fi
        sleep "$sleep_seconds"
    done

    AGENT_PICKER_HELD_LOCK="$lock_path"
}

agent_picker_try_lock() {
    agent_picker_lock "${1:-cache}" 0 0.05
}

agent_picker_lock_briefly() {
    agent_picker_lock "${1:-cache}" 4 0.05
}

agent_picker_lock_is_stale() {
    local lock_path="$1"
    local now=""
    local lock_mtime=""
    local max_age=30

    [ -d "$lock_path" ] || return 1

    now=$(date +%s)
    if [ "$(uname)" = "Darwin" ]; then
        lock_mtime=$(stat -f %m "$lock_path" 2>/dev/null || printf '')
    else
        lock_mtime=$(stat -c %Y "$lock_path" 2>/dev/null || printf '')
    fi

    [ -n "$lock_mtime" ] || return 1
    [ $((now - lock_mtime)) -gt "$max_age" ]
}

agent_picker_unlock() {
    if [ -n "${AGENT_PICKER_HELD_LOCK:-}" ]; then
        rmdir "$AGENT_PICKER_HELD_LOCK" 2>/dev/null || true
        AGENT_PICKER_HELD_LOCK=""
    fi
}
