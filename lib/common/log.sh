#!/usr/bin/env bash
set -euo pipefail

plume_info() {
  if [[ "${PLUME_OUTPUT:-text}" == "json" || "${PLUME_QUIET:-false}" == "true" ]]; then
    return 0
  fi
  printf '%s\n' "[INFO] $*"
}

plume_warn() {
  if [[ "${PLUME_QUIET:-false}" == "true" ]]; then
    return 0
  fi
  printf '%s\n' "[WARN] $*" >&2
}

plume_err() {
  printf '%s\n' "[ERROR] $*" >&2
}
