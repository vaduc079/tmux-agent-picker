# AGENTS.md

## Repository Overview

`tmux-agent-picker` is a Bash/tmux plugin that tracks Claude Code and Codex CLI agent panes and opens an `fzf` picker to jump to the selected pane.

The plugin is event-driven:

- Claude/Codex hooks call `scripts/agent-hook.sh` with JSON payloads.
- tmux hooks call `scripts/tmux-collector.sh` when sessions, windows, or panes change.
- Both paths update cache files under `$AGENT_PICKER_CACHE_DIR`, `@agent-picker-cache-dir`, `$XDG_CACHE_HOME/tmux-agent-picker`, or `~/.cache/tmux-agent-picker`.
- `scripts/picker.sh` reads `picker.tsv`, opens `fzf`, and delegates pane switching to `scripts/switch-to-agent.sh`.

## Structure

- `tmux-agent-picker.tmux` - tmux plugin entry point. Sets defaults, binds the picker key, installs tmux hooks, and primes the cache.
- `scripts/picker.sh` - interactive `fzf` UI for selecting an agent.
- `scripts/agent-hook.sh` - silent best-effort dispatcher for Claude/Codex hooks. Do not emit normal output here.
- `scripts/tmux-collector.sh` - snapshots tmux panes, prunes stale agents, discovers Codex panes, and rebuilds picker rows.
- `scripts/switch-to-agent.sh` - validates the cached pane and switches tmux to it.
- `scripts/lib/cache.sh` - cache paths, JSON initialization, atomic writes, and lock helpers.
- `scripts/lib/picker-index.sh` - rebuilds `picker.tsv` from `agents.json`.
- `scripts/lib/tmux.sh` - tmux helper functions.
- `scripts/lib/agents/*.sh` - per-agent event normalization.
- `tests/*.sh` - shell tests, with `tests/run.sh` as the full test entry point.
- `docs/ai/` - planning/design/testing notes; useful background, not runtime code.

## Runtime Cache

The cache contains:

- `agents.json` - agent records keyed as `<agent_type>:<session_or_pane_id>`.
- `tmux-panes.json` - latest tmux pane snapshot keyed by pane id.
- `picker.tsv` - formatted rows consumed by `scripts/picker.sh`.
- `locks/` - mkdir-based lock directories.

Writes should go through `agent_picker_atomic_write`, and concurrent cache updates should use the lock helpers from `scripts/lib/cache.sh`.

## Development Notes

- Keep scripts portable Bash and consistent with the existing `set -euo pipefail` usage, except `scripts/agent-hook.sh`, which intentionally uses best-effort behavior.
- Hook scripts must not print normal output; output can affect Claude/Codex behavior.
- Prefer shared helpers in `scripts/lib/` over duplicating tmux, cache, lock, or JSON logic.
- Use `jq` for JSON changes and TSV generation. Avoid ad hoc JSON string manipulation.
- Preserve the event normalization boundary in `scripts/lib/agents/`: agent-specific event mapping belongs there, not in the picker or collector.
- Keep user-facing picker columns stable unless the tests and README are updated together.

## Testing

Run the full test suite with:

```bash
tests/run.sh
```

For targeted work, run the matching file in `tests/`, for example:

```bash
tests/cache.sh
tests/agent-hook.sh
tests/collector.sh
```
