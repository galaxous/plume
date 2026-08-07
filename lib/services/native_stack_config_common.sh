#!/usr/bin/env bash
set -euo pipefail

# Shared helpers for native stack config sync (include files + marked blocks).

plume_native_stack_config_marker_begin() {
  printf '%s' '# >>> plume-managed >>>'
}

plume_native_stack_config_marker_end() {
  printf '%s' '# <<< plume-managed <<<'
}

plume_native_stack_effective_password() {
  local raw="${1-__PLUME_UNSET__}"
  local fallback="${2:-}"
  local pass="${raw}"
  if [[ "${pass}" == "__PLUME_UNSET__" ]]; then
    pass="${fallback}"
  fi
  case "${pass}" in
    ""|null|NULL|none|NONE|false|FALSE)
      printf '%s' ""
      ;;
    *)
      printf '%s' "${pass}"
      ;;
  esac
}

plume_native_stack_config_ensure_include() {
  local main_conf="$1"
  local include_line="$2"
  local begin end tmp backup
  begin="$(plume_native_stack_config_marker_begin)"
  end="$(plume_native_stack_config_marker_end)"

  if [[ -z "${main_conf}" || ! -f "${main_conf}" ]]; then
    return 2
  fi

  if grep -Fq "${begin}" "${main_conf}" 2>/dev/null; then
    tmp="$(mktemp)"
    awk -v begin="${begin}" -v end="${end}" -v inc="${include_line}" '
      $0 ~ begin { skip=1; print begin; print inc; print end; next }
      skip && $0 ~ end { skip=0; next }
      !skip { print }
    ' "${main_conf}" > "${tmp}"
    if ! cmp -s "${main_conf}" "${tmp}"; then
      backup="${main_conf}.plume-backup-$(date +%Y%m%d%H%M%S)"
      cp "${main_conf}" "${backup}"
      mv "${tmp}" "${main_conf}"
      plume_info "native config: updated include in ${main_conf} (backup: ${backup})"
    else
      rm -f "${tmp}"
    fi
    return 0
  fi

  backup="${main_conf}.plume-backup-$(date +%Y%m%d%H%M%S)"
  cp "${main_conf}" "${backup}"
  {
    printf '\n%s\n' "${begin}"
    printf '%s\n' "${include_line}"
    printf '%s\n' "${end}"
  } >> "${main_conf}"
  plume_info "native config: appended include to ${main_conf} (backup: ${backup})"
}

plume_native_stack_config_replace_block() {
  local main_conf="$1"
  local block_content="$2"
  local begin end tmp backup
  begin="$(plume_native_stack_config_marker_begin)"
  end="$(plume_native_stack_config_marker_end)"

  if [[ -z "${main_conf}" || ! -f "${main_conf}" ]]; then
    return 2
  fi

  tmp="$(mktemp)"
  if grep -Fq "${begin}" "${main_conf}" 2>/dev/null; then
    awk -v begin="${begin}" -v end="${end}" '
      $0 ~ begin { inblock=1; print; next }
      inblock && $0 ~ end { inblock=0; print; next }
      inblock { next }
      { print }
    ' "${main_conf}" > "${tmp}"
  else
    cp "${main_conf}" "${tmp}"
  fi
  {
    printf '\n%s\n' "${begin}"
    printf '%s\n' "${block_content}"
    printf '%s\n' "${end}"
  } >> "${tmp}"

  if ! cmp -s "${main_conf}" "${tmp}"; then
    backup="${main_conf}.plume-backup-$(date +%Y%m%d%H%M%S)"
    cp "${main_conf}" "${backup}"
    mv "${tmp}" "${main_conf}"
    plume_info "native config: updated block in ${main_conf} (backup: ${backup})"
  else
    rm -f "${tmp}"
  fi
}

plume_native_stack_config_reload_service() {
  local service="$1"
  if plume_native_driver_is_mock; then
    plume_info "native ${service} mock reload"
    return 0
  fi
  local pm
  pm="$(plume_detect_package_manager)"
  case "${pm}" in
    brew)
      local svc
      svc="$(plume_native_driver_brew_service_name "${service}")" || return 2
      HOMEBREW_NO_AUTO_UPDATE=1 brew services restart "${svc}" >/dev/null 2>&1 \
        || HOMEBREW_NO_AUTO_UPDATE=1 brew services start "${svc}"
      ;;
    apt|dnf)
      local unit os
      unit="$(plume_native_driver_systemd_unit "${service}")" || return 2
      os="$(plume_detect_os)"
      if [[ "${os}" == "linux" ]] && command -v systemctl >/dev/null 2>&1; then
        systemctl restart "${unit}"
      else
        plume_err "systemd required for native ${service} reload"
        return 2
      fi
      ;;
    *)
      plume_err "unsupported package manager for ${service} reload: ${pm}"
      return 2
      ;;
  esac
  plume_info "native ${service}: service reloaded"
}

plume_native_stack_config_manage_enabled() {
  local service="$1"
  local key=""
  case "${service}" in
    mariadb) key="PLUME_NATIVE_MARIADB_MANAGE_CONFIG" ;;
    mysql) key="PLUME_NATIVE_MYSQL_MANAGE_CONFIG" ;;
    postgres) key="PLUME_NATIVE_POSTGRES_MANAGE_CONFIG" ;;
    mongodb) key="PLUME_NATIVE_MONGODB_MANAGE_CONFIG" ;;
    rabbitmq) key="PLUME_NATIVE_RABBITMQ_MANAGE_CONFIG" ;;
    redis) key="PLUME_NATIVE_REDIS_MANAGE_CONFIG" ;;
    *) return 1 ;;
  esac
  [[ "$(plume_bool "${!key:-true}")" == "true" ]]
}

plume_native_stack_sync_service_config() {
  local service="$1"
  local dry_run="${2:-false}"
  local do_reload="${3:-false}"
  case "${service}" in
    redis) plume_native_redis_sync_config "${dry_run}" "${do_reload}" ;;
    mariadb|mysql) plume_native_mariadb_sync_config "${service}" "${dry_run}" "${do_reload}" ;;
    postgres) plume_native_postgres_sync_config "${dry_run}" "${do_reload}" ;;
    mongodb) plume_native_mongodb_sync_config "${dry_run}" "${do_reload}" ;;
    rabbitmq) plume_native_rabbitmq_sync_config "${dry_run}" "${do_reload}" ;;
    *) return 0 ;;
  esac
}

plume_native_stack_apply_runtime_credentials() {
  local service="$1"
  if plume_native_driver_is_mock; then
    return 0
  fi
  case "${service}" in
    mariadb|mysql) plume_native_mariadb_apply_root_password "${service}" || true ;;
    postgres) plume_native_postgres_apply_password || true ;;
    mongodb) plume_native_mongodb_apply_auth || true ;;
    rabbitmq) plume_native_rabbitmq_apply_users || true ;;
    *) return 0 ;;
  esac
}

plume_native_stack_sync_on_lifecycle() {
  local service="$1"
  if ! plume_native_stack_config_manage_enabled "${service}" 2>/dev/null; then
    return 0
  fi
  plume_native_stack_sync_service_config "${service}" "false" "false" || {
    plume_warn "native ${service}: config sync failed (fix with: services restart ${service} --mode=native)"
  }
}

plume_native_stack_lifecycle_services() {
  printf '%s\n' mariadb mysql postgres mongodb rabbitmq redis
}
