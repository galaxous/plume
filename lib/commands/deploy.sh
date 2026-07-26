#!/usr/bin/env bash
set -euo pipefail

plume_deploy_parse_mode() {
  if declare -F plume_services_parse_mode >/dev/null 2>&1; then
    plume_services_parse_mode "$@"
    return $?
  fi
  if declare -F plume_mode_current >/dev/null 2>&1; then
    plume_mode_current
    return 0
  fi
  printf '%s' "native"
}

plume_deploy_failback_file() {
  local mode="$1"
  printf '%s' "$(plume_state_dir)/deploy-failback-${mode}"
}

plume_deploy_latest_backup_id() {
  local dir
  dir="$(plume_backup_dir)"
  [[ -d "${dir}" ]] || return 1
  local latest
  latest="$(ls -1t "${dir}"/*.tar.gz 2>/dev/null | head -n 1 || true)"
  [[ -n "${latest}" ]] || return 1
  basename "${latest}" .tar.gz
}

cmd_deploy_plan() {
  local mode
  if ! mode="$(plume_deploy_parse_mode "$@")"; then
    return 2
  fi
  printf 'MODE              %s\n' "${mode}"
  echo "DEPLOY PLAN        COMMAND"
  echo "-----------------  ----------------------------------------"
  printf '%-17s  %s\n' "1.snapshot" "./plume.sh backup create --mode=${mode} --scope=all --name=pre-deploy"
  printf '%-17s  %s\n' "2.health" "./plume.sh doctor check --mode=${mode} --deep"
  printf '%-17s  %s\n' "3.deploy" "./plume.sh deploy apply --mode=${mode}"
  printf '%-17s  %s\n' "4.verify" "./plume.sh monitor summary --mode=${mode} --strict"
  printf '%-17s  %s\n' "5.rollback" "./plume.sh --yes deploy rollback latest --mode=${mode}"
}

plume_deploy_apply_has_flag() {
  local flag="$1"
  shift
  local arg
  for arg in "$@"; do
    [[ "${arg}" == "${flag}" ]] && return 0
  done
  return 1
}

cmd_deploy_apply() {
  local mode dry_run skip_backup skip_health skip_reconcile
  if ! mode="$(plume_deploy_parse_mode "$@")"; then
    return 2
  fi
  dry_run="false"
  skip_backup="false"
  skip_health="false"
  skip_reconcile="false"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --dry-run) dry_run="true" ;;
      --skip-backup) skip_backup="true" ;;
      --skip-health) skip_health="true" ;;
      --skip-reconcile) skip_reconcile="true" ;;
    esac
  done

  if [[ "${dry_run}" != "true" ]]; then
    if ! plume_require_yes_for_critical "${mode}" "critical.deploy.apply" "mode=${mode}" "Use --yes deploy apply"; then
      return 2
    fi
  fi

  plume_audit_event "${mode}" "deploy.apply.start" "dry_run=${dry_run},skip_backup=${skip_backup},skip_health=${skip_health},skip_reconcile=${skip_reconcile}"

  printf 'MODE              %s\n' "${mode}"
  printf 'DRY_RUN           %s\n' "${dry_run}"
  echo "STEP               STATUS"
  echo "------------------ ------"

  if [[ "${skip_backup}" != "true" ]]; then
    if [[ "${dry_run}" == "true" ]]; then
      printf '%-18s %s\n' "1.pre-deploy-backup" "skipped (dry-run)"
    else
      if cmd_backup_create --mode="${mode}" --scope=config --name=pre-deploy >/dev/null; then
        printf '%-18s %s\n' "1.pre-deploy-backup" "ok"
      else
        plume_err "deploy apply failed at pre-deploy backup"
        plume_audit_event "${mode}" "deploy.apply.fail" "step=backup"
        return 2
      fi
    fi
  else
    printf '%-18s %s\n' "1.pre-deploy-backup" "skipped"
  fi

  if [[ "${skip_health}" != "true" ]]; then
    if [[ "${dry_run}" == "true" ]]; then
      printf '%-18s %s\n' "2.doctor-check" "skipped (dry-run)"
    else
      if cmd_doctor_check --mode="${mode}" --deep >/dev/null; then
        printf '%-18s %s\n' "2.doctor-check" "ok"
      else
        plume_err "deploy apply failed at doctor check --deep"
        plume_audit_event "${mode}" "deploy.apply.fail" "step=doctor"
        return 2
      fi
    fi
  else
    printf '%-18s %s\n' "2.doctor-check" "skipped"
  fi

  if [[ "${skip_reconcile}" != "true" ]]; then
    if [[ "${dry_run}" == "true" ]]; then
      printf '%-18s %s\n' "3.services-update" "skipped (dry-run)"
    else
      set +e
      PLUME_ASSUME_YES="true" cmd_services_update --mode="${mode}"
      local reconcile_rc=$?
      set -e
      if [[ "${reconcile_rc}" -eq 0 ]]; then
        printf '%-18s %s\n' "3.services-update" "ok"
      elif [[ "${reconcile_rc}" -eq 2 ]] && ! plume_is_root && [[ "$(plume_detect_os)" == "macos" ]]; then
        plume_warn "services update skipped: root not available on macOS (use --skip-reconcile or sudo)"
        printf '%-18s %s\n' "3.services-update" "skipped (no root)"
      else
        plume_err "deploy apply failed at services update"
        plume_audit_event "${mode}" "deploy.apply.fail" "step=services-update"
        return 2
      fi
    fi
  else
    printf '%-18s %s\n' "3.services-update" "skipped"
  fi

  if [[ "${dry_run}" == "true" ]]; then
    printf '%-18s %s\n' "4.monitor-summary" "skipped (dry-run)"
    echo "OVERALL            OK (dry-run)"
    plume_audit_event "${mode}" "deploy.apply.ok" "dry_run=true"
    return 0
  fi

  if cmd_monitor_summary --mode="${mode}" --strict >/dev/null; then
    printf '%-18s %s\n' "4.monitor-summary" "ok"
    echo "OVERALL            OK"
    plume_audit_event "${mode}" "deploy.apply.ok" "dry_run=false"
    return 0
  fi
  plume_err "deploy apply failed at monitor summary --strict"
  plume_audit_event "${mode}" "deploy.apply.fail" "step=monitor"
  return 2
}

cmd_deploy_rollback() {
  local mode ref dry_run skip_failback
  if ! mode="$(plume_deploy_parse_mode "$@")"; then
    return 2
  fi
  ref="${1:-latest}"
  dry_run="false"
  skip_failback="false"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --dry-run) dry_run="true" ;;
      --skip-failback-point) skip_failback="true" ;;
    esac
  done

  local backup_id
  backup_id="${ref}"
  if [[ "${ref}" == "latest" ]]; then
    if ! backup_id="$(plume_deploy_latest_backup_id)"; then
      plume_err "rollback latest failed: no backup found"
      return 2
    fi
  fi

  if [[ "${dry_run}" != "true" ]]; then
    if ! plume_require_yes_for_critical "${mode}" "critical.deploy.rollback" "mode=${mode},ref=${backup_id}" "Use --yes deploy rollback <id|latest>"; then
      return 2
    fi
  fi

  plume_audit_event "${mode}" "deploy.rollback.start" "ref=${backup_id},dry_run=${dry_run}"

  if [[ "${dry_run}" != "true" && "${skip_failback}" != "true" ]]; then
    local failback_id
    failback_id="$(cmd_backup_create --mode="${mode}" --scope=config --name=failback-pre-rollback | tail -n 1)"
    if [[ -n "${failback_id}" ]]; then
      printf '%s\n' "${failback_id}" > "$(plume_deploy_failback_file "${mode}")"
      plume_audit_event "${mode}" "deploy.failback.point.created" "id=${failback_id}"
    fi
  fi

  if [[ "${dry_run}" == "true" ]]; then
    cmd_backup_restore "${backup_id}" --mode="${mode}" --dry-run
  else
    PLUME_ASSUME_YES="true" cmd_backup_restore "${backup_id}" --mode="${mode}"
  fi

  plume_audit_event "${mode}" "deploy.rollback.ok" "ref=${backup_id},dry_run=${dry_run}"
}

cmd_deploy_failback() {
  local mode dry_run
  if ! mode="$(plume_deploy_parse_mode "$@")"; then
    return 2
  fi
  dry_run="false"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --dry-run) dry_run="true" ;;
    esac
  done

  local marker failback_id
  marker="$(plume_deploy_failback_file "${mode}")"
  if [[ ! -f "${marker}" ]]; then
    plume_err "failback point not found for mode=${mode}"
    return 2
  fi
  failback_id="$(cat "${marker}")"
  [[ -n "${failback_id}" ]] || {
    plume_err "failback marker is empty: ${marker}"
    return 2
  }

  plume_audit_event "${mode}" "deploy.failback.start" "ref=${failback_id},dry_run=${dry_run}"
  if [[ "${dry_run}" == "true" ]]; then
    cmd_deploy_rollback "${failback_id}" --mode="${mode}" --dry-run --skip-failback-point
  else
    if ! plume_require_yes_for_critical "${mode}" "critical.deploy.failback" "mode=${mode},ref=${failback_id}" "Use --yes deploy failback"; then
      return 2
    fi
    PLUME_ASSUME_YES="true" cmd_deploy_rollback "${failback_id}" --mode="${mode}" --skip-failback-point
  fi
  plume_audit_event "${mode}" "deploy.failback.ok" "ref=${failback_id},dry_run=${dry_run}"
}

cmd_deploy() {
  local sub="${1:-plan}"
  shift || true
  case "${sub}" in
    plan) cmd_deploy_plan "$@" ;;
    apply) cmd_deploy_apply "$@" ;;
    rollback) cmd_deploy_rollback "$@" ;;
    failback) cmd_deploy_failback "$@" ;;
    *)
      plume_err "unknown deploy subcommand: ${sub} (use plan|apply|rollback|failback)"
      return 2
      ;;
  esac
}
