---
phase: planning
title: tmux-agent-picker Planning
description: Task breakdown for the first version of tmux-agent-picker
---

# tmux-agent-picker Planning

## Milestones

- [x] Milestone 1: Plugin scaffold and cache primitives.
- [x] Milestone 2: Tmux collector and pane switching.
- [x] Milestone 3: Claude/Codex hook status updates.
- [x] Milestone 4: fzf picker workflow.
- [x] Milestone 5: Tests, docs, and installation examples.

## Task Breakdown

### Phase 1: Foundation

- [x] Task 1.1: Add tmux plugin entry point `tmux-agent-picker.tmux`.
- [x] Task 1.2: Add shared shell library for cache path resolution, locking, JSON initialization, atomic writes, and logging.
- [x] Task 1.3: Add agent adapter mappings for `idle`, `running`, `wait`, and `error`.
- [x] Task 1.4: Add README install prerequisites for tmux, fzf, jq, Claude hooks, and Codex hooks.

### Phase 2: Tmux Metadata

- [x] Task 2.1: Implement `scripts/tmux-collector.sh --once`.
- [x] Task 2.2: Capture pane metadata with one `tmux list-panes -a` command.
- [x] Task 2.3: Reconcile stale agent records when panes disappear.
- [x] Task 2.4: Generate live-only `picker.tsv` from `agents.json` plus `tmux-panes.json`.
- [x] Task 2.5: Register tmux hooks in the plugin entry point.

### Phase 3: Agent Hooks

- [x] Task 3.1: Implement thin dispatcher `scripts/agent-hook.sh <agent-type> <event>`.
- [x] Task 3.2: Add shared adapter contract and generic helpers under `scripts/lib/agents/`.
- [x] Task 3.3: Parse hook JSON payloads with jq and tolerate missing fields.
- [x] Task 3.4: Resolve current tmux pane metadata from `TMUX_PANE`.
- [x] Task 3.5: Implement Claude adapter lifecycle-to-status mapping.
- [x] Task 3.6: Implement Codex adapter lifecycle-to-status mapping.
- [x] Task 3.7: Ensure hook scripts produce no stdout/stderr control output during normal operation.
- [x] Task 3.8: Add sample Claude and Codex hook configuration snippets.

### Phase 4: Picker

- [x] Task 4.1: Implement `scripts/picker.sh` to run the collector and launch fzf.
- [x] Task 4.2: Implement `scripts/switch-to-agent.sh` to switch tmux clients to the selected pane.
- [x] Task 4.3: Make cancel and stale pane behavior cleanly close the picker UI.
- [x] Task 4.4: Add empty-state behavior when no live agents are available.
- [x] Task 4.5: Add configurable key binding and picker display options.
- [x] Task 4.6: Change picker launch to a configurable tmux popup.

### Phase 5: Tests And Validation

- [x] Task 5.1: Add shell tests for status event mapping.
- [x] Task 5.2: Add shell tests for cache atomic writes and stale pane reconciliation.
- [x] Task 5.3: Add fake-tmux integration tests for collector metadata and pane switching.
- [x] Task 5.4: Add fixture-based tests for Claude/Codex hook payload parsing.
- [x] Task 5.5: Manual smoke test with at least one Claude pane and one Codex pane.

## Dependencies

- Foundation tasks must land before collector, hook, or picker scripts.
- Collector output is required before picker rendering can be completed.
- Agent hook upsert logic depends on cache primitives and agent adapter mappings.
- Integration tests depend on a scriptable tmux server environment.

## Estimates

- Foundation: 0.5 day.
- Tmux metadata collector: 0.5-1 day.
- Agent hook integration: 1 day.
- Picker workflow: 0.5 day.
- Tests and docs: 1 day.

Total initial estimate: 3.5-4 days.

## Risks & Mitigation

- Hook payload fields differ between versions: parse defensively and key records by pane when session id is missing.
- Concurrent hook writes corrupt cache: use locks plus atomic file replacement.
- Tmux hook storms cause slowdowns: keep collector single-pass and add debounce later if needed.
- Stale records remain visible: run collector before picker display, prune missing panes, delete Claude records on `SessionEnd`, and prune Codex records when panes return to a shell foreground command.
- Agent session ids can change in the same tmux pane during resume flows: replace old same-pane records on hook upsert and prune duplicate same-pane records during collection.
- Codex startup hooks may not create visible state before the first prompt: discover live Codex foreground commands from tmux metadata and create temporary `codex:<pane-id>` records until a session-id hook event arrives.
- Notification events are ambiguous: only map to `wait` when payload indicates user attention; `idle_prompt` remains informational in v1.

## Progress Summary

Phase 4 implementation and Phase 5 validation are complete for the first plugin slice. The plugin now includes cache helpers, tmux collector, agent hook dispatcher/adapters, fzf picker, pane switching, plugin entrypoint, README setup docs, and automated shell tests. Live smoke testing covered Claude and Codex registration, resume behavior, picker visibility, process exit cleanup, and pane cleanup. Follow-up issues found during smoke testing were fixed: promptless hook payloads no longer abort registration, Claude `SessionEnd` removes records when the pane remains open, same-pane resume flows deduplicate old records, Codex process exit is detected from tmux foreground command changes, and live Codex panes can be discovered before the first prompt.

## Remaining Work

- None for the current lifecycle pass.

## Resources Needed

- Local tmux 3.x.
- fzf.
- jq.
- Claude Code with hooks configured.
- Codex CLI with hooks enabled.
