#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/test-helpers.sh"

TMP_DIR=$(make_temp_dir)
trap 'rm -rf "$TMP_DIR"' EXIT

INJECTION_MARKER="$TMP_DIR/injection-ran"
FAKE_BIN="$TMP_DIR/bin with spaces;touch $INJECTION_MARKER"
HOOKS_DIR="$TMP_DIR/hooks"
TMUX_LOG="$TMP_DIR/tmux.log"
mkdir -p "$FAKE_BIN" "$HOOKS_DIR"

cat > "$FAKE_BIN/tmux" <<'FAKE_TMUX'
#!/usr/bin/env bash

hook_file() {
    printf '%s/%s.hook\n' "$FAKE_TMUX_HOOKS_DIR" "$1"
}

case "$1" in
    bind-key)
        printf 'bind-key %s\n' "$*" >> "$FAKE_TMUX_LOG"
        exit 0
        ;;
    set-hook)
        hook_name="$3"
        hook_command="$4"
        printf 'set-hook %s %s\n' "$hook_name" "$hook_command" >> "$FAKE_TMUX_LOG"
        printf '%s[0] %s\n' "$hook_name" "$hook_command" >> "$(hook_file "$hook_name")"
        exit 0
        ;;
    show-hooks)
        hook_name="$3"
        cat "$(hook_file "$hook_name")" 2>/dev/null || true
        exit 0
        ;;
    show-option)
        exit 1
        ;;
    list-sessions)
        exit 1
        ;;
esac

exit 1
FAKE_TMUX
chmod +x "$FAKE_BIN/tmux"

cat > "$FAKE_BIN/fzf" <<'FAKE_FZF'
#!/usr/bin/env bash
exit 0
FAKE_FZF
chmod +x "$FAKE_BIN/fzf"

export PATH="$FAKE_BIN:$PATH"
export FAKE_TMUX_HOOKS_DIR="$HOOKS_DIR"
export FAKE_TMUX_LOG="$TMUX_LOG"
export AGENT_PICKER_TMUX_BIN="$FAKE_BIN/tmux"
export AGENT_PICKER_FZF_BIN="$FAKE_BIN/fzf"
export AGENT_PICKER_CACHE_DIR="$TMP_DIR/cache with spaces;touch $INJECTION_MARKER"

"$ROOT_DIR/tmux-agent-picker.tmux"
"$ROOT_DIR/tmux-agent-picker.tmux"

hook_count=$(grep -c '^set-hook pane-exited ' "$TMUX_LOG")
assert_eq "1" "$hook_count" "plugin reload should not duplicate collector hook"

bind_count=$(grep -c '^bind-key ' "$TMUX_LOG")
assert_eq "2" "$bind_count" "plugin reload should refresh key binding"

[ ! -e "$INJECTION_MARKER" ] || fail "plugin command construction executed untrusted config"
grep -F '\;touch\' "$TMUX_LOG" >/dev/null || fail "plugin commands should shell-escape semicolons"

printf 'ok - plugin\n'
