#!/usr/bin/env bash
set -euo pipefail

# Homebrew nginx formula patches conf/nginx.conf at build time: listen 80 -> 8080
# so nginx can run without root (see homebrew-core Formula/n/nginx.rb, caveats).

plume_native_nginx_main_conf_path() {
  if [[ -n "${PLUME_NATIVE_NGINX_MAIN_CONF:-}" ]]; then
    printf '%s' "${PLUME_NATIVE_NGINX_MAIN_CONF}"
    return 0
  fi
  if [[ -f "/opt/homebrew/etc/nginx/nginx.conf" ]]; then
    printf '%s' "/opt/homebrew/etc/nginx/nginx.conf"
    return 0
  fi
  if [[ -f "/usr/local/etc/nginx/nginx.conf" ]]; then
    printf '%s' "/usr/local/etc/nginx/nginx.conf"
    return 0
  fi
  if command -v brew >/dev/null 2>&1; then
    local prefix=""
    prefix="$(HOMEBREW_NO_AUTO_UPDATE=1 brew --prefix nginx 2>/dev/null || true)"
    if [[ -n "${prefix}" && -f "${prefix}/etc/nginx/nginx.conf" ]]; then
      printf '%s' "${prefix}/etc/nginx/nginx.conf"
      return 0
    fi
  fi
  printf '%s' ""
}

plume_native_nginx_main_listen_port() {
  local conf=""
  conf="$(plume_native_nginx_main_conf_path)"
  if [[ -z "${conf}" || ! -f "${conf}" ]]; then
    printf '%s' ""
    return 0
  fi
  local detected=""
  detected="$(grep -E '^[[:space:]]*listen[[:space:]]+' "${conf}" 2>/dev/null | head -n 1 | awk '{print $2}' | tr -d ';' || true)"
  if [[ "${detected}" =~ ^\[::\]:([0-9]+)$ ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return 0
  fi
  if [[ "${detected}" =~ ^[0-9]+$ ]]; then
    printf '%s' "${detected}"
    return 0
  fi
  printf '%s' ""
}

plume_native_nginx_manage_main_config_enabled() {
  [[ "$(plume_bool "${PLUME_NATIVE_NGINX_MANAGE_MAIN_CONFIG:-false}")" == "true" ]]
}

plume_native_nginx_sync_main_config() {
  local target_port="${1:-}"
  local dry_run="${2:-false}"
  local do_reload="${3:-false}"

  if [[ -z "${target_port}" ]]; then
    target_port="${PLUME_NATIVE_NGINX_HTTP_PORT:-80}"
  fi
  if ! [[ "${target_port}" =~ ^[0-9]+$ ]]; then
    plume_err "invalid HTTP port: ${target_port}"
    return 2
  fi

  if ! plume_native_nginx_manage_main_config_enabled; then
    plume_err "Set PLUME_NATIVE_NGINX_MANAGE_MAIN_CONFIG=true to patch the Homebrew nginx main config (see docs/commands/services-web.md)"
    return 2
  fi

  case "${PLUME_WEB_SERVER_DRIVER:-nginx}" in
    nginx) ;;
    *)
      plume_err "sync-config applies only when PLUME_WEB_SERVER_DRIVER=nginx (current: ${PLUME_WEB_SERVER_DRIVER:-nginx})"
      return 2
      ;;
  esac

  local conf=""
  conf="$(plume_native_nginx_main_conf_path)"
  if [[ -z "${conf}" || ! -f "${conf}" ]]; then
    plume_err "nginx main config not found (install nginx, e.g. brew install nginx)"
    return 2
  fi

  local current=""
  current="$(plume_native_nginx_main_listen_port)"
  if [[ -z "${current}" ]]; then
    plume_err "could not detect listen port in ${conf}"
    return 2
  fi

  if [[ "${current}" == "${target_port}" ]]; then
    plume_info "nginx main config already listens on ${target_port} (${conf})"
    if [[ "${do_reload}" == "true" ]]; then
      plume_native_nginx_reload_for_http_port "${target_port}" || return 2
    fi
    return 0
  fi

  if [[ "${dry_run}" == "true" ]]; then
    printf 'action: sync-config\n'
    printf 'config: %s\n' "${conf}"
    printf 'current_listen: %s\n' "${current}"
    printf 'target_listen: %s\n' "${target_port}"
    printf 'reload: %s\n' "${do_reload}"
    return 0
  fi

  local backup=""
  backup="${conf}.plume-backup-$(date +%Y%m%d%H%M%S)"
  cp "${conf}" "${backup}"
  plume_info "backup: ${backup}"

  local tmp=""
  tmp="$(mktemp)"
  sed -E \
    -e "s/listen[[:space:]]+${current};/listen ${target_port};/g" \
    -e "s/listen[[:space:]]+\\[::\\]:${current};/listen [::]:${target_port};/g" \
    "${conf}" > "${tmp}"
  mv "${tmp}" "${conf}"

  local nginx_bin=""
  nginx_bin="$(plume_sites_native_nginx_bin 2>/dev/null || true)"
  if [[ -n "${nginx_bin}" ]]; then
    if ! "${nginx_bin}" -t 2>&1; then
      plume_err "nginx -t failed; restoring ${backup}"
      cp "${backup}" "${conf}"
      return 2
    fi
  fi

  plume_info "updated main config listen ${current} -> ${target_port} (${conf})"

  if [[ "${do_reload}" == "true" ]]; then
    plume_native_nginx_reload_for_http_port "${target_port}" || return 2
  else
    plume_info "Restart nginx to apply (port ${target_port} on macOS often needs root): sudo brew services restart nginx"
  fi

  plume_info "Re-publish sites so vhosts match port ${target_port}: ./plume.sh site publish --reload <site-id>"
  return 0
}

plume_native_nginx_reload_for_http_port() {
  local http_port="${1:-80}"

  if [[ "${http_port}" == "80" && "$(plume_detect_os 2>/dev/null || echo unknown)" == "macos" ]]; then
    if command -v brew >/dev/null 2>&1; then
      if command -v sudo >/dev/null 2>&1; then
        if sudo -n true 2>/dev/null; then
          if sudo HOMEBREW_NO_AUTO_UPDATE=1 brew services restart nginx >/dev/null 2>&1; then
            plume_info "nginx restarted via sudo brew services (port 80)"
            return 0
          fi
        elif declare -F plume_macos_permissions_confirm_sudo >/dev/null 2>&1 \
          && plume_macos_permissions_confirm_sudo "sudo brew services restart nginx" \
            "Port 80 requires root on macOS so nginx can bind to privileged ports."; then
          if sudo HOMEBREW_NO_AUTO_UPDATE=1 brew services restart nginx >/dev/null 2>&1; then
            plume_info "nginx restarted via sudo brew services (port 80)"
            return 0
          fi
        fi
      fi
      plume_err "Binding port 80 on macOS requires root. Run: sudo brew services restart nginx"
      plume_err "Alternative: keep Homebrew default 8080 and use PLUME_NATIVE_HOMEBREW_HTTP_PORT=8080 (browser :8080)."
      return 2
    fi
  fi

  if declare -F plume_sites_reload_native >/dev/null 2>&1; then
    if plume_sites_reload_native nginx; then
      return 0
    fi
  fi

  if command -v brew >/dev/null 2>&1; then
    if HOMEBREW_NO_AUTO_UPDATE=1 brew services list 2>/dev/null | awk '{print $1" "$2}' | grep -q '^nginx started'; then
      if HOMEBREW_NO_AUTO_UPDATE=1 brew services restart nginx >/dev/null 2>&1; then
        plume_info "nginx restarted via brew services"
        return 0
      fi
    fi
    if HOMEBREW_NO_AUTO_UPDATE=1 brew services restart nginx >/dev/null 2>&1; then
      plume_info "nginx restarted via brew services"
      return 0
    fi
  fi

  plume_err "nginx reload failed; run: brew services restart nginx"
  return 2
}
