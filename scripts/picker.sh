#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/cache.sh
source "$SCRIPT_DIR/lib/cache.sh"

agent_picker_init_cache

if [ ! -s "$PICKER_TSV" ]; then
    # Hooks keep picker.tsv fresh; the collector is only a cold-cache fallback here.
    "$SCRIPT_DIR/tmux-collector.sh" --once --lock-briefly >/dev/null 2>&1 || true
fi

if [ ! -s "$PICKER_TSV" ]; then
    printf 'No live agents found.\n'
    sleep 1
    exit 0
fi

FZF_BIN="${AGENT_PICKER_FZF_BIN:-fzf}"

if ! command -v "$FZF_BIN" >/dev/null 2>&1; then
    printf 'fzf is required for tmux-agent-picker.\n' >&2
    sleep 2
    exit 1
fi

agent_picker_positive_int() {
    case "${1:-}" in
        ""|*[!0-9]*)
            return 1
            ;;
    esac

    [ "$1" -gt 0 ]
}

agent_picker_column_width() {
    local value="${1:-}"
    local default_value="$2"

    if agent_picker_positive_int "$value"; then
        printf '%s\n' "$value"
        return 0
    fi

    printf '%s\n' "$default_value"
}

STATUS_WIDTH=$(agent_picker_column_width "${AGENT_PICKER_STATUS_WIDTH:-}" 12)
AGENT_WIDTH=$(agent_picker_column_width "${AGENT_PICKER_AGENT_WIDTH:-}" 10)
TITLE_WIDTH=$(agent_picker_column_width "${AGENT_PICKER_TITLE_WIDTH:-}" 44)
CWD_WIDTH=$(agent_picker_column_width "${AGENT_PICKER_CWD_WIDTH:-}" 36)
TMUX_WIDTH=$(agent_picker_column_width "${AGENT_PICKER_TMUX_WIDTH:-}" 24)

agent_picker_format_rows() {
    awk \
      -v status_width="$STATUS_WIDTH" \
      -v agent_width="$AGENT_WIDTH" \
      -v title_width="$TITLE_WIDTH" \
      -v cwd_width="$CWD_WIDTH" \
      -v tmux_width="$TMUX_WIDTH" \
      -F '\t' '
        function clean(value) {
            gsub(/[[:cntrl:]]/, " ", value)
            return value
        }

        function clip_cell(value, width, marker, room) {
            value = clean(value)
            marker = "..."
            room = width - length(marker)

            if (length(value) <= width) {
                return value
            }

            if (room <= 0) {
                return substr(value, 1, width)
            }

            return substr(value, 1, room) marker
        }

        function terminal_width(value, visible) {
            visible = clean(value)
            # fzf/tmux render these status icons as two terminal cells.
            gsub(/🟢|🔵|🟡|🔴|⚪/, "xx", visible)
            return length(visible)
        }

        function format_cell(value, width, padding) {
            value = clip_cell(value, width)
            padding = width - terminal_width(value)

            if (padding > 0) {
                return value sprintf("%" padding "s", "")
            }

            return value
        }

        function print_row(id, status, agent, title, cwd, tmux) {
            printf "%s\t%s  %s  %s  %s  %s\n",
                id,
                format_cell(status, status_width),
                format_cell(agent, agent_width),
                format_cell(title, title_width),
                format_cell(cwd, cwd_width),
                clip_cell(tmux, tmux_width)
        }

        BEGIN {
            print_row("", "status", "agent", "title", "cwd", "tmux")
        }

        NF >= 6 {
            print_row($1, $2, $3, $4, $5, $6)
        }
    '
}

SELECTION=$(
    agent_picker_format_rows < "$PICKER_TSV" |
    "$FZF_BIN" \
      --delimiter=$'\t' \
      --with-nth=2 \
      --header-lines=1 \
      --prompt='agent> ' \
) || exit 0

AGENT_ID="${SELECTION%%$'\t'*}"
[ -n "$AGENT_ID" ] || exit 0

"$SCRIPT_DIR/switch-to-agent.sh" "$AGENT_ID"
