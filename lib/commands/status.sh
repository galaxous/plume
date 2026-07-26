#!/usr/bin/env bash
set -euo pipefail

plume_ops_mode_from_args() {
  plume_services_parse_mode "$@"
}

plume_ops_has_flag() {
  local wanted="$1"
  shift
  local arg
  for arg in "$@"; do
    [[ "${arg}" == "${wanted}" ]] && return 0
  done
  return 1
}

plume_ops_audit() {
  local mode="$1"
  local event="$2"
  local details="${3:-}"
  plume_state_db_append_event "${mode}" "" "${event}" "${details}"
}

plume_ops_run_with_audit() {
  local event_prefix="$1"
  shift
  local mode
  if ! mode="$(plume_ops_mode_from_args "$@")"; then
    return 2
  fi
  local details
  details="$(printf 'args=%s' "$*")"
  plume_ops_audit "${mode}" "${event_prefix}.start" "${details}"
  if "$@"; then
    plume_ops_audit "${mode}" "${event_prefix}.ok" "${details}"
    return 0
  else
    local rc=$?
    plume_ops_audit "${mode}" "${event_prefix}.fail" "code=${rc} ${details}"
    return "${rc}"
  fi
}

cmd_status() {
  plume_ops_run_with_audit "ops.status" cmd_services_status "$@"
}

cmd_health() {
  plume_ops_run_with_audit "ops.health" cmd_services_health "$@"
}

cmd_logs() {
  plume_ops_run_with_audit "ops.logs" cmd_services_logs "$@"
}

cmd_monitor_events() {
  local mode limit arg
  if ! mode="$(plume_ops_mode_from_args "$@")"; then
    return 2
  fi
  limit="30"
  for arg in "$@"; do
    case "${arg}" in
      --limit=*) limit="${arg#*=}" ;;
    esac
  done
  if ! printf '%s' "${limit}" | grep -Eq '^[0-9]+$'; then
    plume_err "invalid --limit value: ${limit}"
    return 2
  fi
  if ! command -v sqlite3 >/dev/null 2>&1; then
    plume_err "sqlite3 is required for monitor events"
    return 2
  fi
  local db
  db="$(plume_state_db_file)"
  if [[ ! -f "${db}" ]]; then
    plume_err "state db not found: ${db}"
    return 2
  fi
  printf 'MODE              %s\n' "${mode}"
  printf 'SOURCE            %s\n' "${db}"
  printf 'LIMIT             %s\n' "${limit}"
  echo "TS                  EVENT                DETAILS"
  echo "------------------- -------------------- ----------------------------------------"
  sqlite3 -separator $'\t' "${db}" "
SELECT ts, event, COALESCE(details, '')
FROM runtime_events
WHERE mode='$(plume_state_db_escape "${mode}")'
ORDER BY id DESC
LIMIT ${limit};" 2>/dev/null | while IFS=$'\t' read -r ts event details; do
    printf '%-19s %-20s %s\n' "${ts:-}" "${event:-}" "${details:-}"
  done
}

cmd_monitor_summary() {
  local mode strict
  if ! mode="$(plume_ops_mode_from_args "$@")"; then
    return 2
  fi
  strict="false"
  if plume_ops_has_flag "--strict" "$@"; then
    strict="true"
  fi

  local total enabled_count running_count disabled_count healthy_count critical_count warn_count
  total=0
  enabled_count=0
  running_count=0
  disabled_count=0
  healthy_count=0
  critical_count=0
  warn_count=0
  local issue_lines=""

  local service status_line _svc _enabled _running _health _port _version running
  while IFS= read -r service; do
    [[ -z "${service}" ]] && continue
    total=$((total + 1))
    status_line="$(plume_services_display_status_line "${service}" "${mode}")"
    IFS=$'\t' read -r _svc _enabled _running _health _port _version <<< "${status_line}"
    running="${_running}"
    if [[ "${mode}" == "docker-lite" ]]; then
      case "${_health}" in
        healthy) running="true" ;;
        stopped|disabled) running="false" ;;
      esac
    fi
    if [[ "${_enabled}" == "true" ]]; then
      enabled_count=$((enabled_count + 1))
      [[ "${running}" == "true" ]] && running_count=$((running_count + 1))
      if [[ "${_health}" == "healthy" ]]; then
        healthy_count=$((healthy_count + 1))
      fi
      if [[ "${running}" != "true" || "${_health}" == "stopped" || "${_health}" == "unhealthy" || "${_health}" == "error" ]]; then
        critical_count=$((critical_count + 1))
        issue_lines="${issue_lines}${service}: running=${running}, health=${_health}\n"
      elif [[ "${_health}" != "healthy" ]]; then
        warn_count=$((warn_count + 1))
        issue_lines="${issue_lines}${service}: running=${running}, health=${_health}\n"
      fi
    else
      disabled_count=$((disabled_count + 1))
    fi
    if [[ "${mode}" == "laradock-bridge" ]] && plume_services_laradock_desired_has "${service}" && ! plume_services_laradock_resolved_has "${service}"; then
      critical_count=$((critical_count + 1))
      issue_lines="${issue_lines}${service}: desired=true,resolved=false\n"
    fi
  done < <(plume_services_display_names_for_mode "${mode}")

  local overall="OK"
  if [[ "${critical_count}" -gt 0 ]]; then
    overall="FAIL"
  elif [[ "${warn_count}" -gt 0 ]]; then
    overall="WARN"
  fi

  printf 'MODE              %s\n' "${mode}"
  printf 'OVERALL           %s\n' "${overall}"
  printf 'TOTAL_SERVICES    %s\n' "${total}"
  printf 'ENABLED           %s\n' "${enabled_count}"
  printf 'RUNNING           %s\n' "${running_count}"
  printf 'HEALTHY           %s\n' "${healthy_count}"
  printf 'CRITICAL          %s\n' "${critical_count}"
  printf 'WARN              %s\n' "${warn_count}"
  printf 'DISABLED          %s\n' "${disabled_count}"
  if [[ -n "${issue_lines}" ]]; then
    echo "ISSUES"
    echo "----------------- ----------------------------------------"
    printf '%b' "${issue_lines}" | awk 'NF{printf "%-17s %s\n","", $0}' | head -n 15
  fi
  echo
  echo "SECTION           COMMAND"
  echo "----------------- ----------------------------------------"
  printf '%-17s %s\n' "status" "services status --running"
  cmd_services_status --mode="${mode}" --running
  echo
  printf '%-17s %s\n' "health" "services health --running"
  cmd_services_health --mode="${mode}" --running
  if [[ "${strict}" == "true" && "${critical_count}" -gt 0 ]]; then
    return 2
  fi
}

cmd_monitor_watch() {
  local mode interval arg
  if ! mode="$(plume_ops_mode_from_args "$@")"; then
    return 2
  fi
  interval="2"
  for arg in "$@"; do
    case "${arg}" in
      --interval=*) interval="${arg#*=}" ;;
      --watch=*) interval="${arg#*=}" ;;
    esac
  done
  if ! printf '%s' "${interval}" | grep -Eq '^[0-9]+$'; then
    plume_err "invalid watch interval: ${interval}"
    return 2
  fi
  plume_ops_audit "${mode}" "ops.monitor.watch.start" "interval=${interval}"
  cmd_services_status --mode="${mode}" --running "--watch=${interval}"
}

cmd_monitor_runbook() {
  local mode scenario arg
  if ! mode="$(plume_ops_mode_from_args "$@")"; then
    return 2
  fi
  scenario="incident"
  for arg in "$@"; do
    case "${arg}" in
      --scenario=*) scenario="${arg#*=}" ;;
    esac
  done
  case "${scenario}" in
    incident|recovery|ports-conflict) ;;
    *)
      plume_err "invalid runbook scenario: ${scenario} (use incident|recovery|ports-conflict)"
      return 2
      ;;
  esac

  printf 'MODE              %s\n' "${mode}"
  printf 'RUNBOOK           %s\n' "${scenario}"
  echo "STEP              COMMAND"
  echo "----------------- ----------------------------------------"

  case "${scenario}" in
    incident)
      printf '%-17s %s\n' "1.capture" "./plume.sh monitor summary --mode=${mode}"
      printf '%-17s %s\n' "2.deep-check" "./plume.sh doctor check --mode=${mode} --deep"
      printf '%-17s %s\n' "3.health" "./plume.sh health --mode=${mode}"
      printf '%-17s %s\n' "4.events" "./plume.sh monitor events --mode=${mode} --limit=50"
      printf '%-17s %s\n' "5.sync-state" "./plume.sh sync state --mode=${mode}"
      printf '%-17s %s\n' "6.recover" "./plume.sh services up all --mode=${mode}"
      ;;
    recovery)
      printf '%-17s %s\n' "1.preflight" "./plume.sh doctor check --mode=${mode}"
      printf '%-17s %s\n' "2.stop" "./plume.sh services down all --mode=${mode}"
      printf '%-17s %s\n' "3.sync" "./plume.sh sync state --mode=${mode}"
      printf '%-17s %s\n' "4.start" "./plume.sh services up all --mode=${mode}"
      printf '%-17s %s\n' "5.verify" "./plume.sh monitor summary --mode=${mode} --strict"
      ;;
    ports-conflict)
      printf '%-17s %s\n' "1.status" "./plume.sh status --mode=${mode}"
      printf '%-17s %s\n' "2.sync" "./plume.sh sync state --mode=${mode}"
      printf '%-17s %s\n' "3.inspect" "./plume.sh doctor ports --mode=${mode}"
      printf '%-17s %s\n' "4.reconcile" "./plume.sh services workspace apply --mode=${mode}"
      printf '%-17s %s\n' "5.verify" "./plume.sh monitor summary --mode=${mode}"
      ;;
  esac
}

cmd_monitor() {
  local sub="${1:-summary}"
  shift || true
  case "${sub}" in
    summary) plume_ops_run_with_audit "ops.monitor.summary" cmd_monitor_summary "$@" ;;
    watch) cmd_monitor_watch "$@" ;;
    events) cmd_monitor_events "$@" ;;
    runbook) plume_ops_run_with_audit "ops.monitor.runbook" cmd_monitor_runbook "$@" ;;
    *)
      plume_err "unknown monitor subcommand: ${sub} (use summary|watch|events|runbook)"
      return 2
      ;;
  esac
}
