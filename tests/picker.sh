#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/test-helpers.sh"

TMP_DIR=$(make_temp_dir)
trap 'rm -rf "$TMP_DIR"' EXIT

FAKE_BIN="$TMP_DIR/bin"
FZF_INPUT="$TMP_DIR/fzf-input.tsv"
FZF_ARGS="$TMP_DIR/fzf-args.txt"
mkdir -p "$FAKE_BIN"

cat > "$FAKE_BIN/tmux" <<'FAKE_TMUX'
#!/usr/bin/env bash
case "$1" in
    list-sessions)
        exit 0
        ;;
    list-panes)
        printf '$1\tsess\t@1\t1\twork\t%%1\t0\t/Users/duc.vu/projects/personal/tmux-agent-picker\tcodex\tCheck workspace meal snap daily reward\n'
        printf '$1\tduc-vu\t@2\t1\twork\t%%2\t1\t/Users/duc.vu/codebases/challenge\tcodex\tSummarize JD'\''s documentation\n'
        exit 0
        ;;
    display-message)
        case "$*" in
            *'#{window_width}'*)
                printf '132\n'
                ;;
            *)
                printf '%%1\n'
                ;;
        esac
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
printf '%s\n' "$@" > "$FAKE_FZF_ARGS"
input=$(cat)
printf '%s\n' "$input" > "$FAKE_FZF_INPUT"
printf '%s\n' "$input" | sed -n '2p'
FAKE_FZF
chmod +x "$FAKE_BIN/fzf"

cat > "$FAKE_BIN/tput" <<'FAKE_TPUT'
#!/usr/bin/env bash
case "$1" in
    cols)
        printf '60\n'
        exit 0
        ;;
esac
exit 1
FAKE_TPUT
chmod +x "$FAKE_BIN/tput"

export PATH="$FAKE_BIN:$PATH"
export FAKE_FZF_INPUT="$FZF_INPUT"
export FAKE_FZF_ARGS="$FZF_ARGS"
export AGENT_PICKER_TMUX_BIN="$FAKE_BIN/tmux"
export AGENT_PICKER_FZF_BIN="$FAKE_BIN/fzf"
export AGENT_PICKER_CACHE_DIR="$TMP_DIR/cache"
export AGENT_PICKER_WINDOW_WIDTH=120

"$ROOT_DIR/scripts/picker.sh" >/dev/null

grep -qx -- "--no-sort" "$FZF_ARGS" || fail "picker should preserve pre-sorted picker.tsv order in fzf"

header=$(sed -n '1p' "$FZF_INPUT")
first_row=$(sed -n '2p' "$FZF_INPUT")
second_row=$(sed -n '3p' "$FZF_INPUT")

header_display="${header#*$'\t'}"
first_display="${first_row#*$'\t'}"
second_display="${second_row#*$'\t'}"

visible_column() {
    local line="$1"
    local needle="$2"

    awk -v line="$line" -v needle="$needle" '
        BEGIN {
            gsub(/🟢|🔵|🟡|🔴|⚪/, "xx", line)
            print index(line, needle)
        }
    '
}

display_width() {
    local line="$1"

    awk -v line="$line" '
        BEGIN {
            gsub(/🟢|🔵|🟡|🔴|⚪/, "xx", line)
            print length(line)
        }
    '
}

assert_column_aligned() {
    local row_name="$1"
    local row_display="$2"
    local header_label="$3"
    local row_value="$4"

    local header_column=""
    local row_column=""

    header_column=$(visible_column "$header_display" "$header_label")
    row_column=$(visible_column "$row_display" "$row_value")

    assert_eq "$header_column" "$row_column" "$row_name $header_label column aligns with header"
}

assert_column_aligned "first row" "$first_display" "agent" "codex"
assert_column_aligned "first row" "$first_display" "title" "Check workspace"
assert_column_aligned "first row" "$first_display" "cwd" ".../personal/tmux-agent-picker"
assert_column_aligned "first row" "$first_display" "tmux" "sess:1.0"

assert_column_aligned "second row" "$second_display" "agent" "codex"
assert_column_aligned "second row" "$second_display" "title" "Summarize JD"
assert_column_aligned "second row" "$second_display" "cwd" ".../codebases/challenge"
assert_column_aligned "second row" "$second_display" "tmux" "duc-vu:1.1"

export AGENT_PICKER_TITLE_WIDTH=16
export AGENT_PICKER_CWD_WIDTH=18

"$ROOT_DIR/scripts/picker.sh" >/dev/null

first_row=$(sed -n '2p' "$FZF_INPUT")
first_display="${first_row#*$'\t'}"

case "$first_display" in
    *"Check workspa..."*".../personal/tm..."*)
        ;;
    *)
        fail "custom picker widths should clip title and cwd: $first_display"
        ;;
esac

unset AGENT_PICKER_TITLE_WIDTH
unset AGENT_PICKER_CWD_WIDTH
unset AGENT_PICKER_TMUX_WIDTH
export AGENT_PICKER_WINDOW_WIDTH=60

"$ROOT_DIR/scripts/picker.sh" >/dev/null

first_row=$(sed -n '2p' "$FZF_INPUT")
second_row=$(sed -n '3p' "$FZF_INPUT")
first_display="${first_row#*$'\t'}"
second_display="${second_row#*$'\t'}"

first_width=$(display_width "$first_display")
second_width=$(display_width "$second_display")

[ "$first_width" -le 60 ] || fail "first row should fit dynamic window width: $first_width"
[ "$second_width" -le 60 ] || fail "second row should fit dynamic window width: $second_width"

unset AGENT_PICKER_WINDOW_WIDTH

"$ROOT_DIR/scripts/picker.sh" >/dev/null

first_row=$(sed -n '2p' "$FZF_INPUT")
first_display="${first_row#*$'\t'}"
first_width=$(display_width "$first_display")

[ "$first_width" -gt 60 ] || fail "picker should prefer tmux window width over stale tput width: $first_width"
[ "$first_width" -le 132 ] || fail "picker should cap tmux-sized row to tmux width: $first_width"

printf 'ok - picker\n'
