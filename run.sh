#!/usr/bin/env bash
set -euo pipefail
strats_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
strats_state="${XDG_STATE_HOME:-$HOME/.local/state}/strats"
mkdir -p "$strats_state"
# Start a separate session with no inherited terminal or tool-session pipes.
# Keep the engine log outside Godot's rotating test/editor logs.
nohup setsid /usr/local/bin/godot --path "$strats_root" \
  --log-file "$strats_state/engine.log" "$@" \
  < /dev/null > "$strats_state/launcher.log" 2>&1 &
strats_pid=$!
printf '%s\n' "$strats_pid" > "$strats_state/game.pid"
printf 'STRATS launched (PID %s). Log: %s/engine.log\n' "$strats_pid" "$strats_state"
