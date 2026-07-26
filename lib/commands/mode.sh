#!/usr/bin/env bash
set -euo pipefail

plume_mode_file() {
  printf '%s' "$(plume_state_dir)/mode"
}

plume_mode_path_file() {
  local mode="$1"
  printf '%s' "$(plume_state_dir)/mode-path-${mode}"
}

plume_mode_active_path_file() {
  printf '%s' "$(plume_state_dir)/mode-path-active"
}

plume_mode_path_get_direct() {
  local mode="$1"
  local file
  file="$(plume_mode_path_file "${mode}")"
  [[ -f "${file}" ]] || return 1
  cat "${file}"
}

plume_mode_active_path_get() {
  local file
  file="$(plume_mode_active_path_file)"
  [[ -f "${file}" ]] || return 1
  cat "${file}"
}

plume_mode_active_path_set() {
  local path="$1"
  printf '%s\n' "${path}" > "$(plume_mode_active_path_file)"
}

plume_mode_active_path_clear() {
  rm -f "$(plume_mode_active_path_file)"
}

plume_context_lock_file() {
  printf '%s' "$(plume_state_dir)/context.lock"
}

plume_context_lock_is_active() {
  local file
  file="$(plume_context_lock_file)"
  [[ -f "${file}" ]]
}

plume_context_lock_get_value() {
  local key="$1"
  local file line
  file="$(plume_context_lock_file)"
  [[ -f "${file}" ]] || return 1
  line="$(grep -E "^${key}=" "${file}" || true)"
  [[ -n "${line}" ]] || return 1
  printf '%s' "${line#*=}"
}

plume_context_lock_activate() {
  local reason="${1:-manual}"
  local mode="${2:-}"
  local path="${3:-}"
  local file
  if [[ -z "${mode}" ]]; then
    mode="$(plume_mode_current)"
  fi
  if [[ -z "${path}" ]]; then
    path="$(plume_mode_path_get "${mode}" || true)"
  fi
  file="$(plume_context_lock_file)"
  mkdir -p "$(dirname "${file}")"
  {
    printf 'locked=true\n'
    printf 'mode=%s\n' "${mode}"
    printf 'path=%s\n' "${path}"
    printf 'reason=%s\n' "${reason}"
    printf 'updated_at=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
  } > "${file}"
  plume_state_db_set_lock "global_context" "true" "${mode}" "${path}" "${reason}"
}

plume_context_lock_clear() {
  rm -f "$(plume_context_lock_file)"
  plume_state_db_set_lock "global_context" "false" "" "" "cleared"
}

plume_compose_has_running_containers() {
  local compose_file="$1"
  local ids id running
  [[ -n "${compose_file}" && -f "${compose_file}" ]] || return 1
  if ! plume_docker_compose_has_v2 && ! plume_docker_compose_has_v1; then
    return 1
  fi

  # Prefer explicit running-only list when supported.
  ids="$(plume_docker_compose_exec "${compose_file}" ps --status running -q 2>/dev/null || true)"
  if [[ -z "${ids}" ]]; then
    ids="$(plume_docker_compose_exec "${compose_file}" ps -q 2>/dev/null || true)"
  fi
  [[ -n "${ids}" ]] || return 1

  # If inspect fails for any reason, treat `ps -q` presence as active workload.
  for id in ${ids}; do
    running="$(docker inspect -f '{{.State.Running}}' "${id}" 2>/dev/null || true)"
    if [[ "${running}" == "true" ]]; then
      return 0
    fi
    if [[ -z "${running}" ]]; then
      return 0
    fi
  done
  return 1
}

plume_native_has_running_state() {
  local file
  file="$(plume_services_runtime_file native)"
  [[ -f "${file}" ]] || return 1
  grep -qE '^[a-zA-Z0-9_]+\.running=true$' "${file}" 2>/dev/null
}

plume_laradock_running_at_path() {
  local path="$1"
  local compose_file
  [[ -n "${path}" && -d "${path}" ]] || return 1
  compose_file="${path}/docker-compose.yml"
  if [[ ! -f "${compose_file}" ]]; then
    compose_file="${path}/compose.yml"
  fi
  plume_compose_has_running_containers "${compose_file}"
}

plume_context_lock_has_live_workloads() {
  local lock_mode lock_path
  lock_mode="$(plume_context_lock_get_value mode || true)"
  lock_path="$(plume_context_lock_get_value path || true)"
  case "${lock_mode}" in
    docker-lite)
      if [[ -n "${lock_path}" ]] && plume_docker_lite_running_at_path "${lock_path}"; then
        return 0
      fi
      return 1
      ;;
    laradock-bridge)
      if [[ -n "${lock_path}" ]] && plume_laradock_running_at_path "${lock_path}"; then
        return 0
      fi
      return 1
      ;;
    native)
      plume_native_has_running_state
      return $?
      ;;
    *)
      # Unknown lock mode -> treat as stale.
      return 1
      ;;
  esac
}

plume_context_lock_refresh() {
  if ! plume_context_lock_is_active; then
    return 0
  fi
  if plume_context_lock_has_live_workloads; then
    return 0
  fi
  plume_context_lock_clear
  return 0
}

plume_context_lock_try_clear_if_idle() {
  local has_live="false"
  local dl_path lb_path
  if plume_native_has_running_state; then
    has_live="true"
  fi
  dl_path="$(plume_mode_path_get docker-lite || true)"
  if [[ "${has_live}" == "false" && -n "${dl_path}" ]] && plume_docker_lite_running_at_path "${dl_path}"; then
    has_live="true"
  fi
  lb_path="$(plume_mode_path_get laradock-bridge || true)"
  if [[ "${has_live}" == "false" && -n "${lb_path}" ]] && plume_laradock_running_at_path "${lb_path}"; then
    has_live="true"
  fi
  if [[ "${has_live}" == "false" ]]; then
    plume_context_lock_clear
  fi
}

plume_context_lock_require_change_allowed() {
  local mode="$1"
  local force="${2:-false}"
  plume_context_lock_refresh
  if [[ "${force}" == "true" ]]; then
    return 0
  fi
  if plume_context_lock_is_active; then
    plume_err "global context is locked after setup; use --force to change ${mode} path/mode"
    return 2
  fi
  return 0
}

plume_mode_path_compose_file() {
  local path="$1"
  if [[ -f "${path}/docker-compose.yml" ]]; then
    printf '%s' "${path}/docker-compose.yml"
    return 0
  fi
  if [[ -f "${path}/compose.yml" ]]; then
    printf '%s' "${path}/compose.yml"
    return 0
  fi
  return 1
}

plume_mode_path_validate_safe_switch() {
  local mode="$1"
  local old_path="$2"
  local new_path="$3"
  [[ "${mode}" == "docker-lite" ]] || return 0
  [[ -n "${old_path}" && "${old_path}" != "${new_path}" ]] || return 0

  local old_compose
  old_compose="$(plume_mode_path_compose_file "${old_path}" || true)"
  if [[ -n "${old_compose}" ]] && (plume_docker_compose_has_v2 || plume_docker_compose_has_v1); then
    if [[ -n "$(plume_docker_compose_exec "${old_compose}" ps -q 2>/dev/null || true)" ]]; then
      plume_err "docker-lite path switch blocked: running containers detected at ${old_path}; run services workspace down first"
      return 2
    fi
  fi
  return 0
}

plume_docker_lite_running_at_path() {
  local path="$1"
  local compose_file
  local ids id running
  compose_file="$(plume_mode_path_compose_file "${path}" || true)"
  [[ -n "${compose_file}" ]] || return 1
  if ! plume_docker_compose_has_v2 && ! plume_docker_compose_has_v1; then
    return 1
  fi
  ids="$(plume_docker_compose_exec "${compose_file}" ps -q 2>/dev/null || true)"
  [[ -n "${ids}" ]] || return 1
  for id in ${ids}; do
    running="$(docker inspect -f '{{.State.Running}}' "${id}" 2>/dev/null || true)"
    if [[ "${running}" == "true" ]]; then
      return 0
    fi
  done
  return 1
}

plume_mode_guard_docker_lite_down_for_change() {
  local target_mode="${1:-}"
  local target_path="${2:-}"
  local current_mode current_path
  current_mode="$(plume_mode_current)"
  [[ "${current_mode}" == "docker-lite" ]] || return 0
  current_path="$(plume_mode_path_get docker-lite || true)"
  [[ -n "${current_path}" ]] || return 0

  local changing_mode="false"
  local changing_path="false"
  if [[ -n "${target_mode}" && "${target_mode}" != "${current_mode}" ]]; then
    changing_mode="true"
  fi
  if [[ -n "${target_path}" && "${target_path}" != "${current_path}" ]]; then
    changing_path="true"
  fi
  if [[ -z "${target_path}" && "${target_mode}" == "docker-lite-clear-path" ]]; then
    changing_path="true"
  fi
  if [[ "${changing_mode}" != "true" && "${changing_path}" != "true" ]]; then
    return 0
  fi

  if plume_docker_lite_running_at_path "${current_path}"; then
    plume_err "docker-lite containers are running at ${current_path}; run './plume.sh services workspace down --mode=docker-lite' before mode/path change"
    return 2
  fi
  return 0
}

plume_mode_guard_laradock_down_for_change() {
  local target_mode="${1:-}"
  local allow_down="${2:-false}"
  local current_mode current_path compose_file
  current_mode="$(plume_mode_current)"
  [[ "${current_mode}" == "laradock-bridge" ]] || return 0
  [[ "${target_mode}" != "laradock-bridge" ]] || return 0

  current_path="$(plume_mode_path_get laradock-bridge || true)"
  [[ -n "${current_path}" ]] || return 0
  if ! plume_laradock_running_at_path "${current_path}"; then
    return 0
  fi

  if [[ "${allow_down}" != "true" ]]; then
    plume_err "laradock-bridge containers are running at ${current_path}; use --down-running to auto-stop or run: (cd ${current_path} && docker compose down)"
    return 2
  fi

  compose_file="$(plume_mode_path_compose_file "${current_path}" || true)"
  if [[ -z "${compose_file}" || ! -f "${compose_file}" ]]; then
    plume_err "laradock-bridge compose file not found for auto-down: ${current_path}"
    return 2
  fi
  if ! plume_docker_compose_has_v2 && ! plume_docker_compose_has_v1; then
    plume_err "docker compose is required for --down-running auto-stop"
    return 2
  fi

  plume_warn "running laradock-bridge containers detected; stopping before mode switch"
  if ! plume_docker_compose_exec "${compose_file}" down; then
    plume_err "failed to stop laradock-bridge containers before mode switch"
    return 2
  fi

  plume_context_lock_try_clear_if_idle
  plume_state_db_append_event "laradock-bridge" "" "mode.switch.auto_down" "from=laradock-bridge,to=${target_mode},path=${current_path}"
  plume_info "laradock-bridge containers stopped for mode switch"
  return 0
}

plume_docker_lite_reconcile_stopped_state_if_idle() {
  local dl_path
  dl_path="$(plume_mode_path_get docker-lite || true)"
  if [[ -n "${dl_path}" ]] && plume_docker_lite_running_at_path "${dl_path}"; then
    return 0
  fi
  local service
  while IFS= read -r service; do
    [[ -z "${service}" ]] && continue
    plume_services_runtime_set "${service}" "running" "false" "docker-lite"
  done < <(plume_service_names_for_mode "docker-lite")
  plume_state_db_append_event "docker-lite" "" "reconcile.stopped" "mode-switch/no-running-containers"
}

plume_mode_path_get() {
  local mode="${1:-$(plume_mode_current)}"
  local current_mode
  current_mode="$(plume_mode_current)"
  if plume_mode_path_get_direct "${mode}" >/dev/null 2>&1; then
    plume_mode_path_get_direct "${mode}"
    return 0
  fi
  if [[ "${mode}" == "${current_mode}" ]]; then
    plume_mode_active_path_get
    return $?
  fi
  return 1
}

plume_mode_path_set() {
  local mode="$1"
  local path="$2"
  printf '%s\n' "${path}" > "$(plume_mode_path_file "${mode}")"
  if [[ "${mode}" == "$(plume_mode_current)" ]]; then
    plume_mode_active_path_set "${path}"
  fi
}

plume_mode_path_clear() {
  local mode="$1"
  rm -f "$(plume_mode_path_file "${mode}")"
  if [[ "${mode}" == "$(plume_mode_current)" ]]; then
    plume_mode_active_path_clear
  fi
}

plume_mode_current() {
  if [[ -n "${PLUME_MODE:-}" ]]; then
    echo "${PLUME_MODE}"
    return 0
  fi

  if [[ -f "$(plume_mode_file)" ]]; then
    cat "$(plume_mode_file)"
    return 0
  fi

  echo "native"
}

cmd_mode() {
  local sub="${1:-current}"
  case "${sub}" in
    current)
      plume_mode_current
      ;;
    context)
      cmd_context "$@"
      ;;
    use)
      local mode=""
      local current_mode
      local force="false"
      local down_running="false"
      local token
      current_mode="$(plume_mode_current)"

      for token in "${@:2}"; do
        [[ -z "${token}" ]] && continue
        case "${token}" in
          --force)
            force="true"
            ;;
          --down-running|--auto-down|--stop-running)
            down_running="true"
            ;;
          native|docker-lite|laradock-bridge)
            if [[ -z "${mode}" ]]; then
              mode="${token}"
            else
              plume_err "mode name provided more than once: ${token}"
              return 2
            fi
            ;;
          *)
            if [[ -z "${mode}" ]]; then
              mode="${token}"
            else
              plume_err "unknown mode use option: ${token}"
              return 2
            fi
            ;;
        esac
      done

      if [[ -z "${mode}" ]]; then
        plume_err "mode name required"
        return 2
      fi
      case "${mode}" in
        native|docker-lite|laradock-bridge) ;;
        *)
          plume_err "invalid mode: ${mode}"
          return 2
          ;;
      esac
      if ! plume_context_lock_require_change_allowed "mode" "${force}"; then
        return 2
      fi
      if [[ "${force}" == "true" ]]; then
        if ! plume_require_yes_for_critical "${current_mode}" "critical.mode.use.force" "from=${current_mode},to=${mode}" "Use --yes mode use <mode> --force"; then
          return 2
        fi
      fi
      if ! plume_mode_guard_docker_lite_down_for_change "${mode}" ""; then
        return 2
      fi
      if ! plume_mode_guard_laradock_down_for_change "${mode}" "${down_running}"; then
        return 2
      fi
      if [[ "${current_mode}" == "docker-lite" && "${mode}" != "docker-lite" ]]; then
        plume_docker_lite_reconcile_stopped_state_if_idle
      fi
      printf '%s\n' "${mode}" > "$(plume_mode_file)"
      if plume_mode_path_get_direct "${mode}" >/dev/null 2>&1; then
        plume_mode_active_path_set "$(plume_mode_path_get_direct "${mode}")"
      else
        plume_mode_active_path_clear
      fi
      plume_state_db_append_event "${mode}" "" "mode.use" "mode=${mode}"
      plume_info "mode set to ${mode}"
      ;;
    path)
      local action="${2:-list}"
      case "${action}" in
        set)
          local mode path token
          local force="false"
          mode="$(plume_mode_current)"
          for token in "${3:-}" "${4:-}" "${5:-}"; do
            [[ -z "${token}" ]] && continue
            if [[ "${token}" == "--force" ]]; then
              force="true"
              continue
            fi
            if [[ "${token}" == "docker-lite" || "${token}" == "laradock-bridge" ]]; then
              mode="${token}"
              continue
            fi
            if [[ -z "${path:-}" ]]; then
              path="${token}"
            fi
          done
          if [[ -z "${path}" ]]; then
            plume_err "usage: mode path set [docker-lite|laradock-bridge] <path>"
            return 2
          fi
          case "${mode}" in
            docker-lite|laradock-bridge) ;;
            *)
              plume_err "active mode does not support path set: ${mode} (supported: docker-lite|laradock-bridge)"
              return 2
              ;;
          esac
          if ! plume_context_lock_require_change_allowed "${mode}" "${force}"; then
            return 2
          fi
          if [[ "${force}" == "true" ]]; then
            if ! plume_require_yes_for_critical "${mode}" "critical.mode.path.set.force" "mode=${mode},path=${path}" "Use --yes mode path set ... --force"; then
              return 2
            fi
          fi
          if [[ "${path}" != /* ]]; then
            path="$(cd "${path}" 2>/dev/null && pwd || true)"
          fi
          if [[ -z "${path}" || ! -d "${path}" ]]; then
            plume_err "invalid path: ${path}"
            return 2
          fi
          local current_path
          current_path="$(plume_mode_path_get_direct "${mode}" || true)"
          if [[ -n "${current_path}" && "${current_path}" != "${path}" && "${force}" != "true" ]]; then
            plume_err "path already set for ${mode}: ${current_path}; use --force to change it"
            return 2
          fi
          if [[ -n "${current_path}" && "${current_path}" != "${path}" ]]; then
            if ! plume_mode_guard_docker_lite_down_for_change "" "${path}"; then
              return 2
            fi
            if ! plume_mode_path_validate_safe_switch "${mode}" "${current_path}" "${path}"; then
              return 2
            fi
          fi
          plume_mode_path_set "${mode}" "${path}"
          if [[ "${mode}" == "docker-lite" ]] && ! plume_mode_path_compose_file "${path}" >/dev/null 2>&1; then
            plume_warn "docker-lite compose not found under ${path}; run: ./plume.sh services workspace init"
          fi
          plume_state_db_append_event "${mode}" "" "mode.path.set" "path=${path}"
          plume_info "${mode} path set to ${path}"
          ;;
        get)
          local mode="${3:-$(plume_mode_current)}"
          case "${mode}" in
            docker-lite|laradock-bridge) ;;
            *)
              plume_err "active mode does not support path get: ${mode} (supported: docker-lite|laradock-bridge)"
              return 2
              ;;
          esac
          plume_mode_path_get "${mode}" || true
          ;;
        clear)
          local mode="${3:-$(plume_mode_current)}"
          local force="false"
          if [[ "${3:-}" == "--force" || "${4:-}" == "--force" ]]; then
            force="true"
          fi
          if [[ "${mode}" == "--force" ]]; then
            mode="$(plume_mode_current)"
          fi
          case "${mode}" in
            docker-lite|laradock-bridge) ;;
            *)
              plume_err "active mode does not support path clear: ${mode} (supported: docker-lite|laradock-bridge)"
              return 2
              ;;
          esac
          if ! plume_context_lock_require_change_allowed "${mode}" "${force}"; then
            return 2
          fi
          if [[ "${force}" == "true" ]]; then
            if ! plume_require_yes_for_critical "${mode}" "critical.mode.path.clear.force" "mode=${mode}" "Use --yes mode path clear ... --force"; then
              return 2
            fi
          fi
          if [[ "${mode}" == "docker-lite" ]]; then
            if ! plume_mode_guard_docker_lite_down_for_change "docker-lite-clear-path" ""; then
              return 2
            fi
          fi
          plume_mode_path_clear "${mode}"
          plume_state_db_append_event "${mode}" "" "mode.path.clear" ""
          plume_info "${mode} path cleared"
          ;;
        list)
          local dl lb active_mode active_path
          local lock_state lock_reason
          plume_context_lock_refresh
          active_mode="$(plume_mode_current)"
          active_path="$(plume_mode_path_get "${active_mode}" || true)"
          if plume_context_lock_is_active; then
            lock_state="locked"
            lock_reason="$(plume_context_lock_get_value reason || true)"
          else
            lock_state="unlocked"
            lock_reason=""
          fi
          dl="$(plume_mode_path_get docker-lite || true)"
          lb="$(plume_mode_path_get laradock-bridge || true)"
          printf 'lock\t%s\t%s\n' "${lock_state}" "${lock_reason}"
          printf 'active\t%s\t%s\n' "${active_mode}" "${active_path}"
          printf 'docker-lite\t%s\n' "${dl}"
          printf 'laradock-bridge\t%s\n' "${lb}"
          ;;
        *)
          plume_err "unknown mode path action: ${action} (use set|get|clear|list)"
          return 2
          ;;
      esac
      ;;
    *)
      plume_err "unknown mode subcommand: ${sub}"
      return 2
      ;;
  esac
}
