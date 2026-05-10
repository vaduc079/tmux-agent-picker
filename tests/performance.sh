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
        count="${FAKE_TMUX_PANE_COUNT:-1}"
        pane=1
        while [ "$pane" -le "$count" ]; do
            printf '$1\tsess\t@%s\t%s\twork\t%%%s\t0\t/tmp/repo-%s\tcodex\tAgent %s\n' "$pane" "$pane" "$pane" "$pane" "$pane"
            pane=$((pane + 1))
        done
        exit 0
        ;;
    display-message)
        if [ "${FAKE_TMUX_FAIL_DISPLAY:-0}" = "1" ]; then
            exit 1
        fi
        printf '$1\tsess\t@1\t1\twork\t%%1\t0\t/tmp/repo-1\tcodex\tAgent 1\n'
        exit 0
        ;;
    switch-client|select-window|select-pane)
        exit 0
        ;;
    show-option)
        exit 1
        ;;
esac
exit 1
FAKE_TMUX
chmod +x "$FAKE_BIN/tmux"

cat > "$FAKE_BIN/fzf" <<'FAKE_FZF'
#!/usr/bin/env bash
while IFS= read -r line; do
    printf '%s\n' "$line"
    exit 0
done
exit 1
FAKE_FZF
chmod +x "$FAKE_BIN/fzf"

export PATH="$FAKE_BIN:$PATH"
export AGENT_PICKER_TMUX_BIN="$FAKE_BIN/tmux"
export AGENT_PICKER_FZF_BIN="$FAKE_BIN/fzf"
export AGENT_PICKER_CACHE_DIR="$TMP_DIR/cache"

validate_picker_scale() {
    local pane_count="$1"
    local row_count=""

    rm -rf "$AGENT_PICKER_CACHE_DIR"
    export FAKE_TMUX_PANE_COUNT="$pane_count"
    export FAKE_TMUX_FAIL_DISPLAY=0

    "$ROOT_DIR/scripts/picker.sh" >/dev/null

    row_count=$(wc -l < "$AGENT_PICKER_CACHE_DIR/picker.tsv" | tr -d ' ')
    assert_eq "$pane_count" "$row_count" "picker should render $pane_count live pane rows"
}

run_hook_batch() {
    local label="$1"
    local count="$2"
    local index=1
    local output=""

    SECONDS=0
    while [ "$index" -le "$count" ]; do
        output=$(
            printf '{"session_id":"%s-%s","cwd":"/tmp/repo","prompt":"test"}' "$label" "$index" |
                "$ROOT_DIR/scripts/agent-hook.sh" codex UserPromptSubmit
        )
        assert_eq "" "$output" "$label hook should stay output-silent"
        index=$((index + 1))
    done

    [ "$SECONDS" -lt 10 ] || fail "$label hook batch should complete promptly"
}

validate_picker_scale 10
validate_picker_scale 50
validate_picker_scale 100

rm -rf "$AGENT_PICKER_CACHE_DIR"
export TMUX_PANE="%1"
export FAKE_TMUX_FAIL_DISPLAY=0
run_hook_batch normal-tmux 20

unset TMUX_PANE
export FAKE_TMUX_FAIL_DISPLAY=1
run_hook_batch missing-tmux 20

printf 'ok - performance checks\n'
