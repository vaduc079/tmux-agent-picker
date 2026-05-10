#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/cache.sh
source "$SCRIPT_DIR/lib/cache.sh"

agent_picker_init_cache
"$SCRIPT_DIR/tmux-collector.sh" --once >/dev/null 2>&1 || true

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

SELECTION=$(
    "$FZF_BIN" \
      --delimiter=$'\t' \
      --with-nth=2,3,4,5,6 \
      --header='status  agent  title  cwd  tmux' \
      --prompt='agent> ' \
      < "$PICKER_TSV"
) || exit 0

AGENT_ID="${SELECTION%%$'\t'*}"
[ -n "$AGENT_ID" ] || exit 0

"$SCRIPT_DIR/switch-to-agent.sh" "$AGENT_ID"
