---
phase: testing
title: tmux-agent-picker Testing Strategy
description: Initial test strategy for tmux-agent-picker
---

# tmux-agent-picker Testing Strategy

## Test Coverage Goals

- Cover all new shell library logic and event-to-status mapping.
- Cover collector reconciliation for live and stale panes.
- Cover picker selection and tmux pane switching through integration tests.
- Use fixture JSON payloads for Claude and Codex hooks.

## Unit Tests

### Status Mapping

- [x] Claude `SessionStart` maps to `idle`.
- [x] Claude `UserPromptSubmit` and `PreToolUse` map to `running`.
- [x] Claude `Stop` maps to `idle`.
- [x] Claude `StopFailure` maps to `error`.
- [x] Claude wait-capable events map to `wait` when payload indicates user attention.
- [x] Codex `PermissionRequest` maps to `wait`.
- [x] Codex `Stop` maps to `idle`.

### Cache Library

- [x] Initializes missing JSON files.
- [x] Writes files atomically.
- [x] Preserves existing records on upsert.
- [x] Handles malformed cache files with a safe fallback.

## Integration Tests

- [x] Collector writes `tmux-panes.json` from a fake tmux server.
- [x] Collector removes agent records for exited panes and exited Codex processes.
- [x] Collector discovers live Codex panes before the first prompt is sent.
- [x] Agent hook writes cache records from hook payloads.
- [x] Picker row generation includes status, agent type, cwd, tmux location, and title.
- [x] Picker row formatting keeps fixed status/agent columns aligned and caps dynamic title/cwd/tmux columns to the current window width.
- [x] Switch script targets the selected pane with stable tmux ids.
- [x] Real tmux server smoke test with live panes.

## Manual Testing

- [x] Install plugin through a local tmux plugin path.
- [x] Configure Claude hooks and verify lifecycle transitions.
- [x] Configure Codex hooks and verify lifecycle transitions.
- [x] Run one Claude and one Codex agent in separate panes.
- [x] Open picker in a tmux popup and switch to each pane.
- [x] Close an agent pane and verify it disappears from the picker.
- [x] Exit Claude with the tmux pane still open and verify the picker entry is removed through `SessionEnd`.
- [x] Exit Codex with the tmux pane still open and verify the collector removes the picker entry.
- [x] Resume a Claude session in the same pane and verify duplicate picker entries are not retained.
- [x] Start a Codex session without sending a prompt and verify the collector discovers it for picker display.

## Performance Testing

- [x] Validate picker startup with 10, 50, and 100 panes using fake tmux/fzf coverage in `tests/performance.sh`.
- [x] Validate hook handler runtime with normal and missing tmux environment variables using fake tmux coverage in `tests/performance.sh`.

## Phase 7 Results

Date: 2026-05-10

Automated coverage now includes:

- `tests/cache.sh`: cache path resolution, JSON initialization, atomic writes, malformed JSON fallback, and lock recovery.
- `tests/plugin.sh`: plugin key binding and idempotent tmux hook registration.
- `tests/agent-adapters.sh`: Claude and Codex event-to-status mapping.
- `tests/agent-hook.sh`: hook cache writes, output-silent behavior, same-pane replacement, Claude `SessionEnd`, and prompt title hints.
- `tests/collector.sh`: tmux snapshot generation, duplicate pruning, stale pane cleanup, exited Codex cleanup, picker TSV generation, and live Codex discovery.
- `tests/switch-to-agent.sh`: stable tmux id targeting for pane switching.
- `tests/performance.sh`: picker scale checks for 10, 50, and 100 panes, plus repeated hook execution with normal and missing tmux pane context.

Latest verification:

- `npx ai-devkit@latest lint --feature tmux-agent-picker`
- `tests/run.sh`
