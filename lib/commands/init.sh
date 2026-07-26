#!/usr/bin/env bash
set -euo pipefail

plume_init_shell_default() {
  local current
  current="$(basename "${SHELL:-}")"
  case "${current}" in
    zsh|bash) printf '%s' "${current}" ;;
    *) printf '%s' "zsh" ;;
  esac
}

plume_init_shell_rc_file() {
  local shell_name="${1:-}"
  case "${shell_name}" in
    zsh) printf '%s' "$HOME/.zshrc" ;;
    bash) printf '%s' "$HOME/.bashrc" ;;
    *)
      plume_err "unsupported shell for init shell: ${shell_name} (use zsh|bash)"
      return 2
      ;;
  esac
}

plume_init_shell_exec_cmd() {
  if command -v plumectl >/dev/null 2>&1; then
    printf '%s' "plumectl"
    return 0
  fi
  if [[ -n "${ROOT_DIR:-}" && -x "${ROOT_DIR}/plume.sh" ]]; then
    printf '%s' "${ROOT_DIR}/plume.sh"
    return 0
  fi
  if [[ -x "./plume.sh" ]]; then
    printf '%s' "./plume.sh"
    return 0
  fi
  plume_err "could not resolve plume executable for shell init"
  return 2
}

plume_init_shell_block() {
  local plume_exec="${1:-}"
  cat <<EOF
# >>> plume php shim >>>
eval "\$(${plume_exec} php shim env)"
# <<< plume php shim <<<
EOF
}

plume_init_shell_write_block() {
  local rc_file="${1:-}"
  local block="${2:-}"
  local force="${3:-false}"
  local begin="# >>> plume php shim >>>"
  local end="# <<< plume php shim <<<"

  mkdir -p "$(dirname "${rc_file}")"
  touch "${rc_file}"

  if grep -Fq "${begin}" "${rc_file}"; then
    if [[ "${force}" != "true" ]]; then
      plume_info "shell init already configured in ${rc_file}"
      return 0
    fi
    local tmp_file
    tmp_file="$(mktemp)"
    awk -v b="${begin}" -v e="${end}" '
      $0==b {skip=1; next}
      $0==e {skip=0; next}
      skip!=1 {print}
    ' "${rc_file}" > "${tmp_file}"
    mv "${tmp_file}" "${rc_file}"
  fi

  {
    printf '\n%s\n' "${block}"
  } >> "${rc_file}"
  plume_info "shell init configured: ${rc_file}"
}

cmd_init_shell() {
  local shell_name rc_file="" force="false"
  shell_name="$(plume_init_shell_default)"

  local arg
  for arg in "$@"; do
    case "${arg}" in
      --shell=*) shell_name="${arg#*=}" ;;
      --rc=*) rc_file="${arg#*=}" ;;
      --force) force="true" ;;
      *)
        plume_err "unknown init shell option: ${arg}"
        return 2
        ;;
    esac
  done

  if [[ -z "${rc_file}" ]]; then
    rc_file="$(plume_init_shell_rc_file "${shell_name}")" || return 2
  fi

  cmd_php_shim_install >/dev/null
  local plume_exec block
  plume_exec="$(plume_init_shell_exec_cmd)" || return 2
  block="$(plume_init_shell_block "${plume_exec}")"
  plume_init_shell_write_block "${rc_file}" "${block}" "${force}"
  plume_info "open new shell or run: source ${rc_file}"
}

cmd_init() {
  local sub="${1:-shell}"
  shift || true
  case "${sub}" in
    shell) cmd_init_shell "$@" ;;
    host) cmd_init_host "$@" ;;
    onboarding) cmd_init_onboarding "$@" ;;
    permissions) cmd_init_permissions "$@" ;;
    *)
      plume_err "unknown init subcommand: ${sub} (use shell|host|onboarding|permissions)"
      return 2
      ;;
  esac
}
