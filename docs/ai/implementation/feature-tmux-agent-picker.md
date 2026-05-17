---
phase: implementation
title: tmux-agent-picker Implementation Guide
description: Initial implementation notes for tmux-agent-picker
---

# tmux-agent-picker Implementation Guide

## Development Setup

- Worktree: `.worktrees/feature-tmux-agent-picker`.
- Current dynamic-column update is intentionally being made in the main workspace without a worktree per user request.
- Required local tools: Bash, tmux, fzf, jq.
- No package manager is currently present in the repo, so dependency bootstrap is skipped until a manifest is added.

## Proposed Code Structure

```text
tmux-agent-picker.tmux
scripts/
  agent-hook.sh
  picker.sh
  switch-to-agent.sh
  tmux-collector.sh
  lib/
    agents/
      claude.sh
      codex.sh
      generic.sh
    cache.sh
    tmux.sh
tests/
  agent-adapters.sh
  agent-hook.sh
  cache.sh
  collector.sh
  performance.sh
  plugin.sh
  switch-to-agent.sh
```

## Implementation Notes

- Keep hook handlers small and best-effort. They must drain stdin and exit 0.
- Keep `agent-hook.sh` as a thin dispatcher. Parse common payload fields once, then put agent-specific event mapping in `scripts/lib/agents/<agent-type>.sh`.
- Keep hook handlers output-silent during normal operation. Claude and Codex can interpret stdout, stderr, and non-zero exits as control signals.
- Keep canonical cache state in JSON and derive picker TSV.
- Treat `agents.json` and `picker.tsv` as live indexes. The collector should remove agents whose owning tmux pane no longer exists in the latest snapshot.
- Render picker columns as `status agent title cwd tmux`, using emoji status labels and a compact cwd that shows only the last two path components for deep paths.
- Keep `status` and `agent` fixed-width. Measure `title`, `cwd`, and `tmux` from the current picker rows, then shrink those dynamic columns as needed so the visible row fits the current popup/window width. Positive numeric dynamic width options act as per-column maximums.
- Remove Claude records on `SessionEnd` so exited Claude processes disappear even when the tmux pane stays open.
- Remove Codex records when the collector sees that the owning pane foreground command has returned to a shell.
- Allow the collector to create temporary `codex:<pane-id>` records for live Codex panes before the first Codex hook event creates a session-id record.
- Replace existing same-pane records on hook upsert to avoid duplicate picker rows after resume flows.
- Prefer one tmux metadata collection command per collector run.
- Use `TMUX_PANE` as the primary association between hook events and panes.
- Avoid storing full prompts, tool inputs, or transcript contents.
- Resolve display titles in this order: tmux pane title, tmux window name, short first line of the latest `UserPromptSubmit` prompt, agent session id. Do not store full prompts.
- Keep tmux hook registration idempotent so reloading the plugin does not append duplicate collector hooks.

## Error Handling

- Cache write failures should log to a local debug file only when debug mode is enabled.
- Hook scripts should not block or fail the agent process.
- Picker switching should validate the target pane before switching.

## Performance Considerations

- Rebuild derived picker rows only when agent or tmux cache data changes.
- Run collector before picker display to handle missed hooks.
- Consider a debounced singleton collector only after v1 behavior is proven.

## Phase 6 Implementation Check

Date: 2026-05-10

Status: aligned with requirements and design after adding the missing supported tmux structure hooks to `tmux-agent-picker.tmux`.

Verification performed:

- Ran `npx ai-devkit@latest lint --feature tmux-agent-picker` in `.worktrees/feature-tmux-agent-picker`.
- Ran `/Users/duc.vu/.ai-devkit/skills/codeaholicguy/ai-devkit/skills/dev-lifecycle/scripts/check-status.sh tmux-agent-picker`; it suggested Phase 6 with 32/32 planning tasks complete.
- Compared requirements and design against `tmux-agent-picker.tmux`, `scripts/`, `tests/`, `README.md`, and feature docs.
- Verified registered hook names against tmux 3.6a in an isolated tmux server. `after-kill-window` was rejected by tmux and is intentionally not registered; `window-unlinked` covers window removal.
- Ran `tests/run.sh`; all shell tests passed.

Design alignment summary:

- Plugin entrypoint defines the picker key/popup behavior and appends supported tmux structure hooks that run the collector.
- Cache primitives resolve XDG/default paths, initialize JSON/TSV files, serialize writes under a lock, and use temporary-file replacement for normal cache writes.
- Agent hooks are output-silent in normal operation, drain stdin, parse payloads with `jq`, dispatch through Claude/Codex adapters, and upsert/delete normalized records.
- The collector captures tmux pane metadata in one `list-panes -a` call, prunes stale panes and exited Codex processes, discovers visible Codex panes before hook registration, deduplicates same-pane records, and rebuilds live-only `picker.tsv`.
- The picker runs the collector before display, uses `fzf`, handles empty/cancel states, and delegates selection to pane switching.
- Pane switching validates liveness and targets stable tmux session/window/pane ids.

Phase 7 closed the remaining performance and missing-tmux-environment test gaps with `tests/performance.sh`.

## Phase 8 Code Review

Date: 2026-05-10

Status: passed with no blocking findings after updating the design doc to remove the invalid `after-kill-window` hook.

Review coverage:

- Checked feature docs, README, plugin entrypoint, scripts, shared libraries, agent adapters, and tests.
- Traced `agent_picker_*` helpers and `AGENT_PICKER_*` integration points across callers.
- Verified the shell entrypoint works through `tmux run-shell` in an isolated tmux server.
- Verified `set-hook -ga` appends hook array entries instead of overwriting existing hooks.
- Confirmed all registered hook names are accepted by local tmux 3.6a.
- Ran shell syntax checks with `bash -n` for plugin, scripts, libraries, and tests.

Findings:

- No blocking correctness, security, rollback, dependency, or contract issues found.
- `shellcheck` is not installed in the local environment, so static shell linting was limited to manual review and `bash -n`.

Latest verification:

- `npx ai-devkit@latest lint --feature tmux-agent-picker`
- `tests/run.sh`
- `bash -n tmux-agent-picker.tmux scripts/*.sh scripts/lib/*.sh scripts/lib/agents/*.sh tests/*.sh`

## Simplification Pass

Date: 2026-05-10

Changes made after the lifecycle review:

- Removed the production-unused `scripts/lib/status.sh` and its standalone test.
- Removed the write-only `refresh` cache file and debug helper plumbing.
- Removed no-op collector mode handling while preserving `--once` as a compatible argument.
- Made plugin hook registration idempotent while still using `set-hook -ga` to preserve existing user hooks.
- Parsed hook payload fields once in `agent-hook.sh`; adapters now only map agent events to action/status.

Validation:

- `tests/run.sh`
- `bash -n tmux-agent-picker.tmux scripts/*.sh scripts/lib/*.sh scripts/lib/agents/*.sh tests/*.sh`
