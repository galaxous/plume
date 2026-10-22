#!/usr/bin/env bash
set -euo pipefail

# Native nginx HTTP listen: Plume guarantees PLUME_NATIVE_NGINX_HTTP_PORT (default 80)
# on macOS (Homebrew) and Linux (apt/dnf). Privileged ports use elevated restart (D-151).

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
  if [[ -f "/etc/nginx/nginx.conf" ]]; then
    printf '%s' "/etc/nginx/nginx.conf"
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
  [[ "$(plume_bool "${PLUME_NATIVE_NGINX_MANAGE_MAIN_CONFIG:-true}")" == "true" ]]
}

plume_native_nginx_desired_http_port() {
  printf '%s' "${PLUME_NATIVE_NGINX_HTTP_PORT:-80}"
}

plume_native_nginx_port_needs_elevation() {
  local port="${1:-}"
  [[ "${port}" =~ ^[0-9]+$ ]] || return 1
  (( port < 1024 ))
}

plume_native_nginx_config_test() {
  if declare -F plume_sites_nginx_config_test >/dev/null 2>&1; then
    plume_sites_nginx_config_test
    return $?
  fi
  local nginx_bin=""
  nginx_bin="$(plume_sites_native_nginx_bin 2>/dev/null || true)"
  [[ -n "${nginx_bin}" ]] || return 0
  "${nginx_bin}" -t >/dev/null 2>&1
}

plume_native_nginx_sync_main_config() {
  local target_port="${1:-}"
  local dry_run="${2:-false}"
  local do_reload="${3:-false}"

  if [[ -z "${target_port}" ]]; then
    target_port="$(plume_native_nginx_desired_http_port)"
  fi
  if ! [[ "${target_port}" =~ ^[0-9]+$ ]]; then
    plume_err "invalid HTTP port: ${target_port}"
    return 2
  fi

  if ! plume_native_nginx_manage_main_config_enabled; then
    plume_err "nginx main-config management is off. Set PLUME_NATIVE_NGINX_MANAGE_MAIN_CONFIG=true (default) or run: plumectl services web ensure"
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
    plume_err "nginx main config not found (install nginx via Plume: plumectl services install web)"
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
    # Config already correct — do not fail ensure when privileged reload is unavailable (D-159).
    # Callers that need a live reload (site publish --reload) still reload after writing snippets.
    if [[ "${do_reload}" == "true" ]]; then
      if ! plume_native_nginx_reload_for_http_port "${target_port}"; then
        plume_warn "nginx reload soft-failed (listen already ${target_port}); snippets may need: plumectl site publish <id> --reload"
      fi
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

  # Linux /etc/nginx often root-owned — write via temp + elevated copy when needed.
  local backup=""
  backup="${conf}.plume-backup-$(date +%Y%m%d%H%M%S)"
  if ! cp "${conf}" "${backup}" 2>/dev/null; then
    if declare -F plume_sites_nginx_run_elevated >/dev/null 2>&1; then
      plume_sites_nginx_run_elevated \
        "Backing up nginx main config requires admin." \
        cp "${conf}" "${backup}" || {
        plume_err "cannot backup nginx main config: ${conf}"
        return 2
      }
    else
      plume_err "cannot backup nginx main config: ${conf}"
      return 2
    fi
  fi
  plume_info "backup: ${backup}"

  local tmp=""
  tmp="$(mktemp)"
  sed -E \
    -e "s/listen[[:space:]]+${current};/listen ${target_port};/g" \
    -e "s/listen[[:space:]]+\\[::\\]:${current};/listen [::]:${target_port};/g" \
    "${conf}" > "${tmp}"

  if ! cp "${tmp}" "${conf}" 2>/dev/null; then
    if declare -F plume_sites_nginx_run_elevated >/dev/null 2>&1 \
      && plume_sites_nginx_run_elevated \
        "Updating nginx main listen port requires admin." \
        cp "${tmp}" "${conf}"; then
      :
    else
      rm -f "${tmp}"
      plume_err "cannot write nginx main config: ${conf}"
      return 2
    fi
  fi
  rm -f "${tmp}"

  if ! plume_native_nginx_config_test; then
    plume_err "nginx -t failed; restoring ${backup}"
    cp "${backup}" "${conf}" 2>/dev/null \
      || plume_sites_nginx_run_elevated "Restore nginx backup" cp "${backup}" "${conf}" || true
    return 2
  fi

  plume_info "updated main config listen ${current} -> ${target_port} (${conf})"

  if [[ "${do_reload}" == "true" ]]; then
    plume_native_nginx_reload_for_http_port "${target_port}" || return 2
  else
    plume_info "Apply with: plumectl services web ensure"
  fi
  return 0
}

plume_native_nginx_reload_for_http_port() {
  local http_port="${1:-80}"
  local os=""
  os="$(plume_detect_os 2>/dev/null || echo unknown)"

  if declare -F plume_native_driver_is_mock >/dev/null 2>&1 && plume_native_driver_is_mock; then
    plume_info "native driver mock reload: nginx (port ${http_port})"
    return 0
  fi

  if plume_native_nginx_port_needs_elevation "${http_port}"; then
    if declare -F plume_sites_nginx_reload_or_restart >/dev/null 2>&1; then
      if plume_sites_nginx_reload_or_restart; then
        plume_info "nginx reloaded via Plume (privileged port ${http_port})"
        return 0
      fi
    fi

    if [[ "${os}" == "macos" ]] && command -v brew >/dev/null 2>&1 && command -v sudo >/dev/null 2>&1; then
      if declare -F plume_sites_nginx_run_elevated >/dev/null 2>&1; then
        if plume_sites_nginx_run_elevated \
          "Port ${http_port} requires administrator privileges so nginx can bind." \
          env HOMEBREW_NO_AUTO_UPDATE=1 brew services restart nginx; then
          plume_info "nginx restarted (elevated) for port ${http_port}"
          return 0
        fi
      fi
    fi

    if [[ "${os}" == "linux" ]] && command -v systemctl >/dev/null 2>&1; then
      if declare -F plume_sites_nginx_run_elevated >/dev/null 2>&1; then
        if plume_sites_nginx_run_elevated \
          "Port ${http_port} requires administrator privileges so nginx can bind." \
          systemctl restart nginx; then
          plume_info "nginx restarted via systemctl (elevated) for port ${http_port}"
          return 0
        fi
      elif command -v sudo >/dev/null 2>&1; then
        sudo systemctl restart nginx >/dev/null 2>&1 && return 0
      fi
    fi

    plume_err "Binding port ${http_port} needs administrator privileges (nginx is root-owned)."
    plume_err "Fix: run in a real terminal → plumectl services web ensure"
    plume_err "Or once: sudo brew services restart nginx"
    return 2
  fi

  if declare -F plume_sites_reload_native >/dev/null 2>&1; then
    if plume_sites_reload_native nginx; then
      return 0
    fi
  fi

  if declare -F plume_sites_nginx_reload_or_restart >/dev/null 2>&1; then
    if plume_sites_nginx_reload_or_restart; then
      return 0
    fi
  fi

  plume_err "nginx reload failed; run: plumectl services restart web"
  return 2
}

# Ensure main nginx listen + optional republish of all native nginx sites (D-151).
plume_native_nginx_ensure_http_port() {
  local target_port="${1:-}"
  local republish_sites="${2:-true}"
  local dry_run="${3:-false}"

  if [[ -z "${target_port}" ]]; then
    target_port="$(plume_native_nginx_desired_http_port)"
  fi

  if [[ "${PLUME_NATIVE_NGINX_ENSURE_IN_PROGRESS:-false}" == "true" ]]; then
    return 0
  fi
  export PLUME_NATIVE_NGINX_ENSURE_IN_PROGRESS=true

  if ! plume_native_nginx_manage_main_config_enabled; then
    plume_warn "PLUME_NATIVE_NGINX_MANAGE_MAIN_CONFIG=false — skipping port ensure (sites may stay on 8080)"
    unset PLUME_NATIVE_NGINX_ENSURE_IN_PROGRESS
    return 0
  fi

  if [[ "${dry_run}" == "true" ]]; then
    plume_native_nginx_sync_main_config "${target_port}" "true" "false"
    local rc=$?
    unset PLUME_NATIVE_NGINX_ENSURE_IN_PROGRESS
    return "${rc}"
  fi

  plume_info "ensuring nginx HTTP listen port=${target_port} (macOS/Linux)"
  # site publish passes republish_sites=false and reloads after writing the snippet (D-159).
  # Avoid a privileged reload here when the caller will reload anyway.
  local sync_reload="true"
  if [[ "${republish_sites}" == "false" ]]; then
    sync_reload="false"
  fi
  if ! plume_native_nginx_sync_main_config "${target_port}" "false" "${sync_reload}"; then
    unset PLUME_NATIVE_NGINX_ENSURE_IN_PROGRESS
    return 2
  fi

  if [[ "${republish_sites}" == "true" ]] && declare -F plume_sites_index_ids >/dev/null 2>&1; then
    local id file server mode
    while IFS= read -r id; do
      [[ -z "${id}" ]] && continue
      file="$(plume_sites_file "${id}" 2>/dev/null || true)"
      [[ -f "${file}" ]] || continue
      server="$(plume_sites_record_value "${file}" server 2>/dev/null || true)"
      [[ "${server}" == "nginx" ]] || continue
      mode="$(plume_sites_record_value "${file}" mode 2>/dev/null || true)"
      [[ -z "${mode}" || "${mode}" == "native" ]] || continue
      plume_info "re-publish site ${id} for listen ${target_port}"
      PLUME_SITE_RELOAD="false" plume_sites_publish_native "${id}" "native" "publish" || {
        plume_warn "re-publish failed for ${id}"
      }
    done < <(plume_sites_index_ids)
    # One reload after all snippets updated
    plume_native_nginx_reload_for_http_port "${target_port}" || true
  fi

  unset PLUME_NATIVE_NGINX_ENSURE_IN_PROGRESS
  plume_info "nginx HTTP port ensure complete (target=${target_port})"
  return 0
}
