#!/usr/bin/env bash
set -euo pipefail

plume_prereq_profiles() {
  cat <<'LIST'
base
native-install
git-ops
docker-lite
security-check
horizon-runtime
laravel-bootstrap
frontend-build
LIST
}

plume_prereq_commands_for_profile() {
  local profile="$1"
  case "${profile}" in
    base) echo "bash sed awk grep cut xargs tar gzip curl" ;;
    native-install)
      local pm
      pm="$(plume_detect_package_manager)"
      case "${pm}" in
        brew|apt|dnf) echo "sudo ${pm}" ;;
        *) echo "sudo" ;;
      esac
      ;;
    git-ops) echo "git ssh" ;;
    docker-lite) echo "docker" ;;
    security-check)
      if [[ "$(plume_detect_os)" == "macos" ]]; then
        echo "pfctl"
      else
        echo "getenforce"
      fi
      ;;
    horizon-runtime) echo "php supervisorctl" ;;
    laravel-bootstrap) echo "php composer" ;;
    frontend-build) echo "node npm" ;;
    *) return 1 ;;
  esac
}

plume_prereq_reason_for_profile() {
  local profile="$1"
  case "${profile}" in
    base) echo "Core shell/runtime commands for all plume operations" ;;
    native-install) echo "Required for host package installation and service provisioning" ;;
    git-ops) echo "Required for repository and remote operations" ;;
    docker-lite) echo "Required for docker-lite and laradock-bridge workflows" ;;
    security-check) echo "Required for firewall and OS security preflight checks" ;;
    horizon-runtime) echo "Required for Horizon runtime process control" ;;
    laravel-bootstrap) echo "Required for Laravel project bootstrap" ;;
    frontend-build) echo "Required for frontend build and dev server workflows" ;;
    *) return 1 ;;
  esac
}

plume_prereq_pkg_for_command() {
  local cmd="$1"
  case "${cmd}" in
    awk) echo "gawk" ;;
    ssh) echo "openssh" ;;
    getenforce) echo "libselinux-utils" ;;
    supervisorctl) echo "supervisor" ;;
    *) echo "${cmd}" ;;
  esac
}

plume_prereq_check_profile() {
  local profile="$1"

  local commands
  if ! commands="$(plume_prereq_commands_for_profile "${profile}")"; then
    plume_err "unknown prereq profile: ${profile}"
    return 2
  fi

  local pm
  local os
  os="$(plume_detect_os)"
  pm="$(plume_detect_package_manager)"

  local missing_count=0
  local missing_lines=""
  local cmd
  for cmd in ${commands}; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
      missing_count=$((missing_count + 1))
      missing_lines="${missing_lines}${cmd}"$'\n'
    fi
  done

  if [[ "${pm}" == "missing" ]]; then
    missing_count=$((missing_count + 1))
    missing_lines="${missing_lines}brew"$'\n'
  fi

  if [[ "${PLUME_OUTPUT:-text}" == "json" ]]; then
    local first="true"
    printf '{"ok":'
    if [[ ${missing_count} -eq 0 ]]; then
      printf 'true'
    else
      printf 'false'
    fi
    printf ',"command":"prereq check","data":{"profile":"%s","os":"%s","package_manager":"%s","reason":"%s","missing":[' \
      "${profile}" "${os}" "${pm}" "$(plume_prereq_reason_for_profile "${profile}")"

    local missing_cmd
    while IFS= read -r missing_cmd; do
      [[ -z "${missing_cmd}" ]] && continue
      local pkg hint
      pkg="$(plume_prereq_pkg_for_command "${missing_cmd}")"
      hint="$(plume_install_hint_for "${pkg}" "${pm}")"
      if [[ "${first}" == "true" ]]; then
        first="false"
      else
        printf ','
      fi
      printf '{"command":"%s","package":"%s","hint":"%s"}' "${missing_cmd}" "${pkg}" "${hint}"
    done <<< "${missing_lines}"

    printf ']},"warnings":[],"errors":[]}
'
  else
    plume_info "prereq profile: ${profile}"
    plume_info "os=${os} package_manager=${pm}"
    if [[ ${missing_count} -eq 0 ]]; then
      plume_info "all required commands are available"
    else
      plume_err "missing required commands for profile '${profile}':"
      while IFS= read -r missing_cmd; do
        [[ -z "${missing_cmd}" ]] && continue
        local pkg hint
        pkg="$(plume_prereq_pkg_for_command "${missing_cmd}")"
        hint="$(plume_install_hint_for "${pkg}" "${pm}")"
        plume_err "- ${missing_cmd} (package: ${pkg})"
        plume_err "  hint: ${hint}"
      done <<< "${missing_lines}"
    fi
  fi

  if [[ ${missing_count} -gt 0 ]]; then
    return 2
  fi
  return 0
}

cmd_prereq_explain() {
  if [[ "${PLUME_OUTPUT:-text}" == "json" ]]; then
    local first="true"
    printf '{"ok":true,"command":"prereq explain","data":{"profiles":['
    local profile
    while IFS= read -r profile; do
      [[ -z "${profile}" ]] && continue
      if [[ "${first}" == "true" ]]; then
        first="false"
      else
        printf ','
      fi
      printf '{"name":"%s","reason":"%s"}' "${profile}" "$(plume_prereq_reason_for_profile "${profile}")"
    done < <(plume_prereq_profiles)
    printf ']},"warnings":[],"errors":[]}
'
    return 0
  fi

  echo "Prereq profiles:"
  local profile
  while IFS= read -r profile; do
    [[ -z "${profile}" ]] && continue
    printf '%-17s %s\n' "${profile}" "$(plume_prereq_reason_for_profile "${profile}")"
  done < <(plume_prereq_profiles)
}

cmd_prereq() {
  local sub="${1:-check}"
  shift || true

  case "${sub}" in
    check)
      local profile="base"
      local arg
      for arg in "$@"; do
        case "${arg}" in
          --profile=*) profile="${arg#--profile=}" ;;
          *)
            plume_err "unknown prereq check option: ${arg}"
            return 2
            ;;
        esac
      done
      plume_prereq_check_profile "${profile}"
      ;;
    explain)
      cmd_prereq_explain
      ;;
    *)
      plume_err "unknown prereq subcommand: ${sub}"
      return 2
      ;;
  esac
}
