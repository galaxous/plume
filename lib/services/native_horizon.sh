#!/usr/bin/env bash
set -euo pipefail

# Native Laravel Horizon via system supervisor (D-149). Per-site programs: plume-horizon-<site-id>.

plume_native_horizon_legacy_program_name() {
  printf '%s' "plume-horizon"
}

plume_native_horizon_program_name_for_site() {
  local site_id="$1"
  if [[ "${site_id}" == "__legacy__" ]]; then
    plume_native_horizon_legacy_program_name
    return 0
  fi
  printf 'plume-horizon-%s' "${site_id}"
}

# Backward compat alias
plume_native_horizon_program_name() {
  plume_native_horizon_legacy_program_name
}

plume_native_horizon_site_enabled() {
  local file="$1"
  [[ "$(plume_sites_record_horizon_enabled "${file}")" == "true" ]]
}

plume_native_horizon_list_enabled_site_ids() {
  local id file path
  while IFS= read -r id; do
    [[ -z "${id}" ]] && continue
    file="$(plume_sites_file "${id}" 2>/dev/null || true)"
    [[ -f "${file}" ]] || continue
    plume_native_horizon_site_enabled "${file}" || continue
    path="$(plume_sites_record_value "${file}" path 2>/dev/null || true)"
    [[ -n "${path}" && -f "${path}/artisan" ]] || continue
    printf '%s\n' "${id}"
  done < <(plume_sites_index_ids 2>/dev/null || true)
}

plume_native_horizon_project_path_legacy() {
  local path="" id file candidate

  if [[ -n "${PLUME_HORIZON_PATH:-}" ]]; then
    path="${PLUME_HORIZON_PATH}"
    if [[ "${path}" != /* ]]; then
      path="$(cd "${path}" 2>/dev/null && pwd || true)"
    fi
    if [[ -n "${path}" && -f "${path}/artisan" ]]; then
      printf '%s' "${path}"
      return 0
    fi
  fi

  if declare -F plume_sites_index_ids >/dev/null 2>&1; then
    while IFS= read -r id; do
      [[ -z "${id}" ]] && continue
      file="$(plume_sites_file "${id}" 2>/dev/null || true)"
      [[ -f "${file}" ]] || continue
      candidate="$(plume_sites_record_value "${file}" path 2>/dev/null || true)"
      [[ -n "${candidate}" && -f "${candidate}/artisan" ]] || continue
      printf '%s' "${candidate}"
      return 0
    done < <(plume_sites_index_ids)
  fi

  if declare -F plume_laravel_resolve_project_context >/dev/null 2>&1; then
    if plume_laravel_resolve_project_context "" >/dev/null 2>&1 \
      && [[ -n "${PLUME_LARAVEL_PROJECT_PATH:-}" && -f "${PLUME_LARAVEL_PROJECT_PATH}/artisan" ]]; then
      printf '%s' "${PLUME_LARAVEL_PROJECT_PATH}"
      return 0
    fi
  fi

  return 1
}

plume_native_horizon_site_project_path() {
  local site_id="$1"
  local file path

  if [[ "${site_id}" == "__legacy__" ]]; then
    plume_native_horizon_project_path_legacy
    return $?
  fi

  file="$(plume_sites_file "${site_id}" 2>/dev/null || true)"
  [[ -f "${file}" ]] || return 1
  path="$(plume_sites_record_value "${file}" path 2>/dev/null || true)"
  if [[ -n "${path}" && -f "${path}/artisan" ]]; then
    if [[ "${path}" != /* ]]; then
      path="$(cd "${path}" 2>/dev/null && pwd || true)"
    fi
    [[ -n "${path}" && -f "${path}/artisan" ]] || return 1
    printf '%s' "${path}"
    return 0
  fi
  return 1
}

plume_native_horizon_php_bin_for_site() {
  local site_id="$1"
  local project="" version="" php_bin="" file

  project="$(plume_native_horizon_site_project_path "${site_id}")" || return 1

  if [[ -n "${PLUME_PHP_BIN:-}" ]]; then
    printf '%s' "${PLUME_PHP_BIN}"
    return 0
  fi

  if [[ "${site_id}" != "__legacy__" ]]; then
    file="$(plume_sites_file "${site_id}" 2>/dev/null || true)"
    if [[ -f "${file}" ]]; then
      version="$(plume_sites_record_php_version "${file}" 2>/dev/null || true)"
    fi
  elif declare -F plume_sites_index_ids >/dev/null 2>&1; then
    local id
    while IFS= read -r id; do
      [[ -z "${id}" ]] && continue
      file="$(plume_sites_file "${id}" 2>/dev/null || true)"
      [[ -f "${file}" ]] || continue
      if [[ "$(plume_sites_record_value "${file}" path 2>/dev/null || true)" == "${project}" ]]; then
        version="$(plume_sites_record_php_version "${file}" 2>/dev/null || true)"
        break
      fi
    done < <(plume_sites_index_ids)
  fi

  if [[ -z "${version}" || "${version}" == "default" ]]; then
    version="${PLUME_PHP_DEFAULT_VERSION:-${PLUME_PHP_VERSION:-8.3}}"
  fi

  if declare -F plume_php_find_cli_bin >/dev/null 2>&1; then
    php_bin="$(plume_php_find_cli_bin "${version}" 2>/dev/null || true)"
  fi
  if [[ -n "${php_bin}" ]]; then
    printf '%s' "${php_bin}"
    return 0
  fi
  if command -v php >/dev/null 2>&1; then
    printf '%s' "$(command -v php)"
    return 0
  fi
  return 1
}

plume_native_horizon_resolve_targets() {
  local site_filter="${PLUME_HORIZON_SITE_ID:-}"
  local id
  local -a targets=()

  if [[ -n "${site_filter}" ]]; then
    if ! plume_sites_exists "${site_filter}"; then
      plume_err "site not found: ${site_filter}"
      return 2
    fi
    if ! plume_native_horizon_site_project_path "${site_filter}" >/dev/null 2>&1; then
      plume_err "site ${site_filter} has no Laravel project with artisan"
      return 2
    fi
    printf '%s\n' "${site_filter}"
    return 0
  fi

  while IFS= read -r id; do
    [[ -z "${id}" ]] && continue
    targets+=("${id}")
  done < <(plume_native_horizon_list_enabled_site_ids)

  if (( ${#targets[@]} > 0 )); then
    printf '%s\n' "${targets[@]}"
    return 0
  fi

  if plume_native_horizon_project_path_legacy >/dev/null 2>&1; then
    printf '%s\n' "__legacy__"
    return 0
  fi

  plume_err "no horizon targets: enable horizon on a site (site update <id> --horizon) or set PLUME_HORIZON_PATH"
  return 2
}

plume_native_horizon_write_program_for_site() {
  local site_id="$1"
  local project php_bin prog_name

  project="$(plume_native_horizon_site_project_path "${site_id}")" || return 1
  php_bin="$(plume_native_horizon_php_bin_for_site "${site_id}")" || return 1
  prog_name="$(plume_native_horizon_program_name_for_site "${site_id}")"

  export PLUME_SUPERVISOR_PROGRAM_TEMPLATE="horizon"
  export PLUME_SUPERVISOR_PROGRAM_NAME="${prog_name}"
  export PLUME_SUPERVISOR_PROGRAM_NON_INTERACTIVE="true"
  export PLUME_HORIZON_SITE_ID="${site_id}"
  plume_native_supervisor_program_add || return 1
  plume_info "native horizon: program ${prog_name} site=${site_id} project=${project} php=${php_bin}"
}

plume_native_horizon_write_program() {
  local site_id
  site_id="$(plume_native_horizon_resolve_targets | head -1 || true)"
  [[ -n "${site_id}" ]] || return 1
  plume_native_horizon_write_program_for_site "${site_id}"
}

plume_native_horizon_sync_programs() {
  local site_id rc=0 wrote="false"
  while IFS= read -r site_id; do
    [[ -z "${site_id}" ]] && continue
    if ! plume_native_horizon_write_program_for_site "${site_id}"; then
      rc=2
      continue
    fi
    wrote="true"
  done < <(plume_native_horizon_resolve_targets 2>/dev/null || true)

  if [[ "${wrote}" != "true" ]]; then
    return "${rc:-2}"
  fi
  return "${rc}"
}

plume_native_horizon_start() {
  local site_id prog_name rc=0

  if plume_native_driver_is_mock; then
    plume_native_horizon_sync_programs || true
    plume_info "native driver mock start: horizon"
    return 0
  fi

  if ! plume_native_horizon_sync_programs; then
    plume_err "native horizon: no Laravel project with artisan (site update --horizon or set PLUME_HORIZON_PATH)"
    return 2
  fi

  plume_native_supervisor_start_system || return 2
  while IFS= read -r site_id; do
    [[ -z "${site_id}" ]] && continue
    prog_name="$(plume_native_horizon_program_name_for_site "${site_id}")"
    plume_native_supervisor_reload_program "${prog_name}" || rc=2
  done < <(plume_native_horizon_resolve_targets)
  if ! plume_native_horizon_health; then
    plume_native_horizon_diagnose_failure || true
    return 2
  fi
  return "${rc}"
}

plume_native_horizon_log_file_for_site() {
  local site_id="$1"
  if [[ "${site_id}" == "__legacy__" ]]; then
    plume_service_log_file horizon native 2>/dev/null || printf '%s/logs/services/native/horizon.log' "$(plume_state_dir)"
    return 0
  fi
  printf '%s/logs/services/native/horizon-%s.log' "$(plume_state_dir)" "${site_id}"
}

plume_native_horizon_diagnose_failure() {
  local site_id prog_name st log_file project=""
  local any="false"

  plume_warn "horizon diagnose (Plume-managed; no supervisorctl needed):"
  while IFS= read -r site_id; do
    [[ -z "${site_id}" ]] && continue
    any="true"
    prog_name="$(plume_native_horizon_program_name_for_site "${site_id}")"
    st="$(plume_native_supervisor_program_status "${prog_name}" 2>/dev/null || true)"
    [[ -z "${st}" ]] && st="${prog_name} (no status from supervisord — try: plumectl services restart supervisor)"
    plume_warn "  program: ${st}"
    log_file="$(plume_native_horizon_log_file_for_site "${site_id}")"
    if [[ -f "${log_file}" ]]; then
      plume_warn "  log: ${log_file}"
      tail -n 20 "${log_file}" 2>/dev/null | while IFS= read -r line; do
        plume_warn "    ${line}"
      done || true
    else
      plume_warn "  log: ${log_file} (empty — process may not have started)"
    fi
    if declare -F plume_native_horizon_site_project_path >/dev/null 2>&1; then
      project="$(plume_native_horizon_site_project_path "${site_id}" 2>/dev/null || true)"
    fi
    if [[ -n "${project}" ]]; then
      plume_warn "  project: ${project} — check QUEUE_CONNECTION/REDIS_* in .env"
    fi
  done < <(plume_native_horizon_resolve_targets 2>/dev/null || true)

  if [[ "${any}" != "true" ]]; then
    prog_name="$(plume_native_horizon_legacy_program_name)"
    st="$(plume_native_supervisor_program_status "${prog_name}" 2>/dev/null || true)"
    plume_warn "  program: ${st:-${prog_name} unknown}"
  fi

  plume_warn "next: plumectl doctor supervisor"
  plume_warn "next: plumectl services logs horizon --tail=50"
  plume_warn "next: plumectl services restart horizon"
}

plume_native_horizon_print_logs() {
  local tail_count="${1:-30}"
  local follow="${2:-false}"
  local site_id log_file
  local -a files=()
  local found="false"

  while IFS= read -r site_id; do
    [[ -z "${site_id}" ]] && continue
    log_file="$(plume_native_horizon_log_file_for_site "${site_id}")"
    if [[ -f "${log_file}" ]]; then
      files+=("${log_file}")
      found="true"
    fi
  done < <(plume_native_horizon_resolve_targets 2>/dev/null || true)

  if [[ "${found}" != "true" ]]; then
    log_file="$(plume_native_horizon_log_file_for_site "__legacy__")"
    if [[ -f "${log_file}" ]]; then
      files+=("${log_file}")
      found="true"
    fi
  fi

  if [[ "${found}" != "true" ]]; then
    # Fall back to any horizon-*.log under native logs
    local dir
    dir="$(plume_state_dir)/logs/services/native"
    if [[ -d "${dir}" ]]; then
      while IFS= read -r log_file; do
        [[ -z "${log_file}" ]] && continue
        files+=("${log_file}")
        found="true"
      done < <(find "${dir}" -maxdepth 1 -type f \( -name 'horizon-*.log' -o -name 'horizon.log' \) 2>/dev/null | sort)
    fi
  fi

  if [[ "${found}" != "true" ]]; then
    printf '%s\n' "no logs yet for horizon (native) — run: plumectl services up horizon"
    return 0
  fi

  if [[ "${follow}" == "true" ]]; then
    if (( ${#files[@]} == 1 )); then
      tail -n "${tail_count}" -f "${files[0]}"
    else
      tail -n "${tail_count}" -f "${files[@]}"
    fi
    return 0
  fi

  local f
  for f in "${files[@]}"; do
    printf '%s\n' "--- ${f} ---"
    tail -n "${tail_count}" "${f}" 2>/dev/null || true
  done
}

plume_native_horizon_stop() {
  local site_id prog_name

  if plume_native_driver_is_mock; then
    return 0
  fi

  while IFS= read -r site_id; do
    [[ -z "${site_id}" ]] && continue
    prog_name="$(plume_native_horizon_program_name_for_site "${site_id}")"
    plume_native_supervisorctl stop "${prog_name}" >/dev/null 2>&1 || true
  done < <(plume_native_horizon_resolve_targets 2>/dev/null || true)

  plume_native_supervisorctl stop "$(plume_native_horizon_legacy_program_name)" >/dev/null 2>&1 || true
}

plume_native_horizon_program_running() {
  local prog_name="$1"
  local st
  st="$(plume_native_supervisor_program_status "${prog_name}" 2>/dev/null || true)"
  printf '%s' "${st}" | grep -Eq 'RUNNING|STARTING'
}

plume_native_horizon_health() {
  local site_id prog_name total=0 running=0

  if plume_native_driver_is_mock; then
    return 0
  fi
  plume_native_supervisor_health || return 1

  while IFS= read -r site_id; do
    [[ -z "${site_id}" ]] && continue
    total=$((total + 1))
    prog_name="$(plume_native_horizon_program_name_for_site "${site_id}")"
    if plume_native_horizon_program_running "${prog_name}"; then
      running=$((running + 1))
    fi
  done < <(plume_native_horizon_resolve_targets 2>/dev/null || true)

  if [[ "${total}" -eq 0 ]]; then
    prog_name="$(plume_native_horizon_legacy_program_name)"
    plume_native_horizon_program_running "${prog_name}"
    return $?
  fi

  [[ "${running}" -eq "${total}" ]]
}

plume_native_horizon_program_file() {
  local site_id="${PLUME_HORIZON_SITE_ID:-__legacy__}"
  plume_native_supervisor_program_conf_path "$(plume_native_horizon_program_name_for_site "${site_id}")"
}

plume_native_supervisor_sock() {
  printf '%s' ""
}

plume_native_supervisor_conf() {
  plume_native_supervisor_main_conf_path
}
