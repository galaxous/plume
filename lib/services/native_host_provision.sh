#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=native_host_service_drivers.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/native_host_service_drivers.sh"

plume_native_host_provision_enabled() {
  [[ "$(plume_bool "${PLUME_NATIVE_HOST_PROVISION:-false}")" == "true" ]]
}

plume_native_host_provision_supported() {
  local service="$1"
  local resolved
  resolved="$(plume_native_host_resolve_service "${service}" 2>/dev/null || printf '%s' "${service}")"
  plume_native_driver_service_supported "${resolved}"
}

# Mailpit + Phase 17 auto-provision when service enabled (D-119).
plume_native_host_provision_service_wants() {
  local service="$1"
  if plume_native_host_provision_enabled; then
    return 0
  fi
  if [[ "$(plume_bool "${PLUME_SERVICES_NO_PROVISION:-false}")" == "true" ]]; then
    return 1
  fi
  if [[ "${service}" == "mailpit" ]] && plume_native_host_provision_supported mailpit; then
    if [[ "$(plume_detect_package_manager)" == "brew" ]]; then
      return 0
    fi
    return 1
  fi
  if [[ "$(plume_mode_current)" == "native" ]] \
    && [[ "$(plume_bool "${PLUME_NATIVE_SERVICE_AUTO_PROVISION:-true}")" == "true" ]] \
    && [[ "$(plume_service_enabled "${service}")" == "true" ]] \
    && plume_native_host_provision_supported "${service}"; then
    return 0
  fi
  return 1
}

plume_native_host_resolve_service() {
  local service="$1"
  if [[ "${service}" == "web" ]]; then
    case "${PLUME_WEB_SERVER_DRIVER:-nginx}" in
      apache2) echo "apache2" ;;
      caddy)
        plume_warn "native host provision: caddy not automated; use nginx or apache2 driver"
        return 1
        ;;
      nginx|*) echo "nginx" ;;
    esac
    return 0
  fi
  echo "${service}"
}

plume_native_host_brew_formula() {
  plume_native_driver_brew_formula "$1"
}

plume_native_host_apt_packages() {
  plume_native_driver_apt_packages "$1"
}

plume_native_host_dnf_packages() {
  plume_native_driver_dnf_packages "$1"
}

plume_native_host_brew_service_name() {
  plume_native_driver_brew_service_name "$1"
}

plume_native_host_systemd_unit() {
  plume_native_driver_systemd_unit "$1"
}

plume_native_host_install_packages() {
  local service="$1"
  plume_native_driver_install_packages "${service}"
}

plume_native_host_start_service() {
  local service="$1"
  plume_native_driver_start_service "${service}"
}

plume_native_host_stop_service() {
  local service="$1"
  plume_native_driver_stop_service "${service}"
}

plume_native_host_provision_install() {
  local service="$1"
  if ! plume_native_host_provision_service_wants "${service}"; then
    return 0
  fi
  if ! plume_native_host_provision_supported "${service}"; then
    return 0
  fi
  local resolved
  if ! resolved="$(plume_native_host_resolve_service "${service}")"; then
    return 2
  fi
  plume_require_native_install_privileges || return 2
  plume_native_host_install_packages "${resolved}"
}

plume_native_host_provision_start() {
  local service="$1"
  if ! plume_native_host_provision_service_wants "${service}"; then
    return 0
  fi
  if ! plume_native_host_provision_supported "${service}"; then
    return 0
  fi
  local resolved
  if ! resolved="$(plume_native_host_resolve_service "${service}")"; then
    return 2
  fi
  plume_native_host_start_service "${resolved}"
}

plume_native_host_provision_stop() {
  local service="$1"
  if ! plume_native_host_provision_service_wants "${service}"; then
    return 0
  fi
  if ! plume_native_host_provision_supported "${service}"; then
    return 0
  fi
  local resolved
  if ! resolved="$(plume_native_host_resolve_service "${service}")"; then
    return 2
  fi
  plume_native_host_stop_service "${resolved}"
}

plume_native_host_health_probe() {
  local service="$1"
  local resolved
  resolved="$(plume_native_host_resolve_service "${service}" 2>/dev/null || printf '%s' "${service}")"
  plume_native_driver_health_probe "${resolved}"
}

# Phase 17 registry-only: horizon/supervisor/php_worker have no native brew/npm driver.
plume_native_host_registry_only_service() {
  local service="$1"
  case "${service}" in
    horizon|supervisor|php_worker) return 0 ;;
  esac
  return 1
}

plume_native_host_runtime_managed() {
  local service="$1"
  if plume_native_host_registry_only_service "${service}"; then
    return 1
  fi
  local resolved
  resolved="$(plume_native_host_resolve_service "${service}" 2>/dev/null || printf '%s' "${service}")"
  plume_native_driver_service_supported "${resolved}"
}

plume_native_host_service_url() {
  local service="$1"
  plume_native_driver_service_url "${service}"
}

plume_native_host_print_credentials() {
  local service="$1"
  plume_native_driver_print_credentials "${service}"
}
