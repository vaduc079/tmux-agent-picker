#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT_DIR/tests/cache.sh"
"$ROOT_DIR/tests/plugin.sh"
"$ROOT_DIR/tests/agent-adapters.sh"
"$ROOT_DIR/tests/agent-hook.sh"
"$ROOT_DIR/tests/collector.sh"
"$ROOT_DIR/tests/switch-to-agent.sh"
"$ROOT_DIR/tests/performance.sh"

printf 'ok - all tests\n'
