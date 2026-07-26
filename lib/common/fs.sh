#!/usr/bin/env bash
set -euo pipefail

plume_state_dir() {
  printf '%s' "${PLUME_STATE_DIR:-$HOME/.config/plume/state}"
}

plume_ensure_state_dirs() {
  mkdir -p "$(plume_state_dir)"
}
