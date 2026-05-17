---
phase: requirements
title: tmux-agent-picker Requirements
description: Requirements for an event-driven tmux picker for Claude and Codex agent panes
---

# tmux-agent-picker Requirements

## Problem Statement

Users who run multiple Claude Code and Codex CLI agents inside tmux need a fast way to see what is running, which agents need attention, and jump directly to the relevant pane.

Current workflows require scanning tmux windows manually, relying on pane titles, or using broader status/sidebar tools. The first version of `tmux-agent-picker` should be a focused tmux plugin that maintains a lightweight cache of agent state and opens an `fzf` picker in a tmux popup.

## Goals & Objectives

- Provide a tmux key binding that opens a tmux popup containing an `fzf` list of active agent sessions.
- Show each agent's type, cwd, tmux location, display title, and status.
- Switch immediately to the selected agent's tmux pane.
- Keep agent and tmux metadata up to date through hooks, not steady polling.
- Store centralized runtime data under `~/.cache/tmux-agent-picker/`, or `$XDG_CACHE_HOME/tmux-agent-picker` when set.
- Keep Claude/Codex hooks side-effect free beyond updating picker cache data.
- Support both Claude Code and Codex CLI in the first version.

## Non-Goals

- No persistent sidebar in v1.
- No tmux status-line integration in v1.
- No agent process management, close actions, park mode, or wait timers in v1.
- No mutation of Claude/Codex prompts, tool calls, permissions, or runtime behavior.
- No custom TUI beyond `fzf` in v1.
- No cross-machine aggregation in v1.

## User Stories & Use Cases

- As a tmux user running multiple agents, I want to press one tmux key and see every tracked agent so that I can choose the right one quickly.
- As a user, I want rows to include agent type, cwd, tmux session/window/pane, display title, and status so that I can distinguish similar agents.
- As a user, I want selecting a row to switch to that pane immediately so that the picker becomes a navigation tool, not just a dashboard.
- As a user, I want agents waiting on permission or input to be visible as `wait` so that I can unblock them first.
- As a user, I want closed panes and ended agents to disappear automatically so that the picker does not accumulate stale entries.

## Status Model

The user-facing statuses are:

- `idle`: agent exists and is not currently responding.
- `running`: agent is processing a prompt or using tools.
- `wait`: agent is blocked on user input, permission, or another interactive decision.
- `error`: agent hook reported a failure state.

Event mapping:

- Claude `SessionStart`: register or refresh the agent as `idle`.
- Claude `UserPromptSubmit`: mark `running`.
- Claude `PreToolUse`: mark `running`.
- Claude `Stop`: mark `idle`.
- Claude `StopFailure`: mark `error`.
- Claude `SessionEnd`: remove the agent.
- Claude `PermissionRequest`: mark `wait`.
- Claude `Notification`: mark `wait` for user-attention notification types such as `permission_prompt` and `elicitation_dialog`; ignore non-blocking notification types such as `auth_success`, `elicitation_complete`, and `elicitation_response`.
- Codex `SessionStart`: register or refresh the agent as `idle`.
- Codex `UserPromptSubmit`: mark `running`.
- Codex `PreToolUse` and `PostToolUse`: mark `running`.
- Codex `PermissionRequest`: mark `wait`.
- Codex `Stop`: mark `idle`.
- Codex process exit: remove the agent when the tmux collector sees that the owning pane has returned to a shell foreground command.

## Product Decisions For V1

- Default picker key: `prefix + A`, configurable through `@agent-picker-key`.
- Picker display: tmux popup in v1, with configurable popup width and height.
- Display title is derived because Claude and Codex hooks do not expose a general agent session title. Title priority: tmux pane title, then tmux window name, then the first line of the most recent user prompt when available, then agent session id.
- Cache persistence: records may remain on disk across shell invocations, but the collector must hide or remove records whose tmux pane is not live in the current tmux server, or whose Codex process has exited while the pane remains open.
- Registration source: agent hooks are the canonical source for creating agent records. The tmux collector enriches and cleans records, and may create a temporary Codex record from live tmux pane metadata when a Codex pane is visible before its startup hook writes cache state.
- Hook output: picker hooks should produce no stdout/stderr control output for Claude or Codex. They should exit 0 after best-effort cache writes so they never approve, deny, block, continue, or otherwise steer the agent.
- Picker visibility: show only agents whose owning tmux pane is still live.
- Claude `idle_prompt` notifications are informational in v1 and do not change status to `wait`.

## Success Criteria

- Installing the tmux plugin adds a configurable key binding that opens the picker in a tmux popup.
- The picker lists Claude and Codex agents from all tmux sessions visible to the current tmux server.
- Each row includes at least: status, agent type, cwd, tmux session/window/pane, and display title.
- Selecting a row switches to the exact pane that owns the agent.
- Hook handlers exit successfully and quickly even when tmux is unavailable.
- Tmux structure changes trigger cache refreshes for pane/window/session create, rename, selection, and exit events.
- Cache writes are atomic and do not leave partially written JSON/TSV files.
- Stale agent records are removed or hidden when their owning tmux pane no longer exists.
- The implementation works on macOS and Linux with Bash, tmux, fzf, and jq installed.

## Constraints & Assumptions

- v1 is a shell-based tmux plugin following tmux plugin manager conventions.
- `fzf` is required for the picker.
- `jq` is required for robust JSON hook payload parsing.
- Agent hooks receive JSON on stdin and must drain stdin before exiting.
- Hook scripts should tolerate missing fields because hook payloads may vary across Claude/Codex versions.
- Tmux pane identity should prefer `TMUX_PANE` when present, then tmux metadata lookup from the hook environment.
- The cache is local to the user and tmux server; multi-user locking is out of scope.
- The picker should not require a long-running daemon for v1, but a singleton collector process may be introduced later if event bursts become expensive.
- The implementation should assume one visible agent record per hook-reported agent session. If the same Claude/Codex session id moves panes, the most recent hook event wins.

## Reference Findings

- tmux plugin entry point configures key bindings and tmux hooks.
- agent hooks are small, drain stdin, write cache/status files, and exit successfully.
- tmux hooks trigger a collector rather than doing heavy UI work.
- picker scripts consume cached state and use `tmux switch-client`, `select-window`, and `select-pane` style commands for navigation.

## Questions & Open Items

- Validate Claude notification behavior during real usage and revisit `idle_prompt` if it proves to indicate a blocked agent.
