#!/usr/bin/env bash
set -euo pipefail

plume_native_host_provision_enabled() {
  [[ "$(plume_bool "${PLUME_NATIVE_HOST_PROVISION:-false}")" == "true" ]]
}

# Mailpit host install/start also runs on `services up mailpit` without global provision flag (D-109).
plume_native_host_provision_service_wants() {
  local service="$1"
  if plume_native_host_provision_enabled; then
    return 0
  fi
  if [[ "${service}" == "mailpit" ]] && plume_native_host_provision_supported mailpit; then
    return 0
  fi
  return 1
}

plume_native_host_provision_supported() {
  local service="$1"
  case "${service}" in
    web|nginx|apache2|mariadb|mysql|redis) return 0 ;;
    mailpit)
      [[ "$(plume_detect_package_manager)" == "brew" ]]
      ;;
    *) return 1 ;;
  esac
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
  local service="$1"
  case "${service}" in
    nginx) echo "nginx" ;;
    apache2) echo "httpd" ;;
    mariadb) echo "mariadb" ;;
    mysql) echo "mysql" ;;
    redis) echo "redis" ;;
    mailpit) echo "mailpit" ;;
    *) return 1 ;;
  esac
}

plume_native_host_apt_packages() {
  local service="$1"
  case "${service}" in
    nginx) echo "nginx" ;;
    apache2) echo "apache2" ;;
    mariadb) echo "mariadb-server" ;;
    mysql) echo "mysql-server" ;;
    redis) echo "redis-server" ;;
    *) return 1 ;;
  esac
}

plume_native_host_dnf_packages() {
  local service="$1"
  case "${service}" in
    nginx) echo "nginx" ;;
    apache2) echo "httpd" ;;
    mariadb) echo "mariadb-server" ;;
    mysql) echo "mysql-server" ;;
    redis) echo "redis" ;;
    *) return 1 ;;
  esac
}

plume_native_host_brew_service_name() {
  local service="$1"
  case "${service}" in
    nginx) echo "nginx" ;;
    apache2) echo "httpd" ;;
    mariadb) echo "mariadb" ;;
    mysql) echo "mysql" ;;
    redis) echo "redis" ;;
    mailpit) echo "mailpit" ;;
    *) return 1 ;;
  esac
}

plume_native_host_systemd_unit() {
  local service="$1"
  case "${service}" in
    nginx) echo "nginx" ;;
    apache2) echo "apache2" ;;
    mariadb) echo "mariadb" ;;
    mysql) echo "mysql" ;;
    redis) echo "redis" ;;
    *) return 1 ;;
  esac
}

plume_native_host_install_packages() {
  local service="$1"
  local pm formula pkgs
  pm="$(plume_detect_package_manager)"
  case "${pm}" in
    brew)
      formula="$(plume_native_host_brew_formula "${service}")" || return 2
      if brew list "${formula}" >/dev/null 2>&1; then
        plume_info "native host: ${formula} already installed (brew)"
        return 0
      fi
      if declare -F plume_macos_permissions_confirm_host_install >/dev/null 2>&1; then
        plume_macos_permissions_confirm_host_install \
          "brew install ${formula}" \
          "Plume will install ${formula} via Homebrew for native mode (${service})." || return 2
      fi
      plume_info "native host: installing ${formula} (brew)"
      brew install "${formula}"
      ;;
    apt)
      pkgs="$(plume_native_host_apt_packages "${service}")" || return 2
      plume_info "native host: installing ${pkgs} (apt)"
      apt-get update -qq
      DEBIAN_FRONTEND=noninteractive apt-get install -y ${pkgs}
      ;;
    dnf)
      pkgs="$(plume_native_host_dnf_packages "${service}")" || return 2
      plume_info "native host: installing ${pkgs} (dnf)"
      dnf install -y ${pkgs}
      ;;
    *)
      plume_err "native host install unsupported package manager for ${service}: ${pm}"
      return 2
      ;;
  esac
}

plume_native_host_start_service() {
  local service="$1"
  local pm os
  pm="$(plume_detect_package_manager)"
  os="$(plume_detect_os)"
  case "${pm}" in
    brew)
      local svc
      svc="$(plume_native_host_brew_service_name "${service}")" || return 2
      plume_info "native host: starting ${svc} (brew services)"
      brew services start "${svc}" 2>/dev/null || brew services restart "${svc}"
      ;;
    apt|dnf)
      local unit
      unit="$(plume_native_host_systemd_unit "${service}")" || return 2
      if [[ "${os}" == "linux" ]] && command -v systemctl >/dev/null 2>&1; then
        plume_info "native host: starting ${unit} (systemd)"
        systemctl enable "${unit}" 2>/dev/null || true
        systemctl start "${unit}"
      else
        plume_err "native host start requires systemd on linux for ${service}"
        return 2
      fi
      ;;
    *)
      plume_err "native host start unsupported package manager: ${pm}"
      return 2
      ;;
  esac
}

plume_native_host_stop_service() {
  local service="$1"
  local pm os
  pm="$(plume_detect_package_manager)"
  os="$(plume_detect_os)"
  case "${pm}" in
    brew)
      local svc
      svc="$(plume_native_host_brew_service_name "${service}")" || return 2
      plume_info "native host: stopping ${svc} (brew services)"
      brew services stop "${svc}" 2>/dev/null || true
      ;;
    apt|dnf)
      local unit
      unit="$(plume_native_host_systemd_unit "${service}")" || return 2
      if [[ "${os}" == "linux" ]] && command -v systemctl >/dev/null 2>&1; then
        plume_info "native host: stopping ${unit} (systemd)"
        systemctl stop "${unit}" 2>/dev/null || true
      fi
      ;;
    *)
      return 0
      ;;
  esac
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
