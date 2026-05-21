#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/cache.sh
source "$SCRIPT_DIR/lib/cache.sh"
# shellcheck source=lib/picker-index.sh
source "$SCRIPT_DIR/lib/picker-index.sh"

agent_picker_init_cache

if jq -e 'length > 0' "$AGENTS_JSON" >/dev/null 2>&1; then
    agent_picker_rebuild_picker_tsv
fi

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

agent_picker_column_max_width() {
    local value="${1:-}"

    if agent_picker_positive_int "$value"; then
        printf '%s\n' "$value"
        return 0
    fi

    printf '0\n'
}

agent_picker_tty_width() {
    local tty_size=""
    local width=""

    tty -s || return 1

    tty_size=$(stty size </dev/tty 2>/dev/null || true)
    width="${tty_size##* }"
    agent_picker_positive_int "$width" || return 1

    printf '%s\n' "$width"
}

agent_picker_tmux_window_width() {
    local width=""

    width=$(agent_picker_tmux_cmd display-message -p '#{window_width}' 2>/dev/null || true)
    agent_picker_positive_int "$width" || return 1

    printf '%s\n' "$width"
}

agent_picker_tput_width() {
    local width=""

    command -v tput >/dev/null 2>&1 || return 1

    width=$(tput cols 2>/dev/null || true)
    agent_picker_positive_int "$width" || return 1

    printf '%s\n' "$width"
}

agent_picker_window_width() {
    local width="${AGENT_PICKER_WINDOW_WIDTH:-}"

    if agent_picker_positive_int "$width"; then
        printf '%s\n' "$width"
        return 0
    fi

    if width=$(agent_picker_tty_width); then
        printf '%s\n' "$width"
        return 0
    fi

    if width=$(agent_picker_tmux_window_width); then
        printf '%s\n' "$width"
        return 0
    fi

    if width=$(agent_picker_tput_width); then
        printf '%s\n' "$width"
        return 0
    fi

    printf '120\n'
}

STATUS_WIDTH=$(agent_picker_column_width "${AGENT_PICKER_STATUS_WIDTH:-}" 12)
AGENT_WIDTH=$(agent_picker_column_width "${AGENT_PICKER_AGENT_WIDTH:-}" 10)
TITLE_MAX_WIDTH=$(agent_picker_column_max_width "${AGENT_PICKER_TITLE_WIDTH:-}")
CWD_MAX_WIDTH=$(agent_picker_column_max_width "${AGENT_PICKER_CWD_WIDTH:-}")
TMUX_MAX_WIDTH=$(agent_picker_column_max_width "${AGENT_PICKER_TMUX_WIDTH:-}")
WINDOW_WIDTH=$(agent_picker_window_width)

agent_picker_format_rows() {
    awk \
      -v status_width="$STATUS_WIDTH" \
      -v agent_width="$AGENT_WIDTH" \
      -v title_max_width="$TITLE_MAX_WIDTH" \
      -v cwd_max_width="$CWD_MAX_WIDTH" \
      -v tmux_max_width="$TMUX_MAX_WIDTH" \
      -v window_width="$WINDOW_WIDTH" \
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

        function max_value(current, candidate) {
            return candidate > current ? candidate : current
        }

        function min_value(current, candidate) {
            return candidate < current ? candidate : current
        }

        function cap_width(width, max_width) {
            if (max_width > 0 && width > max_width) {
                return max_width
            }

            return width
        }

        function format_cell(value, width, padding) {
            value = clip_cell(value, width)
            padding = width - terminal_width(value)

            if (padding > 0) {
                return value sprintf("%" padding "s", "")
            }

            return value
        }

        function store_row(id_value, status_value, agent_value, title_value, cwd_value, tmux_value) {
            row_count += 1
            ids[row_count] = id_value
            statuses[row_count] = status_value
            agents[row_count] = agent_value
            titles[row_count] = title_value
            cwds[row_count] = cwd_value
            tmuxes[row_count] = tmux_value

            title_width = max_value(title_width, terminal_width(title_value))
            cwd_width = max_value(cwd_width, terminal_width(cwd_value))
            tmux_width = max_value(tmux_width, terminal_width(tmux_value))
        }

        function fit_tiny_columns(available_width, first_width, second_width) {
            first_width = int(available_width / 3)
            second_width = int(available_width / 3)

            title_width = first_width
            cwd_width = second_width
            tmux_width = available_width - first_width - second_width
        }

        function fit_dynamic_columns(available_width, min_title_width, min_cwd_width, min_tmux_width, natural_total, min_total, remaining_width, title_extra, cwd_extra, tmux_extra, total_extra, assigned_title_extra, assigned_cwd_extra) {
            natural_total = title_width + cwd_width + tmux_width
            if (natural_total <= available_width) {
                return
            }

            min_total = min_title_width + min_cwd_width + min_tmux_width
            if (min_total > available_width) {
                fit_tiny_columns(available_width)
                return
            }

            remaining_width = available_width - min_total
            title_extra = title_width - min_title_width
            cwd_extra = cwd_width - min_cwd_width
            tmux_extra = tmux_width - min_tmux_width
            total_extra = title_extra + cwd_extra + tmux_extra

            if (total_extra <= 0) {
                title_width = min_title_width
                cwd_width = min_cwd_width
                tmux_width = min_tmux_width
                return
            }

            assigned_title_extra = int(remaining_width * title_extra / total_extra)
            assigned_cwd_extra = int(remaining_width * cwd_extra / total_extra)

            title_width = min_title_width + assigned_title_extra
            cwd_width = min_cwd_width + assigned_cwd_extra
            tmux_width = min_tmux_width + remaining_width - assigned_title_extra - assigned_cwd_extra
        }

        function print_row(row_number) {
            printf "%s\t%s  %s  %s  %s  %s\n",
                ids[row_number],
                format_cell(statuses[row_number], status_width),
                format_cell(agents[row_number], agent_width),
                format_cell(titles[row_number], title_width),
                format_cell(cwds[row_number], cwd_width),
                clip_cell(tmuxes[row_number], tmux_width)
        }

        BEGIN {
            separator_width = 8
            store_row("", "status", "agent", "title", "cwd", "tmux")
        }

        NF >= 6 {
            store_row($1, $2, $3, $4, $5, $6)
        }

        END {
            title_width = cap_width(title_width, title_max_width)
            cwd_width = cap_width(cwd_width, cwd_max_width)
            tmux_width = cap_width(tmux_width, tmux_max_width)

            dynamic_width = window_width - status_width - agent_width - separator_width
            if (dynamic_width < 3) {
                dynamic_width = 3
            }

            min_title_width = min_value(title_width, 12)
            min_cwd_width = min_value(cwd_width, 10)
            min_tmux_width = min_value(tmux_width, 8)

            fit_dynamic_columns(dynamic_width, min_title_width, min_cwd_width, min_tmux_width)

            for (row_index = 1; row_index <= row_count; row_index += 1) {
                print_row(row_index)
            }
        }
    '
}

SELECTION=$(
    agent_picker_format_rows < "$PICKER_TSV" |
    "$FZF_BIN" \
      --delimiter=$'\t' \
      --with-nth=2 \
      --header-lines=1 \
      --no-sort \
      --prompt='agent> ' \
) || exit 0

AGENT_ID="${SELECTION%%$'\t'*}"
[ -n "$AGENT_ID" ] || exit 0

"$SCRIPT_DIR/switch-to-agent.sh" "$AGENT_ID"
