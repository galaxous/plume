#!/usr/bin/env bash
set -euo pipefail

# Laradock parity: map mariadb|mysql hostnames → 127.0.0.1 for native phpMyAdmin / CLI.

plume_native_db_dual_engine_both_enabled() {
  [[ "$(plume_bool "${PLUME_MARIADB_ENABLED:-false}")" == "true" ]] \
    && [[ "$(plume_bool "${PLUME_MYSQL_ENABLED:-false}")" == "true" ]]
}

plume_native_db_brew_dual_engine_warn() {
  plume_native_db_dual_engine_both_enabled || return 0
  if declare -F plume_native_driver_is_mock >/dev/null 2>&1 \
    && plume_native_driver_is_mock 2>/dev/null; then
    return 0
  fi
  if [[ "$(plume_detect_package_manager 2>/dev/null || true)" != "brew" ]]; then
    return 0
  fi
  plume_warn "native brew: mariadb and mysql conflict (same binaries); use database.engine for one native engine + other via docker-lite, or disable PLUME_MYSQL_ENABLED"
}

plume_native_db_brew_dual_engine_assert() {
  plume_native_db_dual_engine_both_enabled || return 0
  if declare -F plume_native_driver_is_mock >/dev/null 2>&1 \
    && plume_native_driver_is_mock 2>/dev/null; then
    return 0
  fi
  if [[ "$(plume_detect_package_manager 2>/dev/null || true)" != "brew" ]]; then
    return 0
  fi
  plume_err "native brew: cannot start mariadb and mysql together; set database.engine to mariadb or mysql, or disable PLUME_MYSQL_ENABLED / PLUME_MARIADB_ENABLED"
  return 2
}

plume_native_db_hosts_marker_prefix() {
  printf '%s' 'plume-native-db'
}

plume_native_db_hosts_sync() {
  local host_file ip marker_prefix tmp_file engine

  if [[ "$(plume_bool "${PLUME_NATIVE_DB_HOSTS_SYNC:-true}")" != "true" ]]; then
    return 0
  fi

  host_file="$(plume_sites_host_file)"
  if [[ ! -f "${host_file}" ]]; then
    return 0
  fi

  marker_prefix="$(plume_native_db_hosts_marker_prefix)"
  ip="${PLUME_SITE_HOSTS_IP:-127.0.0.1}"
  tmp_file="$(mktemp)"
  awk -v prefix="${marker_prefix}" '
    index($0, prefix) == 0
  ' "${host_file}" > "${tmp_file}" 2>/dev/null || cp "${host_file}" "${tmp_file}"

  while IFS= read -r engine; do
    [[ -n "${engine}" ]] || continue
    printf '%s\t%s\t# %s:%s\n' "${ip}" "${engine}" "${marker_prefix}" "${engine}" >> "${tmp_file}"
  done < <(plume_native_phpmyadmin_list_operational_db_engines)

  if ! plume_fs_copy_no_tty "${tmp_file}" "${host_file}"; then
    rm -f "${tmp_file}"
    if [[ "$(plume_bool "${PLUME_NATIVE_DB_HOSTS_REQUIRED:-false}")" == "true" ]]; then
      plume_warn "native db hosts sync failed (see docs/operations/macos-permissions.md)"
      return 2
    fi
    plume_warn "native db hosts sync skipped (not writable: ${host_file})"
    return 0
  fi
  rm -f "${tmp_file}"
  return 0
}
