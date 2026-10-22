#!/usr/bin/env bash
set -euo pipefail

plume_detect_os() {
  local uname_out
  uname_out="$(uname -s 2>/dev/null || echo unknown)"
  if [[ "${OS:-}" == "Windows_NT" ]]; then
    echo "windows"
    return 0
  fi
  case "${uname_out}" in
    Darwin) echo "macos" ;;
    Linux) echo "linux" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *) echo "unknown" ;;
  esac
}

plume_detect_linux_id() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    echo "${ID:-unknown}"
    return 0
  fi
  echo "unknown"
}

plume_detect_package_manager() {
  local os
  os="$(plume_detect_os)"
  case "${os}" in
    macos)
      if command -v brew >/dev/null 2>&1; then
        echo "brew"
      else
        echo "missing"
      fi
      ;;
    linux)
      if command -v apt >/dev/null 2>&1; then
        echo "apt"
      elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
      else
        echo "manual"
      fi
      ;;
    *)
      echo "manual"
      ;;
  esac
}

plume_install_hint_for() {
  local pkg="$1"
  local pm="${2:-$(plume_detect_package_manager)}"
  case "${pm}" in
    brew) echo "brew install ${pkg}" ;;
    apt) echo "sudo apt update && sudo apt install -y ${pkg}" ;;
    dnf) echo "sudo dnf install -y ${pkg}" ;;
    *)
      echo "Install '${pkg}' manually for your OS and retry."
      ;;
  esac
}

plume_is_root() {
  [[ "$(id -u)" -eq 0 ]]
}

plume_require_root() {
  if plume_is_root; then
    return 0
  fi
  plume_err "this operation requires root/sudo privileges"
  return 2
}

plume_require_native_install_privileges() {
  if [[ "$(plume_bool "${PLUME_ALLOW_NON_ROOT_INSTALL:-false}")" == "true" ]]; then
    return 0
  fi
  local os pm
  os="$(plume_detect_os)"
  pm="$(plume_detect_package_manager)"
  case "${os}" in
    macos)
      if [[ "${pm}" == "brew" ]]; then
        if plume_is_root; then
          plume_err "brew-based installs should run as normal user (not root)"
          return 2
        fi
        return 0
      fi
      # fallback: unknown macOS package flow
      return 0
      ;;
    linux)
      plume_require_root
      ;;
    *)
      plume_require_root
      ;;
  esac
}

# Copy src -> dest without interactive sudo password prompts (CI-safe; D-136).
# Uses sudo -n only when dest is not writable. Never opens /dev/tty.
plume_fs_copy_no_tty() {
  local src="$1"
  local dest="$2"
  if [[ -w "${dest}" ]] || { [[ ! -e "${dest}" ]] && [[ -w "$(dirname "${dest}")" ]]; }; then
    cp "${src}" "${dest}" >/dev/null 2>&1
    return $?
  fi
  if command -v sudo >/dev/null 2>&1; then
    sudo -n cp "${src}" "${dest}" >/dev/null 2>&1
    return $?
  fi
  cp "${src}" "${dest}" >/dev/null 2>&1
}

# Copy src -> dest; passwordless first, then interactive sudo via /dev/tty (D-159).
# Use for /etc/hosts site domain sync. CI/noninteractive still only sudo -n (D-136).
plume_fs_copy_elevated() {
  local src="$1"
  local dest="$2"
  local reason="${3:-Writing ${dest} requires administrator privileges.}"
  if plume_fs_copy_no_tty "${src}" "${dest}"; then
    return 0
  fi
  if ! command -v sudo >/dev/null 2>&1; then
    return 1
  fi
  if declare -F plume_interactive_is_noninteractive >/dev/null 2>&1 \
    && plume_interactive_is_noninteractive; then
    return 1
  fi
  if declare -F plume_macos_permissions_confirm_sudo >/dev/null 2>&1; then
    if ! plume_macos_permissions_confirm_sudo "sudo cp ${src} ${dest}" "${reason}"; then
      return 1
    fi
  elif declare -F plume_interactive_enabled >/dev/null 2>&1; then
    if ! plume_interactive_enabled; then
      return 1
    fi
  elif [[ ! -t 0 && ! -r /dev/tty ]]; then
    return 1
  fi
  set +e
  if [[ -r /dev/tty && -w /dev/tty ]]; then
    sudo cp "${src}" "${dest}" </dev/tty >/dev/null
  else
    sudo cp "${src}" "${dest}" >/dev/null
  fi
  local rc=$?
  set -e
  return "${rc}"
}
