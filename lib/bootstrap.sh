#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=common/log.sh
source "${ROOT_DIR}/lib/common/log.sh"
# shellcheck source=common/cli.sh
source "${ROOT_DIR}/lib/common/cli.sh"
# shellcheck source=common/os.sh
source "${ROOT_DIR}/lib/common/os.sh"
# shellcheck source=common/host_profile.sh
source "${ROOT_DIR}/lib/common/host_profile.sh"
# shellcheck source=common/fs.sh
source "${ROOT_DIR}/lib/common/fs.sh"
# shellcheck source=common/state_db.sh
source "${ROOT_DIR}/lib/common/state_db.sh"
# shellcheck source=common/sites.sh
source "${ROOT_DIR}/lib/common/sites.sh"
# shellcheck source=common/env.sh
source "${ROOT_DIR}/lib/common/env.sh"
# shellcheck source=common/stack_service_env.sh
source "${ROOT_DIR}/lib/common/stack_service_env.sh"
# shellcheck source=common/macos_permissions.sh
source "${ROOT_DIR}/lib/common/macos_permissions.sh"
# shellcheck source=config/defaults.sh
source "${ROOT_DIR}/lib/config/defaults.sh"
# shellcheck source=common/services_manifest.sh
source "${ROOT_DIR}/lib/common/services_manifest.sh"
# shellcheck source=common/plume_yml.sh
source "${ROOT_DIR}/lib/common/plume_yml.sh"
# shellcheck source=services/native_host_provision.sh
source "${ROOT_DIR}/lib/services/native_host_provision.sh"
# shellcheck source=services/native_web_nginx_config.sh
source "${ROOT_DIR}/lib/services/native_web_nginx_config.sh"
# shellcheck source=services/native_redis_config.sh
source "${ROOT_DIR}/lib/services/native_redis_config.sh"
# shellcheck source=services/registry.sh
source "${ROOT_DIR}/lib/services/registry.sh"
# shellcheck source=commands/help.sh
source "${ROOT_DIR}/lib/commands/help.sh"
# shellcheck source=commands/mode.sh
source "${ROOT_DIR}/lib/commands/mode.sh"
# shellcheck source=commands/php.sh
source "${ROOT_DIR}/lib/commands/php.sh"
# shellcheck source=commands/init_host_onboarding.sh
source "${ROOT_DIR}/lib/commands/init_host_onboarding.sh"
# shellcheck source=commands/init.sh
source "${ROOT_DIR}/lib/commands/init.sh"
# shellcheck source=commands/context.sh
source "${ROOT_DIR}/lib/commands/context.sh"
# shellcheck source=commands/envcmd.sh
source "${ROOT_DIR}/lib/commands/envcmd.sh"
# shellcheck source=commands/services.sh
source "${ROOT_DIR}/lib/commands/services.sh"
# shellcheck source=commands/sync.sh
source "${ROOT_DIR}/lib/commands/sync.sh"
# shellcheck source=commands/prereq.sh
source "${ROOT_DIR}/lib/commands/prereq.sh"
# shellcheck source=commands/site.sh
source "${ROOT_DIR}/lib/commands/site.sh"
# shellcheck source=commands/status.sh
source "${ROOT_DIR}/lib/commands/status.sh"
# shellcheck source=commands/project.sh
source "${ROOT_DIR}/lib/commands/project.sh"
# shellcheck source=commands/deploy.sh
source "${ROOT_DIR}/lib/commands/deploy.sh"
# shellcheck source=commands/backup.sh
source "${ROOT_DIR}/lib/commands/backup.sh"
# shellcheck source=commands/doctor.sh
source "${ROOT_DIR}/lib/commands/doctor.sh"
# shellcheck source=commands/security.sh
source "${ROOT_DIR}/lib/commands/security.sh"
# shellcheck source=commands/schedule_queue.sh
source "${ROOT_DIR}/lib/commands/schedule_queue.sh"

main() {
  plume_parse_global_flags "$@"
  plume_load_defaults
  plume_services_manifest_apply
  plume_load_env "${PLUME_ENV_FILE}"
  plume_load_mode_context_env
  plume_load_defaults
  plume_host_profile_maybe_autobootstrap
  plume_ensure_state_dirs
  plume_state_db_init
  plume_ensure_sites_dirs

  local bootstrap_cmd="${PLUME_PARSED_ARGS[0]:-help}"
  case "${bootstrap_cmd}" in
    help|-h|--help|version|--version|-v|init) ;;
    *)
      plume_services_manifest_maybe_on_first_run_provision || return $?
      ;;
  esac

  if [[ "${PLUME_GLOBAL_VERSION}" == "true" ]]; then
    cmd_version
    return 0
  fi

  local cmd="${PLUME_PARSED_ARGS[0]:-help}"

  if [[ "${PLUME_GLOBAL_HELP}" == "true" && "${cmd}" == "help" ]]; then
    cmd_help
    return 0
  fi

  if [[ ${#PLUME_PARSED_ARGS[@]} -gt 0 ]]; then
    set -- "${PLUME_PARSED_ARGS[@]}"
  else
    set --
  fi

  cmd="${1:-help}"
  shift || true

  case "${cmd}" in
    help|-h|--help) cmd_help "$@" ;;
    version|--version|-v) cmd_version ;;
    context) cmd_context "$@" ;;
    env) cmd_env "$@" ;;
    mode) cmd_mode "$@" ;;
    php) cmd_php "$@" ;;
    init) cmd_init "$@" ;;
    services) cmd_services "$@" ;;
    sync) cmd_sync "$@" ;;
    prereq) cmd_prereq "$@" ;;
    site) cmd_site "$@" ;;
    status) cmd_status "$@" ;;
    health) cmd_health "$@" ;;
    logs) cmd_logs "$@" ;;
    monitor) cmd_monitor "$@" ;;
    project) cmd_project "$@" ;;
    deploy) cmd_deploy "$@" ;;
    backup) cmd_backup "$@" ;;
    doctor) cmd_doctor "$@" ;;
    security) cmd_security "$@" ;;
    schedule) cmd_schedule "$@" ;;
    queue) cmd_queue "$@" ;;
    *)
      plume_err "Unknown command: ${cmd}"
      cmd_help
      return 2
      ;;
  esac
}
