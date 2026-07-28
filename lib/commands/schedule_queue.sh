#!/usr/bin/env bash
set -euo pipefail

plume_laravel_schedule_cron_marker() {
  printf '%s' '# plume-laravel-schedule-cron'
}

plume_laravel_parse_path_from_args() {
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --path=*) printf '%s' "${arg#*=}"; return 0 ;;
    esac
  done
  printf '%s' ""
}

plume_laravel_arg_has_dry_run() {
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --dry-run) return 0 ;;
    esac
  done
  return 1
}

plume_laravel_arg_has_remove() {
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --remove) return 0 ;;
    esac
  done
  return 1
}

plume_laravel_crontab_read() {
  if [[ -n "${PLUME_CRONTAB_FILE:-}" ]]; then
    if [[ -f "${PLUME_CRONTAB_FILE}" ]]; then
      cat "${PLUME_CRONTAB_FILE}"
    fi
    return 0
  fi
  if ! command -v crontab >/dev/null 2>&1; then
    return 1
  fi
  crontab -l 2>/dev/null || true
  return 0
}

plume_laravel_crontab_write() {
  local content="$1"
  if [[ -n "${PLUME_CRONTAB_FILE:-}" ]]; then
    printf '%s\n' "${content}" > "${PLUME_CRONTAB_FILE}"
    return 0
  fi
  local tmp
  tmp="$(mktemp)"
  printf '%s\n' "${content}" > "${tmp}"
  crontab "${tmp}"
  rm -f "${tmp}"
}

plume_laravel_resolve_php_bin() {
  local site_id="${PLUME_LARAVEL_SITE_ID:-}"
  local file version php_bin

  if [[ -n "${PLUME_PHP_BIN:-}" ]]; then
    printf '%s' "${PLUME_PHP_BIN}"
    return 0
  fi

  version=""
  if [[ -n "${site_id}" ]]; then
    file="$(plume_sites_file "${site_id}")"
    if [[ -f "${file}" ]]; then
      version="$(plume_sites_record_php_version "${file}" 2>/dev/null || true)"
    fi
  fi

  if [[ -z "${version}" || "${version}" == "default" ]]; then
    version="${PLUME_PHP_DEFAULT_VERSION:-${PLUME_PHP_VERSION:-8.3}}"
  fi

  if php_bin="$(plume_php_find_cli_bin "${version}" 2>/dev/null || true)" && [[ -n "${php_bin}" ]]; then
    printf '%s' "${php_bin}"
    return 0
  fi

  if command -v php >/dev/null 2>&1; then
    printf '%s' "php"
    return 0
  fi

  return 1
}

plume_laravel_require_artisan() {
  local project_path="$1"
  if [[ ! -f "${project_path}/artisan" ]]; then
    plume_err "no artisan file under ${project_path}"
    return 2
  fi
  return 0
}

plume_laravel_artisan_command_line() {
  local project_path="$1"
  local php_bin="$2"
  shift 2
  printf 'cd %s && %s artisan %s' "${project_path}" "${php_bin}" "$*"
}

plume_laravel_run_artisan() {
  local project_path="$1"
  local php_bin="$2"
  shift 2
  plume_project_run_in_path "${project_path}" "${php_bin}" artisan "$@"
}

plume_laravel_to_abs_path() {
  local value="$1"
  if [[ -z "${value}" ]]; then
    return 1
  fi
  if [[ "${value:0:1}" == "~" ]]; then
    value="${HOME}${value#\~}"
  fi
  if [[ "${value}" != /* ]]; then
    value="$(cd "${value}" 2>/dev/null && pwd || true)"
  fi
  [[ -n "${value}" && -d "${value}" ]] || return 1
  printf '%s' "${value}"
}

plume_laravel_resolve_project_context() {
  local explicit_raw="${1:-}"
  local explicit="" cwd id file path mode active_path

  PLUME_LARAVEL_PROJECT_PATH=""
  PLUME_LARAVEL_PROJECT_SOURCE=""
  PLUME_LARAVEL_SITE_ID=""

  if [[ -n "${explicit_raw}" ]]; then
    if ! explicit="$(plume_laravel_to_abs_path "${explicit_raw}")"; then
      plume_err "invalid --path: ${explicit_raw}"
      return 2
    fi
    PLUME_LARAVEL_PROJECT_PATH="${explicit}"
    PLUME_LARAVEL_PROJECT_SOURCE="flag:--path"
    return 0
  fi

  cwd="$(pwd -P 2>/dev/null || pwd)"

  while IFS= read -r id; do
    [[ -z "${id}" ]] && continue
    file="$(plume_sites_file "${id}")"
    [[ -f "${file}" ]] || continue
    path="$(plume_sites_record_value "${file}" path)"
    [[ -n "${path}" ]] || continue
    if [[ "${cwd}" == "${path}" || "${cwd}" == "${path}/"* ]]; then
      PLUME_LARAVEL_PROJECT_PATH="${path}"
      PLUME_LARAVEL_SITE_ID="${id}"
      PLUME_LARAVEL_PROJECT_SOURCE="site:${id}"
      return 0
    fi
  done < <(plume_sites_index_ids)

  if [[ -f "${cwd}/artisan" ]]; then
    PLUME_LARAVEL_PROJECT_PATH="${cwd}"
    PLUME_LARAVEL_PROJECT_SOURCE="cwd"
    return 0
  fi

  mode="$(plume_mode_current)"
  active_path="$(plume_mode_path_get "${mode}" || true)"
  if [[ -n "${active_path}" && -f "${active_path}/artisan" ]]; then
    if active_path="$(plume_laravel_to_abs_path "${active_path}" 2>/dev/null || true)"; then
      PLUME_LARAVEL_PROJECT_PATH="${active_path}"
      PLUME_LARAVEL_PROJECT_SOURCE="mode_path:${mode}"
      return 0
    fi
  fi

  plume_err "could not resolve Laravel project path (use --path=, register site, or run from project root)"
  return 2
}

plume_laravel_artisan_state() {
  local project_path="$1"
  if [[ -f "${project_path}/artisan" ]]; then
    printf '%s' "present"
  else
    printf '%s' "missing"
  fi
}

plume_laravel_read_env_kv() {
  local env_file="$1"
  local key="$2"
  local line
  [[ -f "${env_file}" ]] || return 1
  line="$(grep -E "^${key}=" "${env_file}" 2>/dev/null | tail -n 1 || true)"
  [[ -n "${line}" ]] || return 1
  printf '%s' "${line#*=}" | sed -e 's/^["'\'' ]*//' -e 's/["'\'' ]*$//'
}

plume_laravel_schedule_cron_state() {
  local project_path="$1"
  local marker hit path_hit generic
  marker="$(plume_laravel_schedule_cron_marker)"

  local crontab_body
  if ! crontab_body="$(plume_laravel_crontab_read)"; then
    printf '%s' "unknown"
    return 0
  fi

  hit="$(printf '%s\n' "${crontab_body}" | grep -F "${marker}" || true)"
  if [[ -n "${hit}" ]]; then
    printf '%s' "configured"
    return 0
  fi

  path_hit="$(printf '%s\n' "${crontab_body}" | grep -F "schedule:run" | grep -F "${project_path}" || true)"
  if [[ -n "${path_hit}" ]]; then
    printf '%s' "configured"
    return 0
  fi

  generic="$(printf '%s\n' "${crontab_body}" | grep -F 'schedule:run' || true)"
  if [[ -n "${generic}" ]]; then
    printf '%s' "maybe"
    return 0
  fi

  printf '%s' "not-configured"
}

plume_laravel_schedule_cron_line() {
  local project_path="$1"
  local php_bin="$2"
  printf '* * * * * cd %s && %s artisan schedule:run >> /dev/null 2>&1 %s' \
    "${project_path}" "${php_bin}" "$(plume_laravel_schedule_cron_marker)"
}

plume_laravel_schedule_cron_hint() {
  local project_path="$1"
  plume_laravel_schedule_cron_line "${project_path}" "php"
}

plume_laravel_queue_service_summary() {
  local service="$1"
  local mode="$2"
  if ! plume_service_exists "${service}" "${mode}"; then
    printf '%s\t%s\t%s\t%s\n' "${service}" "n/a" "n/a" "unsupported"
    return 0
  fi
  local status_line _svc enabled running health _port _version
  status_line="$(plume_services_display_status_line "${service}" "${mode}")"
  IFS=$'\t' read -r _svc enabled running health _port _version <<< "${status_line}"
  printf '%s\t%s\t%s\t%s\n' "${service}" "${enabled}" "${running}" "${health}"
}

plume_laravel_queue_hints() {
  local mode="$1"
  local horizon_enabled="$2"
  local supervisor_enabled="$3"
  local horizon_running="$4"
  local supervisor_running="$5"

  if [[ "${mode}" == "native" ]]; then
    if [[ "${horizon_enabled}" == "true" && "${horizon_running}" != "true" ]]; then
      plume_info "start Horizon: ./plume.sh services up horizon --mode=native"
    elif [[ "${horizon_enabled}" != "true" && "${supervisor_enabled}" == "true" && "${supervisor_running}" != "true" ]]; then
      plume_info "native supervisor is enabled but not running; full install is backlog — try: ./plume.sh services up supervisor --mode=native"
    elif [[ "${horizon_enabled}" != "true" && "${supervisor_enabled}" != "true" ]]; then
      plume_info "enable queue workers: set PLUME_HORIZON_ENABLED=true (and PLUME_SUPERVISOR_ENABLED=true) then ./plume.sh services up horizon --mode=native"
    fi
    return 0
  fi

  if [[ "${mode}" == "docker-lite" ]]; then
    plume_info "docker-lite: use ./plume.sh services status laravel-horizon --mode=docker-lite and services up laravel-horizon when enabled"
    return 0
  fi

  if [[ "${mode}" == "laradock-bridge" ]]; then
    plume_info "laradock-bridge: use ./plume.sh services status laravel-horizon --mode=laradock-bridge"
  fi
}

cmd_schedule_status() {
  local mode explicit_raw project_path artisan cron_state cron_hint
  if ! mode="$(plume_services_parse_mode "$@")"; then
    return 2
  fi
  explicit_raw="$(plume_laravel_parse_path_from_args "$@")"
  if ! plume_laravel_resolve_project_context "${explicit_raw}"; then
    return 2
  fi
  project_path="${PLUME_LARAVEL_PROJECT_PATH}"
  artisan="$(plume_laravel_artisan_state "${project_path}")"
  cron_state="$(plume_laravel_schedule_cron_state "${project_path}")"
  cron_hint="$(plume_laravel_schedule_cron_hint "${project_path}")"

  if [[ "${PLUME_OUTPUT:-text}" == "json" ]]; then
    printf '{"ok":true,"command":"schedule status","data":{"mode":"%s","project_path":"%s","project_source":"%s","site_id":"%s","artisan":"%s","scheduler_cron":"%s","cron_hint":"%s","docs":"docs/commands/schedule.md"}}\n' \
      "${mode}" \
      "${project_path}" \
      "${PLUME_LARAVEL_PROJECT_SOURCE}" \
      "${PLUME_LARAVEL_SITE_ID:-}" \
      "${artisan}" \
      "${cron_state}" \
      "${cron_hint}"
    return 0
  fi

  printf '%-18s %s\n' "MODE" "${mode}"
  printf '%-18s %s\n' "PROJECT_PATH" "${project_path}"
  printf '%-18s %s\n' "PROJECT_SOURCE" "${PLUME_LARAVEL_PROJECT_SOURCE}"
  [[ -n "${PLUME_LARAVEL_SITE_ID:-}" ]] && printf '%-18s %s\n' "SITE_ID" "${PLUME_LARAVEL_SITE_ID}"
  printf '%-18s %s\n' "ARTISAN" "${artisan}"
  printf '%-18s %s\n' "SCHEDULER_CRON" "${cron_state}"
  printf '%-18s %s\n' "CRON_HINT" "${cron_hint}"
  if [[ "${cron_state}" == "not-configured" ]]; then
    plume_info "install scheduler cron: ./plume.sh schedule cron-install --path=${project_path} (or copy CRON_HINT into crontab -e)"
  fi
  if [[ "${artisan}" == "missing" ]]; then
    plume_warn "no artisan file under PROJECT_PATH; schedule:run requires a Laravel app root"
  fi
}

cmd_queue_status() {
  local mode explicit_raw project_path queue_conn env_file
  local horizon_enabled supervisor_enabled php_worker_enabled
  local h_en h_run h_health s_en s_run s_health w_en w_run w_health
  if ! mode="$(plume_services_parse_mode "$@")"; then
    return 2
  fi
  explicit_raw="$(plume_laravel_parse_path_from_args "$@")"
  if ! plume_laravel_resolve_project_context "${explicit_raw}"; then
    return 2
  fi
  project_path="${PLUME_LARAVEL_PROJECT_PATH}"
  env_file="${project_path}/.env"
  queue_conn="$(plume_laravel_read_env_kv "${env_file}" "QUEUE_CONNECTION" 2>/dev/null || true)"
  [[ -n "${queue_conn}" ]] || queue_conn="$(plume_laravel_read_env_kv "${env_file}" "QUEUE_DRIVER" 2>/dev/null || true)"
  [[ -n "${queue_conn}" ]] || queue_conn="-"

  horizon_enabled="$(plume_service_enabled_for_mode horizon "${mode}")"
  supervisor_enabled="$(plume_service_enabled_for_mode supervisor "${mode}")"
  php_worker_enabled="$(plume_service_enabled_for_mode php_worker "${mode}")"

  IFS=$'\t' read -r _ h_en h_run h_health <<< "$(plume_laravel_queue_service_summary horizon "${mode}")"
  IFS=$'\t' read -r _ s_en s_run s_health <<< "$(plume_laravel_queue_service_summary supervisor "${mode}")"
  IFS=$'\t' read -r _ w_en w_run w_health <<< "$(plume_laravel_queue_service_summary php_worker "${mode}")"

  if [[ "${PLUME_OUTPUT:-text}" == "json" ]]; then
    printf '{"ok":true,"command":"queue status","data":{"mode":"%s","project_path":"%s","project_source":"%s","site_id":"%s","queue_connection":"%s","horizon":{"env_enabled":%s,"enabled":"%s","running":"%s","health":"%s"},"supervisor":{"env_enabled":%s,"enabled":"%s","running":"%s","health":"%s"},"php_worker":{"env_enabled":%s,"enabled":"%s","running":"%s","health":"%s"},"docs":"docs/commands/queue.md"}}\n' \
      "${mode}" \
      "${project_path}" \
      "${PLUME_LARAVEL_PROJECT_SOURCE}" \
      "${PLUME_LARAVEL_SITE_ID:-}" \
      "${queue_conn}" \
      "${horizon_enabled}" "${h_en}" "${h_run}" "${h_health}" \
      "${supervisor_enabled}" "${s_en}" "${s_run}" "${s_health}" \
      "${php_worker_enabled}" "${w_en}" "${w_run}" "${w_health}"
    return 0
  fi

  printf '%-18s %s\n' "MODE" "${mode}"
  printf '%-18s %s\n' "PROJECT_PATH" "${project_path}"
  printf '%-18s %s\n' "PROJECT_SOURCE" "${PLUME_LARAVEL_PROJECT_SOURCE}"
  [[ -n "${PLUME_LARAVEL_SITE_ID:-}" ]] && printf '%-18s %s\n' "SITE_ID" "${PLUME_LARAVEL_SITE_ID}"
  printf '%-18s %s\n' "QUEUE_CONNECTION" "${queue_conn}"
  printf '%-18s env=%s enabled=%s running=%s health=%s\n' "HORIZON" "${horizon_enabled}" "${h_en}" "${h_run}" "${h_health}"
  printf '%-18s env=%s enabled=%s running=%s health=%s\n' "SUPERVISOR" "${supervisor_enabled}" "${s_en}" "${s_run}" "${s_health}"
  printf '%-18s env=%s enabled=%s running=%s health=%s\n' "PHP_WORKER" "${php_worker_enabled}" "${w_en}" "${w_run}" "${w_health}"
  plume_laravel_queue_hints "${mode}" "${horizon_enabled}" "${supervisor_enabled}" "${h_run}" "${s_run}"
}

plume_laravel_prepare_artisan_run() {
  local explicit_raw="$1"
  local project_path php_bin

  if ! plume_laravel_resolve_project_context "${explicit_raw}"; then
    return 2
  fi
  project_path="${PLUME_LARAVEL_PROJECT_PATH}"
  if ! plume_laravel_require_artisan "${project_path}"; then
    return 2
  fi
  if ! php_bin="$(plume_laravel_resolve_php_bin)"; then
    plume_err "php CLI not found (set PLUME_PHP_BIN or install PHP for site version)"
    return 2
  fi
  PLUME_LARAVEL_ARTISAN_PHP_BIN="${php_bin}"
  return 0
}

cmd_schedule_list() {
  local explicit_raw project_path php_bin rc

  explicit_raw="$(plume_laravel_parse_path_from_args "$@")"
  if ! plume_laravel_prepare_artisan_run "${explicit_raw}"; then
    return 2
  fi
  project_path="${PLUME_LARAVEL_PROJECT_PATH}"
  php_bin="${PLUME_LARAVEL_ARTISAN_PHP_BIN}"

  set +e
  plume_laravel_run_artisan "${project_path}" "${php_bin}" schedule:list
  rc=$?
  set -e
  return "${rc}"
}

cmd_schedule_run_once() {
  local explicit_raw project_path php_bin cron_state cron_hint dry_run cmd_line rc

  explicit_raw="$(plume_laravel_parse_path_from_args "$@")"
  if plume_laravel_arg_has_dry_run "$@"; then
    dry_run="true"
  else
    dry_run="false"
  fi

  if ! plume_laravel_prepare_artisan_run "${explicit_raw}"; then
    return 2
  fi
  project_path="${PLUME_LARAVEL_PROJECT_PATH}"
  php_bin="${PLUME_LARAVEL_ARTISAN_PHP_BIN}"
  cmd_line="$(plume_laravel_artisan_command_line "${project_path}" "${php_bin}" schedule:run --no-interaction)"

  if [[ "${dry_run}" == "true" ]]; then
    plume_info "[DRY-RUN] ${cmd_line}"
    return 0
  fi

  set +e
  plume_laravel_run_artisan "${project_path}" "${php_bin}" schedule:run --no-interaction
  rc=$?
  set -e

  cron_state="$(plume_laravel_schedule_cron_state "${project_path}")"
  if [[ "${cron_state}" == "not-configured" ]]; then
    cron_hint="$(plume_laravel_schedule_cron_hint "${project_path}")"
    plume_info "scheduler crontab not detected; for every-minute runs install: ${cron_hint}"
  fi

  return "${rc}"
}

cmd_schedule_cron_install() {
  local explicit_raw project_path php_bin cron_line dry_run remove
  local marker existing new_content had_marker

  if [[ "$(id -u 2>/dev/null || printf '0')" -eq 0 ]]; then
    plume_err "refusing to modify crontab as root; run as your normal user"
    return 2
  fi

  explicit_raw="$(plume_laravel_parse_path_from_args "$@")"
  if plume_laravel_arg_has_dry_run "$@"; then
    dry_run="true"
  else
    dry_run="false"
  fi
  if plume_laravel_arg_has_remove "$@"; then
    remove="true"
  else
    remove="false"
  fi

  if ! plume_laravel_prepare_artisan_run "${explicit_raw}"; then
    return 2
  fi
  project_path="${PLUME_LARAVEL_PROJECT_PATH}"
  php_bin="${PLUME_LARAVEL_ARTISAN_PHP_BIN}"
  cron_line="$(plume_laravel_schedule_cron_line "${project_path}" "${php_bin}")"
  marker="$(plume_laravel_schedule_cron_marker)"

  if [[ -z "${PLUME_CRONTAB_FILE:-}" ]] && ! command -v crontab >/dev/null 2>&1; then
    plume_err "crontab command not found"
    return 2
  fi

  if ! existing="$(plume_laravel_crontab_read)"; then
    plume_err "could not read crontab"
    return 2
  fi
  had_marker="$(printf '%s\n' "${existing}" | grep -F "${marker}" || true)"

  if [[ "${remove}" == "true" ]]; then
    if [[ -z "${had_marker}" ]]; then
      plume_info "no plume scheduler cron line to remove"
      return 0
    fi
    new_content="$(printf '%s\n' "${existing}" | grep -Fv "${marker}" || true)"
    while [[ "${new_content}" == $'\n' ]]; do
      new_content="${new_content#$'\n'}"
    done
    if [[ "${dry_run}" == "true" ]]; then
      plume_info "[DRY-RUN] would remove plume scheduler cron line(s) marked ${marker}"
      return 0
    fi
    plume_laravel_crontab_write "${new_content}"
    plume_info "removed plume scheduler cron line(s)"
    return 0
  fi

  if [[ -n "${had_marker}" ]]; then
    plume_info "plume scheduler cron already installed (${marker})"
    return 0
  fi

  if [[ "${dry_run}" == "true" ]]; then
    plume_info "[DRY-RUN] ${cron_line}"
    return 0
  fi

  if [[ -n "${existing}" ]]; then
    new_content="${existing}"$'\n'"${cron_line}"
  else
    new_content="${cron_line}"
  fi
  plume_laravel_crontab_write "${new_content}"
  plume_info "installed plume scheduler cron line for ${project_path}"
  return 0
}

cmd_queue_list() {
  local mode explicit_raw project_path php_bin horizon_enabled rc

  if ! mode="$(plume_services_parse_mode "$@")"; then
    return 2
  fi
  explicit_raw="$(plume_laravel_parse_path_from_args "$@")"
  if ! plume_laravel_prepare_artisan_run "${explicit_raw}"; then
    return 2
  fi
  project_path="${PLUME_LARAVEL_PROJECT_PATH}"
  php_bin="${PLUME_LARAVEL_ARTISAN_PHP_BIN}"
  horizon_enabled="$(plume_service_enabled_for_mode horizon "${mode}")"

  if [[ "${horizon_enabled}" == "true" ]]; then
    plume_info "Horizon enabled: also try \`php artisan horizon:status\` in project (./plume.sh services status horizon --mode=${mode})"
  fi

  set +e
  plume_laravel_run_artisan "${project_path}" "${php_bin}" queue:failed
  rc=$?
  set -e
  return "${rc}"
}

cmd_schedule() {
  local sub="${1:-status}"
  shift || true
  case "${sub}" in
    status) cmd_schedule_status "$@" ;;
    list) cmd_schedule_list "$@" ;;
    run-once) cmd_schedule_run_once "$@" ;;
    cron-install) cmd_schedule_cron_install "$@" ;;
    *)
      plume_err "unknown schedule subcommand: ${sub} (use status|list|run-once|cron-install)"
      return 2
      ;;
  esac
}

cmd_queue() {
  local sub="${1:-status}"
  shift || true
  case "${sub}" in
    status) cmd_queue_status "$@" ;;
    list) cmd_queue_list "$@" ;;
    *)
      plume_err "unknown queue subcommand: ${sub} (use status|list)"
      return 2
      ;;
  esac
}
