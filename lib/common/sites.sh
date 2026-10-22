#!/usr/bin/env bash
set -euo pipefail

plume_sites_dir() {
  printf '%s' "${PLUME_SITE_REGISTRY_DIR:-$HOME/.config/plume/sites}"
}

plume_sites_mode_cache_root() {
  local mode="$1"
  case "${mode}" in
    docker-lite)
      printf '%s' "${HOME}/.config/plume/docker-lite/sites"
      ;;
    laradock-bridge)
      printf '%s' "${HOME}/.config/plume/laradock-bridge/sites"
      ;;
    native|*)
      printf '%s' "${PLUME_SITE_REGISTRY_DIR:-$HOME/.config/plume/sites}"
      ;;
  esac
}

plume_sites_index_file() {
  printf '%s/index.yml' "$(plume_sites_dir)"
}

plume_sites_cache_dir() {
  local server="${1:-nginx}"
  local mode="${2:-$(plume_mode_current)}"
  local root
  root="$(plume_sites_mode_cache_root "${mode}")"
  printf '%s/%s' "${root}" "${server}"
}

plume_ensure_sites_dirs() {
  mkdir -p "$(plume_sites_dir)"
  mkdir -p "$(plume_sites_cache_dir)"
}

plume_sites_id() {
  if [[ -n "${1:-}" ]]; then
    printf '%s' "$1"
    return 0
  fi
  printf 'site-%s-%s' "$(date +%s)" "${RANDOM}"
}

plume_sites_index_ids() {
  local index_file
  index_file="$(plume_sites_index_file)"

  if [[ ! -f "${index_file}" ]]; then
    return 0
  fi

  awk '/^  - / {print $2}' "${index_file}" 2>/dev/null || true
}

plume_sites_index_write() {
  local idx_file
  idx_file="$(plume_sites_index_file)"
  local ids=("$@")
  local ids_count=0
  local id

  ids_count=${#ids[@]}

  {
    printf 'sites:\n'
    if (( ids_count > 0 )); then
      for id in "${ids[@]}"; do
        [[ -z "${id}" ]] && continue
        printf '  - %s\n' "${id}"
      done
    fi
  } > "${idx_file}"
}

plume_sites_index_upsert() {
  local target="$1"
  local ids=()
  local ids_count=0
  local found=""
  local id

  while IFS= read -r id; do
    ids+=("${id}")
    ids_count=$((ids_count + 1))
  done < <(plume_sites_index_ids)

  if (( ids_count > 0 )); then
    for id in "${ids[@]}"; do
      if [[ "${id}" == "${target}" ]]; then
        found="1"
        break
      fi
    done
  fi

  if [[ -z "${found}" ]]; then
    ids+=("${target}")
  fi

  if (( ids_count > 0 || ${#ids[@]} > 0 )); then
    plume_sites_index_write "${ids[@]}"
  else
    plume_sites_index_write
  fi
}

plume_sites_index_remove() {
  local target="$1"
  local ids=()
  local ids_count=0
  local id

  while IFS= read -r id; do
    [[ "${id}" == "${target}" ]] && continue
    ids+=("${id}")
    ids_count=$((ids_count + 1))
  done < <(plume_sites_index_ids)

  if (( ids_count > 0 )); then
    plume_sites_index_write "${ids[@]}"
  else
    plume_sites_index_write
  fi
}

plume_sites_file() {
  local id="$1"
  printf '%s/%s.yml' "$(plume_sites_dir)" "${id}"
}

plume_sites_exists() {
  local id="$1"
  [[ -f "$(plume_sites_file "${id}")" ]]
}

plume_sites_record_value() {
  local file="$1"
  local key="$2"
  awk -F': ' -v k="${key}" '$1 == k {print $2; exit}' "${file}" 2>/dev/null || true
}

plume_sites_record_port() {
  local file="$1"
  local port
  port="$(plume_sites_record_value "${file}" port)"
  if [[ -z "${port}" ]]; then
    port="80"
  fi
  printf '%s' "${port}"
}

plume_sites_record_domains() {
  local file="$1"
  awk '
    /^domains:/ {inlist=1; next}
    inlist == 1 && /^  - / { sub(/^  - /, "", $0); print $0 }
    inlist == 1 && $1 !~ /^- / && $1 !~ /^  - / { exit }
  ' "${file}" 2>/dev/null || true
}

plume_sites_record_server_config() {
  local file="$1"
  local value
  value="$(plume_sites_record_value "${file}" server_config)"
  if [[ -z "${value}" ]]; then
    # Backward compatibility with old site records.
    value="$(plume_sites_record_value "${file}" nginx_config)"
  fi
  printf '%s' "${value}"
}

plume_sites_record_cert_id() {
  local file="$1"
  local value
  value="$(plume_sites_record_value "${file}" cert_id)"
  printf '%s' "${value}"
}

plume_sites_record_https_port() {
  local file="$1"
  local value
  value="$(plume_sites_record_value "${file}" https_port)"
  if [[ -z "${value}" ]]; then
    value="${PLUME_WEB_HTTPS_PORT:-443}"
  fi
  printf '%s' "${value}"
}

plume_sites_cert_dir() {
  local cert_id="$1"
  printf '%s' "$(plume_state_dir)/certs/${cert_id}"
}

plume_sites_cert_file() {
  local cert_id="$1"
  printf '%s' "$(plume_sites_cert_dir "${cert_id}")/cert.crt"
}

plume_sites_cert_key_file() {
  local cert_id="$1"
  printf '%s' "$(plume_sites_cert_dir "${cert_id}")/cert.key"
}

plume_sites_cert_exists() {
  local cert_id="$1"
  [[ -n "${cert_id}" ]] || return 1
  [[ -f "$(plume_sites_cert_file "${cert_id}")" && -f "$(plume_sites_cert_key_file "${cert_id}")" ]]
}

plume_sites_php_version_normalize() {
  local raw="${1:-}"
  local value
  value="$(printf '%s' "${raw}" | tr '[:upper:]' '[:lower:]' | tr -d ' ')"
  if [[ -z "${value}" || "${value}" == "default" ]]; then
    printf '%s' "${PLUME_PHP_DEFAULT_VERSION:-${PLUME_PHP_VERSION:-8.3}}"
    return 0
  fi
  value="${value#php}"
  if [[ "${value}" =~ ^[0-9]+\.[0-9]+$ ]]; then
    printf '%s' "${value}"
    return 0
  fi
  if [[ "${value}" =~ ^[0-9]{2}$ ]]; then
    printf '%s.%s' "${value:0:1}" "${value:1:1}"
    return 0
  fi
  if [[ "${value}" =~ ^[0-9]+$ ]]; then
    printf '%s' "${value}"
    return 0
  fi
  return 1
}

plume_sites_record_horizon_enabled() {
  local file="$1"
  local value
  value="$(plume_sites_record_value "${file}" horizon)"
  if [[ "$(plume_bool "${value:-false}")" == "true" ]]; then
    printf '%s' "true"
  else
    printf '%s' "false"
  fi
}

plume_sites_record_php_version() {
  local file="$1"
  local value
  value="$(plume_sites_record_value "${file}" php_version)"
  if [[ -z "${value}" ]]; then
    printf '%s' "${PLUME_PHP_DEFAULT_VERSION:-${PLUME_PHP_VERSION:-8.3}}"
    return 0
  fi
  if value="$(plume_sites_php_version_normalize "${value}")"; then
    printf '%s' "${value}"
    return 0
  fi
  printf '%s' "${PLUME_PHP_DEFAULT_VERSION:-${PLUME_PHP_VERSION:-8.3}}"
}

plume_sites_record_php_upstream() {
  local file="$1"
  local value
  value="$(plume_sites_record_value "${file}" php_upstream)"
  printf '%s' "${value}"
}

plume_sites_php_service_for_version() {
  local php_version="$1"
  local normalized default_norm
  normalized="$(plume_sites_php_version_normalize "${php_version}")" || return 1
  default_norm="$(plume_sites_php_version_normalize "${PLUME_PHP_DEFAULT_VERSION:-${PLUME_PHP_VERSION:-8.3}}")"

  if [[ "${normalized}" == "${default_norm}" ]]; then
    printf '%s' "php-fpm"
    return 0
  fi

  local compact
  compact="$(printf '%s' "${normalized}" | tr -d '.')"
  printf 'php%s-fpm' "${compact}"
}

plume_sites_php_fpm_pool_config_candidates() {
  local normalized="$1"
  printf '%s\n' \
    "/opt/homebrew/etc/php/${normalized}/php-fpm.d/www.conf" \
    "/usr/local/etc/php/${normalized}/php-fpm.d/www.conf" \
    "/etc/php/${normalized}/fpm/pool.d/www.conf"
}

plume_sites_php_fpm_listen_from_pool_config() {
  local normalized="$1"
  local conf listen
  if [[ -n "${PLUME_PHP_FPM_WWW_CONF:-}" && -f "${PLUME_PHP_FPM_WWW_CONF}" ]]; then
    listen="$(
      grep -E '^[[:space:]]*listen[[:space:]]*=' "${PLUME_PHP_FPM_WWW_CONF}" 2>/dev/null | head -n 1 \
        | sed -E 's/^[[:space:]]*listen[[:space:]]*=[[:space:]]*//; s/[[:space:]]*;[[:space:]]*$//; s/^["'\''"]//; s/["'\''"]$//' \
        || true
    )"
    [[ -n "${listen}" ]] && printf '%s' "${listen}" && return 0
  fi
  while IFS= read -r conf; do
    [[ -f "${conf}" ]] || continue
    listen="$(
      grep -E '^[[:space:]]*listen[[:space:]]*=' "${conf}" 2>/dev/null | head -n 1 \
        | sed -E 's/^[[:space:]]*listen[[:space:]]*=[[:space:]]*//; s/[[:space:]]*;[[:space:]]*$//; s/^["'\''"]//; s/["'\''"]$//' \
        || true
    )"
    [[ -n "${listen}" ]] || continue
    printf '%s' "${listen}"
    return 0
  done < <(plume_sites_php_fpm_pool_config_candidates "${normalized}")
  return 1
}

plume_sites_php_fpm_listen_to_upstream() {
  local listen="$1"
  if [[ "${listen}" == unix:* ]]; then
    printf '%s' "${listen}"
    return 0
  fi
  if [[ "${listen}" == /* ]]; then
    printf 'unix:%s' "${listen}"
    return 0
  fi
  printf '%s' "${listen}"
}

plume_sites_php_listen_is_shared_default_tcp() {
  local listen="$1"
  local port="${PLUME_SITE_PHP_FPM_PORT:-9000}"
  [[ "${listen}" == "127.0.0.1:${port}" || "${listen}" == "localhost:${port}" || "${listen}" == ":${port}" ]]
}

plume_sites_php_native_fpm_formula_installed() {
  local normalized="$1"
  [[ -x "/opt/homebrew/opt/php@${normalized}/sbin/php-fpm" || -x "/usr/local/opt/php@${normalized}/sbin/php-fpm" ]]
}

plume_sites_php_canonical_homebrew_socket() {
  local normalized="$1"
  local hb
  if ! plume_sites_php_native_fpm_formula_installed "${normalized}"; then
    return 1
  fi
  for hb in "/opt/homebrew/var/run/php@${normalized}-fpm.sock" "/usr/local/var/run/php@${normalized}-fpm.sock"; do
    printf '%s' "${hb}"
    return 0
  done
  return 1
}

plume_sites_php_upstream_for_version() {
  local mode="$1"
  local php_version="$2"
  local port service
  port="${PLUME_SITE_PHP_FPM_PORT:-9000}"
  service="$(plume_sites_php_service_for_version "${php_version}")" || return 1

  case "${mode}" in
    native)
      local normalized compact default_norm specific_key specific_upstream default_upstream
      normalized="$(plume_sites_php_version_normalize "${php_version}")" || return 1
      default_norm="$(plume_sites_php_version_normalize "${PLUME_PHP_DEFAULT_VERSION:-${PLUME_PHP_VERSION:-8.3}}")"
      compact="$(printf '%s' "${normalized}" | tr -d '.')"
      specific_key="PLUME_NATIVE_PHP_FPM_UPSTREAM_${compact}"
      specific_upstream="${!specific_key:-}"
      default_upstream="${PLUME_NATIVE_PHP_FPM_UPSTREAM:-}"
      if [[ -n "${specific_upstream}" ]]; then
        printf '%s' "${specific_upstream}"
        return 0
      fi
      if [[ "${service}" == "php-fpm" && -n "${default_upstream}" ]]; then
        printf '%s' "${default_upstream}"
        return 0
      fi
      # best-effort native socket discovery per php version
      local socket=""
      if [[ "$(uname -s 2>/dev/null || true)" == "Darwin" ]]; then
        local hb
        if [[ "${normalized}" == "${default_norm}" ]]; then
          for hb in "/opt/homebrew/var/run/php-fpm.sock" "/usr/local/var/run/php-fpm.sock"; do
            [[ -S "${hb}" ]] && socket="${hb}" && break
          done
        else
          for hb in "/opt/homebrew/var/run/php@${normalized}-fpm.sock" "/usr/local/var/run/php@${normalized}-fpm.sock"; do
            [[ -S "${hb}" ]] && socket="${hb}" && break
          done
        fi
      else
        local lx="/run/php/php${normalized}-fpm.sock"
        [[ -S "${lx}" ]] && socket="${lx}"
      fi
      if [[ -n "${socket}" ]]; then
        printf 'unix:%s' "${socket}"
        return 0
      fi
      local pool_listen upstream_from_listen canonical_socket
      pool_listen="$(plume_sites_php_fpm_listen_from_pool_config "${normalized}" 2>/dev/null || true)"
      if [[ -n "${pool_listen}" ]]; then
        if [[ "${normalized}" == "${default_norm}" ]] || ! plume_sites_php_listen_is_shared_default_tcp "${pool_listen}"; then
          upstream_from_listen="$(plume_sites_php_fpm_listen_to_upstream "${pool_listen}")"
          printf '%s' "${upstream_from_listen}"
          return 0
        fi
      fi
      if [[ "${normalized}" != "${default_norm}" ]]; then
        canonical_socket="$(plume_sites_php_canonical_homebrew_socket "${normalized}" 2>/dev/null || true)"
        if [[ -n "${canonical_socket}" ]]; then
          printf 'unix:%s' "${canonical_socket}"
          return 0
        fi
        local lx="/run/php/php${normalized}-fpm.sock"
        if [[ -f "/etc/php/${normalized}/fpm/pool.d/www.conf" ]]; then
          printf 'unix:%s' "${lx}"
          return 0
        fi
      fi
      printf '127.0.0.1:%s' "${port}"
      return 0
      ;;
  esac

  printf '%s:%s' "${service}" "${port}"
}

plume_sites_effective_http_port() {
  local port="$1"
  local mode="${2:-native}"
  if [[ "${mode}" != "native" || "${port}" != "80" ]]; then
    printf '%s' "${port}"
    return 0
  fi
  # Explicit override (legacy keep-8080)
  if [[ -n "${PLUME_NATIVE_HOMEBREW_HTTP_PORT:-}" ]]; then
    printf '%s' "${PLUME_NATIVE_HOMEBREW_HTTP_PORT}"
    return 0
  fi
  # When Plume manages main nginx config, site snippets use the *desired* port (D-151).
  if declare -F plume_native_nginx_manage_main_config_enabled >/dev/null 2>&1 \
    && plume_native_nginx_manage_main_config_enabled; then
    if declare -F plume_native_nginx_desired_http_port >/dev/null 2>&1; then
      printf '%s' "$(plume_native_nginx_desired_http_port)"
      return 0
    fi
    printf '%s' "${PLUME_NATIVE_NGINX_HTTP_PORT:-80}"
    return 0
  fi
  if declare -F plume_native_nginx_main_listen_port >/dev/null 2>&1; then
    local detected=""
    detected="$(plume_native_nginx_main_listen_port)"
    if [[ -n "${detected}" ]]; then
      printf '%s' "${detected}"
      return 0
    fi
  fi
  if [[ -n "${PLUME_NATIVE_NGINX_HTTP_PORT:-}" ]]; then
    printf '%s' "${PLUME_NATIVE_NGINX_HTTP_PORT}"
    return 0
  fi
  printf '%s' "${port}"
}

plume_sites_format_public_url() {
  local scheme="$1"
  local host="$2"
  local port="$3"
  if [[ "${scheme}" == "http" && "${port}" == "80" ]]; then
    printf 'http://%s' "${host}"
    return 0
  fi
  if [[ "${scheme}" == "https" && "${port}" == "443" ]]; then
    printf 'https://%s' "${host}"
    return 0
  fi
  printf '%s://%s:%s' "${scheme}" "${host}" "${port}"
}

plume_sites_access_hint_for_http() {
  local registry_port="$1"
  local effective_http="$2"
  local url_http="$3"
  if [[ "${registry_port}" == "80" && "${effective_http}" != "80" ]]; then
    printf '%s' "http:// without :${effective_http} will fail (nothing listens on port 80). Open ${url_http} or configure port 80 (root/pf proxy)."
    return 0
  fi
  printf '%s' ""
}

plume_sites_path_is_macos_tcc_sensitive() {
  local path="$1"
  [[ "$(uname -s 2>/dev/null)" == "Darwin" ]] || return 1
  case "${path}" in
    *"/Desktop/"*|*"/Desktop"|*"/Documents/"*|*"/Documents"|*"/Downloads/"*|*"/Downloads")
      return 0
      ;;
  esac
  return 1
}

plume_sites_macos_tcc_sensitive_site_summary() {
  local id file path doc_root front hits=""
  while IFS= read -r id; do
    [[ -z "${id}" ]] && continue
    file="$(plume_sites_file "${id}")"
    [[ -f "${file}" ]] || continue
    path="$(plume_sites_record_value "${file}" path)"
    [[ -n "${path}" ]] || continue
    doc_root="$(plume_sites_record_value "${file}" document_root)"
    [[ -n "${doc_root}" ]] || doc_root="public"
    front="${path}/${doc_root}/index.php"
    if plume_sites_path_is_macos_tcc_sensitive "${path}"; then
      hits="${hits}${id}:${front}; "
    fi
  done < <(plume_sites_index_ids)
  hits="${hits%; }"
  printf '%s' "${hits}"
}

plume_site_conflict_domain() {
  local domain="$1"
  local id_to_ignore="${2:-}"
  local id

  while IFS= read -r id; do
    [[ -z "${id}" ]] && continue
    [[ -n "${id_to_ignore}" && "${id}" == "${id_to_ignore}" ]] && continue

    local file
    file="$(plume_sites_file "${id}")"
    while IFS= read -r existing; do
      [[ "${existing}" == "${domain}" ]] && return 0
    done < <(plume_sites_record_domains "${file}")
  done < <(plume_sites_index_ids)

  return 1
}

plume_site_conflict_path() {
  local path="$1"
  local id_to_ignore="${2:-}"
  local id

  while IFS= read -r id; do
    [[ -z "${id}" ]] && continue
    [[ -n "${id_to_ignore}" && "${id}" == "${id_to_ignore}" ]] && continue

    local file existing_path
    file="$(plume_sites_file "${id}")"
    existing_path="$(plume_sites_record_value "${file}" path)"
    [[ "${existing_path}" == "${path}" ]] && return 0
  done < <(plume_sites_index_ids)

  return 1
}

plume_site_conflict_port() {
  local port="$1"
  local id_to_ignore="${2:-}"
  local strict
  strict="$(plume_bool "${PLUME_SITE_PORT_CONFLICT_CHECK:-false}")"
  if [[ "${strict}" != "true" ]]; then
    return 1
  fi
  local id
  local existing_port

  while IFS= read -r id; do
    [[ -z "${id}" ]] && continue
    [[ -n "${id_to_ignore}" && "${id}" == "${id_to_ignore}" ]] && continue

    local file
    file="$(plume_sites_file "${id}")"
    existing_port="$(plume_sites_record_port "${file}")"
    [[ "${existing_port}" == "${port}" ]] && return 0
  done < <(plume_sites_index_ids)

  return 1
}

plume_sites_host_file() {
  local host_file="${PLUME_HOSTS_FILE:-/etc/hosts}"
  if [[ "${host_file:0:1}" == "~" ]]; then
    printf '%s\n' "${HOME}${host_file#\~}"
  else
    printf '%s\n' "${host_file}"
  fi
}

plume_sites_host_marker() {
  local site_id="$1"
  printf 'plume-site:%s' "${site_id}"
}

plume_sites_upsert_host_entries() {
  local site_id="$1"
  local id_file marker host_file tmp_file
  local -a domains=()
  local domain ip

  id_file="$(plume_sites_file "${site_id}")"
  while IFS= read -r domain; do
    [[ -z "${domain}" ]] && continue
    domains+=("${domain}")
  done < <(plume_sites_record_domains "${id_file}")

  if [[ "$(plume_bool "${PLUME_SITE_HOSTS_SYNC:-true}")" != "true" ]]; then
    if [[ "${#domains[@]}" -gt 0 ]]; then
      plume_warn "PLUME_SITE_HOSTS_SYNC=false — /etc/hosts not updated (${domains[*]}); browser may show NXDOMAIN"
      plume_warn "Fix: set PLUME_SITE_HOSTS_SYNC=true in ~/.config/plume/.env, then: plumectl site publish ${site_id}"
    fi
    return 0
  fi

  host_file="$(plume_sites_host_file)"
  if [[ ! -f "${host_file}" ]]; then
    return 2
  fi

  marker="$(plume_sites_host_marker "${site_id}")"

  tmp_file="$(mktemp)"
  awk -v marker="${marker}" '
    index($0, marker) == 0
  ' "${host_file}" > "${tmp_file}"

  ip="${PLUME_SITE_HOSTS_IP:-127.0.0.1}"
  for domain in "${domains[@]}"; do
    printf '%s\t%s\t# %s\n' "${ip}" "${domain}" "${marker}" >> "${tmp_file}"
  done

  if ! plume_fs_copy_elevated "${tmp_file}" "${host_file}" \
    "Updating /etc/hosts for site domains (${domains[*]:-none}) needs admin."; then
    rm -f "${tmp_file}"
    plume_warn "could not write ${host_file} (need sudo). Domains: ${domains[*]:-none}"
    plume_warn "Add manually: ${ip:-127.0.0.1}  ${domains[*]:-}  # ${marker}"
    if [[ "$(plume_bool "${PLUME_SITE_HOSTS_REQUIRED:-false}")" == "true" ]]; then
      return 2
    fi
    return 0
  fi
  rm -f "${tmp_file}"
  if [[ "${#domains[@]}" -gt 0 ]]; then
    plume_info "hosts updated: ${domains[*]} -> ${ip} (${host_file})"
  fi
  return 0
}

plume_sites_remove_host_entries() {
  local site_id="$1"
  local host_file marker tmp_file

  if [[ "${PLUME_SITE_HOSTS_SYNC}" != "true" ]]; then
    return 0
  fi

  host_file="$(plume_sites_host_file)"
  if [[ ! -f "${host_file}" ]]; then
    return 0
  fi

  marker="$(plume_sites_host_marker "${site_id}")"
  tmp_file="$(mktemp)"
  awk -v marker="${marker}" '
    index($0, marker) == 0
  ' "${host_file}" > "${tmp_file}"

  if ! plume_fs_copy_elevated "${tmp_file}" "${host_file}" \
    "Removing /etc/hosts entries for ${site_id} needs admin."; then
    rm -f "${tmp_file}"
    if [[ "$(plume_bool "${PLUME_SITE_HOSTS_REQUIRED:-false}")" == "true" ]]; then
      return 2
    fi
    return 0
  fi
  rm -f "${tmp_file}"
}

plume_sites_write_record() {
  local id="$1"
  local mode="$2"
  local path="$3"
  local server="$4"
  local document_root="$5"
  local port="$6"
  local status="$7"
  local php_version="${8:-${PLUME_PHP_DEFAULT_VERSION:-${PLUME_PHP_VERSION:-8.3}}}"
  local server_config="${9:-}"
  local cert_id="${10:-}"
  local https_port="${11:-${PLUME_WEB_HTTPS_PORT:-443}}"
  local php_upstream="${12:-}"
  local horizon="${13:-}"
  shift 13
  local domains=("$@")

  local file
  file="$(plume_sites_file "${id}")"

  {
    printf 'id: %s\n' "${id}"
    printf 'mode: %s\n' "${mode}"
    printf 'path: %s\n' "${path}"
    printf 'server: %s\n' "${server}"
    printf 'port: %s\n' "${port}"
    if [[ -n "${document_root}" ]]; then
      printf 'document_root: %s\n' "${document_root}"
    else
      printf 'document_root: public\n'
    fi
    printf 'php_version: %s\n' "${php_version}"
    if [[ -n "${php_upstream}" ]]; then
      printf 'php_upstream: %s\n' "${php_upstream}"
    fi
    if [[ -n "${server_config}" ]]; then
      printf 'server_config: %s\n' "${server_config}"
    fi
    if [[ -n "${cert_id}" ]]; then
      printf 'cert_id: %s\n' "${cert_id}"
      printf 'https_port: %s\n' "${https_port}"
    fi
    if [[ -n "${horizon}" ]]; then
      if [[ "$(plume_bool "${horizon}")" == "true" ]]; then
        printf 'horizon: true\n'
      else
        printf 'horizon: false\n'
      fi
    fi
    printf 'status: %s\n' "${status}"
    printf 'created_at: %s\n' "$(date +%s)"
    printf 'domains:\n'
    for domain in "${domains[@]}"; do
      printf '  - %s\n' "${domain}"
    done
  } > "${file}"
}

plume_sites_list_text() {
  local id
  local -a rows=()
  local cell_id cell_server cell_php cell_port cell_https cell_cert cell_status cell_domains cell_path
  local header_id="ID"
  local header_server="SERVER"
  local header_php="PHP"
  local header_port="PORT"
  local header_https="HTTPS"
  local header_cert="CERT"
  local header_status="STATUS"
  local header_domains="DOMAINS"
  local header_path="PATH"
  local width_id="${#header_id}"
  local width_server="${#header_server}"
  local width_php="${#header_php}"
  local width_port="${#header_port}"
  local width_https="${#header_https}"
  local width_cert="${#header_cert}"
  local width_status="${#header_status}"
  local width_domains="${#header_domains}"
  local width_path="${#header_path}"

  while IFS= read -r id; do
    local file path server php_version status port https_port cert_id domains
    file="$(plume_sites_file "${id}")"
    path="$(plume_sites_record_value "${file}" path)"
    server="$(plume_sites_record_value "${file}" server)"
    php_version="$(plume_sites_record_php_version "${file}")"
    port="$(plume_sites_record_port "${file}")"
    https_port="$(plume_sites_record_https_port "${file}")"
    cert_id="$(plume_sites_record_cert_id "${file}")"
    status="$(plume_sites_record_value "${file}" status)"
    domains="$(plume_sites_record_domains "${file}" | tr '\n' ',')"
    domains="${domains%,}"
    [[ -n "${port}" ]] || port="-"
    [[ -n "${https_port}" ]] || https_port="-"
    [[ -n "${cert_id}" ]] || cert_id="-"
    [[ -n "${status}" ]] || status="-"
    [[ -n "${domains}" ]] || domains="-"

    rows+=("${id}"$'\t'"${server}"$'\t'"${php_version}"$'\t'"${port}"$'\t'"${https_port}"$'\t'"${cert_id}"$'\t'"${status}"$'\t'"${domains}"$'\t'"${path}")

    (( ${#id} > width_id )) && width_id="${#id}"
    (( ${#server} > width_server )) && width_server="${#server}"
    (( ${#php_version} > width_php )) && width_php="${#php_version}"
    (( ${#port} > width_port )) && width_port="${#port}"
    (( ${#https_port} > width_https )) && width_https="${#https_port}"
    (( ${#cert_id} > width_cert )) && width_cert="${#cert_id}"
    (( ${#status} > width_status )) && width_status="${#status}"
    (( ${#domains} > width_domains )) && width_domains="${#domains}"
    (( ${#path} > width_path )) && width_path="${#path}"
  done < <(plume_sites_index_ids)

  local total_width=$((width_id + width_server + width_php + width_port + width_https + width_cert + width_status + width_domains + width_path + 16))
  printf "%-${width_id}s  %-${width_server}s  %-${width_php}s  %-${width_port}s  %-${width_https}s  %-${width_cert}s  %-${width_status}s  %-${width_domains}s  %-${width_path}s\n" \
    "${header_id}" "${header_server}" "${header_php}" "${header_port}" "${header_https}" "${header_cert}" "${header_status}" "${header_domains}" "${header_path}"
  printf '%s\n' "$(printf '%*s' "${total_width}" '' | tr ' ' '-')"

  local row
  if (( ${#rows[@]} > 0 )); then
    for row in "${rows[@]}"; do
      IFS=$'\t' read -r id server php_version port https_port cert_id status domains path <<< "${row}"
      [[ -n "${port}" ]] || port="-"
      [[ -n "${https_port}" ]] || https_port="-"
      [[ -n "${cert_id}" ]] || cert_id="-"
      [[ -n "${status}" ]] || status="-"
      [[ -n "${domains}" ]] || domains="-"
      printf "%-${width_id}s  %-${width_server}s  %-${width_php}s  %-${width_port}s  %-${width_https}s  %-${width_cert}s  %-${width_status}s  %-${width_domains}s  %-${width_path}s\n" \
        "${id}" "${server}" "${php_version}" "${port}" "${https_port}" "${cert_id}" "${status}" "${domains}" "${path}"
    done
  fi
}

plume_sites_cache_dir_for_mode() {
  local id="$1"
  local server="$2"
  local mode="${3:-$(plume_mode_current)}"
  printf '%s/%s' "$(plume_sites_mode_cache_root "${mode}")" "${server}"
}

plume_sites_render_config_to_file() {
  local id="$1"
  local mode="$2"
  local file_path="$3"
  local record_file
  record_file="$(plume_sites_file "${id}")"

  local server path document_root first_domain server_config port php_version php_upstream cert_id https_port cert_file cert_key tls_enabled
  local php_upstream_override
  local -a domains=()
  server="$(plume_sites_record_value "${record_file}" server)"
  path="$(plume_sites_record_value "${record_file}" path)"
  document_root="$(plume_sites_record_value "${record_file}" document_root)"
  port="$(plume_sites_record_port "${record_file}")"
  port="$(plume_sites_effective_http_port "${port}" "${mode}")"
  php_version="$(plume_sites_record_php_version "${record_file}")"
  php_upstream_override="$(plume_sites_record_php_upstream "${record_file}")"
  if [[ -n "${php_upstream_override}" ]]; then
    php_upstream="${php_upstream_override}"
  else
    php_upstream="$(plume_sites_php_upstream_for_version "${mode}" "${php_version}")"
  fi
  server_config="$(plume_sites_record_server_config "${record_file}")"
  cert_id="$(plume_sites_record_cert_id "${record_file}")"
  https_port="$(plume_sites_record_https_port "${record_file}")"
  first_domain="$(plume_sites_record_domains "${record_file}" | head -n 1)"
  while IFS= read -r domain; do
    [[ -n "${domain}" ]] && domains+=("${domain}")
  done < <(plume_sites_record_domains "${record_file}")

  [[ -n "${first_domain}" ]] || first_domain="plume-default.test"
  [[ -n "${document_root}" ]] || document_root="public"
  tls_enabled="false"
  if [[ -n "${cert_id}" ]]; then
    cert_file="$(plume_sites_cert_file "${cert_id}")"
    cert_key="$(plume_sites_cert_key_file "${cert_id}")"
    if [[ -f "${cert_file}" && -f "${cert_key}" ]]; then
      tls_enabled="true"
    else
      printf '%s\n' "error: certificate files not found for cert_id=${cert_id}" >&2
      return 1
    fi
  fi

  local temp_file
  temp_file="$(mktemp)"

  if [[ -n "${server_config}" ]]; then
    if [[ -f "${server_config}" ]]; then
      if cp -f "${server_config}" "${temp_file}"; then
        mv -f "${temp_file}" "${file_path}"
        return 0
      fi
      rm -f "${temp_file}"
      return 1
    fi
    rm -f "${temp_file}"
    printf '%s\n' "error: custom server config not found: ${server_config}" >&2
    return 1
  fi

  if [[ "${server}" == "caddy" ]]; then
    local hostnames
    hostnames="$(printf '%s' "${domains[*]}" | tr ' ' ',')"
    [[ -n "${hostnames}" ]] || hostnames="${first_domain}"
    local caddy_upstream
    caddy_upstream="${php_upstream}"
    if [[ "${caddy_upstream}" == unix:* ]]; then
      caddy_upstream="unix//${caddy_upstream#unix:}"
    fi
    cat > "${temp_file}" <<EOF
# Plume-generated caddy site (${id}) [mode=${mode}, php=${php_version}]
${hostnames} {
  encode zstd gzip
  root * ${path}/${document_root}
  php_fastcgi ${caddy_upstream}
$(if [[ "${tls_enabled}" == "true" ]]; then printf '  tls %s %s\n' "${cert_file}" "${cert_key}"; fi)  file_server
}
EOF
    mv -f "${temp_file}" "${file_path}"
    return 0
  fi

  if [[ "${server}" == "apache2" ]]; then
    local aliases=""
    local d
    for d in "${domains[@]}"; do
      [[ "${d}" == "${first_domain}" ]] && continue
      aliases="${aliases} ${d}"
    done
    local apache_handler
    apache_handler="proxy:fcgi://${php_upstream}"
    if [[ "${php_upstream}" == unix:* ]]; then
      apache_handler="proxy:unix:${php_upstream#unix:}|fcgi://localhost/"
    fi
    cat > "${temp_file}" <<EOF
# Plume-generated apache2 site (${id}) [mode=${mode}, php=${php_version}]
$(if [[ "${tls_enabled}" == "true" ]]; then cat <<AP_HTTP
<VirtualHost *:${port}>
    ServerName ${first_domain}
$(if [[ -n "${aliases}" ]]; then printf '    ServerAlias%s\n' "${aliases}"; fi)    Redirect permanent / https://${first_domain}:${https_port}/
</VirtualHost>

AP_HTTP
fi)
<VirtualHost *:$(if [[ "${tls_enabled}" == "true" ]]; then printf '%s' "${https_port}"; else printf '%s' "${port}"; fi)>
    ServerName ${first_domain}
$(if [[ -n "${aliases}" ]]; then printf '    ServerAlias%s\n' "${aliases}"; fi)    DocumentRoot ${path}/${document_root}
$(if [[ "${tls_enabled}" == "true" ]]; then cat <<AP_TLS
    SSLEngine on
    SSLCertificateFile ${cert_file}
    SSLCertificateKeyFile ${cert_key}
AP_TLS
fi)

    <Directory ${path}/${document_root}>
        AllowOverride All
        Require all granted
    </Directory>

    <FilesMatch \.php$>
        SetHandler "${apache_handler}"
    </FilesMatch>
</VirtualHost>
EOF
    mv -f "${temp_file}" "${file_path}"
    return 0
  fi

  # nginx fallback
  cat > "${temp_file}" <<EOF
# Plume-generated nginx site (${id}) [mode=${mode}, php=${php_version}]
$(if [[ "${tls_enabled}" == "true" ]]; then cat <<NG_HTTP
server {
    listen ${port};
    server_name ${first_domain};
    return 301 https://\$host:${https_port}\$request_uri;
}

NG_HTTP
fi)
server {
    listen $(if [[ "${tls_enabled}" == "true" ]]; then printf '%s ssl' "${https_port}"; else printf '%s' "${port}"; fi);
    server_name ${first_domain};
    root ${path}/${document_root};
    index index.php index.html;
$(if [[ "${tls_enabled}" == "true" ]]; then cat <<NG_TLS
    ssl_certificate ${cert_file};
    ssl_certificate_key ${cert_key};
NG_TLS
fi)

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        try_files \$uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
        fastcgi_pass ${php_upstream};
    }
}
EOF
  mv -f "${temp_file}" "${file_path}"
}

plume_sites_publish_native() {
  local id="$1"
  local mode="${2:-native}"
  local record_file server conf_file
  local action_message="${3:-publish}"
  PLUME_SITE_LAST_PUBLISH_RELOADED="false"
  record_file="$(plume_sites_file "${id}")"
  server="$(plume_sites_record_value "${record_file}" server)"

  # Guarantee desired HTTP port (default 80) on main nginx before rendering site snippet (D-151).
  if [[ "${mode}" == "native" && "${server}" == "nginx" \
    && "${action_message}" != "remove" \
    && "$(plume_bool "${PLUME_NATIVE_NGINX_ENSURE_ON_PUBLISH:-true}")" == "true" \
    && "${PLUME_NATIVE_NGINX_ENSURE_IN_PROGRESS:-false}" != "true" ]] \
    && declare -F plume_native_nginx_ensure_http_port >/dev/null 2>&1; then
    plume_native_nginx_ensure_http_port "" "false" "false" || {
      plume_warn "nginx HTTP port ensure failed; site snippet may not match live listen — run: plumectl services web ensure"
    }
  fi

  conf_file="$(plume_sites_cache_dir_for_mode "${id}" "${server}" "${mode}")/${id}.conf"
  mkdir -p "$(dirname "${conf_file}")"

  plume_sites_render_config_to_file "${id}" "${mode}" "${conf_file}"
  local rc=$?
  if [[ ${rc} -ne 0 ]]; then
    return "${rc}"
  fi

  if [[ "${action_message}" == "remove" ]]; then
    return 0
  fi

  if [[ "${mode}" == "native" ]]; then
    case "${server}" in
      nginx)
        local nginx_strict="false"
        if [[ "$(plume_bool "${PLUME_SITE_NGINX_STRICT:-false}")" == "true" ]]; then
          nginx_strict="true"
        elif [[ "$(plume_bool "${PLUME_SITE_NGINX_STRICT_ON_RELOAD:-true}")" == "true" && "$(plume_bool "${PLUME_SITE_RELOAD:-false}")" == "true" ]]; then
          nginx_strict="true"
        fi
        if [[ "${nginx_strict}" == "true" ]]; then
          plume_sites_publish_native_server_strict "${id}" "${conf_file}" "nginx" || return 1
        fi
        ;;
      apache2)
        if [[ "$(plume_bool "${PLUME_SITE_APACHE2_STRICT:-false}")" == "true" ]]; then
          plume_sites_publish_native_server_strict "${id}" "${conf_file}" "apache2" || return 1
        fi
        ;;
      caddy)
        if [[ "$(plume_bool "${PLUME_SITE_CADDY_STRICT:-false}")" == "true" ]]; then
          plume_sites_publish_native_server_strict "${id}" "${conf_file}" "caddy" || return 1
        fi
        ;;
    esac
  fi

  if ! plume_sites_upsert_host_entries "${id}"; then
    return 1
  fi
}

plume_sites_nginx_native_include_dir() {
  if [[ -n "${PLUME_NGINX_INCLUDE_DIR:-}" ]]; then
    printf '%s' "${PLUME_NGINX_INCLUDE_DIR}"
    return 0
  fi
  if [[ -d "/opt/homebrew/etc/nginx" ]]; then
    mkdir -p "/opt/homebrew/etc/nginx/servers"
    printf '%s' "/opt/homebrew/etc/nginx/servers"
    return 0
  fi
  if [[ -d "/opt/homebrew/etc/nginx/servers" ]]; then
    printf '%s' "/opt/homebrew/etc/nginx/servers"
    return 0
  fi
  if [[ -d "/usr/local/etc/nginx/servers" ]]; then
    printf '%s' "/usr/local/etc/nginx/servers"
    return 0
  fi
  if [[ -d "/etc/nginx/sites-enabled" ]]; then
    printf '%s' "/etc/nginx/sites-enabled"
    return 0
  fi
  printf '%s' ""
}

plume_sites_apache2_native_include_dir() {
  if [[ -n "${PLUME_APACHE2_INCLUDE_DIR:-}" ]]; then
    printf '%s' "${PLUME_APACHE2_INCLUDE_DIR}"
    return 0
  fi
  if [[ -d "/opt/homebrew/etc/httpd/extra" ]]; then
    printf '%s' "/opt/homebrew/etc/httpd/extra"
    return 0
  fi
  if [[ -d "/usr/local/etc/httpd/extra" ]]; then
    printf '%s' "/usr/local/etc/httpd/extra"
    return 0
  fi
  if [[ -d "/etc/apache2/sites-enabled" ]]; then
    printf '%s' "/etc/apache2/sites-enabled"
    return 0
  fi
  if [[ -d "/etc/httpd/conf.d" ]]; then
    printf '%s' "/etc/httpd/conf.d"
    return 0
  fi
  printf '%s' ""
}

plume_sites_caddy_native_include_dir() {
  if [[ -n "${PLUME_CADDY_INCLUDE_DIR:-}" ]]; then
    printf '%s' "${PLUME_CADDY_INCLUDE_DIR}"
    return 0
  fi
  if [[ -d "/opt/homebrew/etc/caddy/conf.d" ]]; then
    printf '%s' "/opt/homebrew/etc/caddy/conf.d"
    return 0
  fi
  if [[ -d "/usr/local/etc/caddy/conf.d" ]]; then
    printf '%s' "/usr/local/etc/caddy/conf.d"
    return 0
  fi
  if [[ -d "/etc/caddy/conf.d" ]]; then
    printf '%s' "/etc/caddy/conf.d"
    return 0
  fi
  printf '%s' ""
}

plume_sites_native_include_dir_for_server() {
  local server="$1"
  case "${server}" in
    nginx) plume_sites_nginx_native_include_dir ;;
    apache2) plume_sites_apache2_native_include_dir ;;
    caddy) plume_sites_caddy_native_include_dir ;;
    *) printf '%s' "" ;;
  esac
}

plume_sites_publish_native_server_strict() {
  local id="$1"
  local source_conf="$2"
  local server="$3"
  local include_dir target_conf backup_file had_backup="false"
  include_dir="$(plume_sites_native_include_dir_for_server "${server}")"
  if [[ -z "${include_dir}" ]]; then
    plume_err "${server} strict mode: include directory not found (set include dir env)"
    return 1
  fi
  if [[ ! -d "${include_dir}" ]]; then
    plume_err "${server} strict mode: include directory not found: ${include_dir}"
    return 1
  fi
  target_conf="${include_dir}/${id}.conf"
  backup_file="$(mktemp)"
  if [[ -f "${target_conf}" ]]; then
    cp -f "${target_conf}" "${backup_file}"
    had_backup="true"
  fi
  if ! cp -f "${source_conf}" "${target_conf}"; then
    rm -f "${backup_file}"
    plume_err "${server} strict mode: failed to write target include: ${target_conf}"
    return 1
  fi
  # nginx workers / -t must be able to read includes (avoid umask 0077 → 600).
  chmod 644 "${target_conf}" 2>/dev/null || true
  if ! plume_sites_validate_native "${server}"; then
    if [[ "${had_backup}" == "true" ]]; then
      cp -f "${backup_file}" "${target_conf}" || true
    else
      rm -f "${target_conf}" || true
    fi
    rm -f "${backup_file}"
    plume_err "${server} strict mode: config test failed after publish"
    return 1
  fi
  if ! plume_sites_reload_native "${server}"; then
    if [[ "${had_backup}" == "true" ]]; then
      cp -f "${backup_file}" "${target_conf}" || true
    else
      rm -f "${target_conf}" || true
    fi
    rm -f "${backup_file}"
    plume_err "${server} strict mode: reload failed after publish"
    return 1
  fi
  PLUME_SITE_LAST_PUBLISH_RELOADED="true"
  rm -f "${backup_file}"
  return 0
}

plume_sites_publish_docker_lite() {
  local id="$1"
  local mode="${2:-docker-lite}"
  if ! plume_docker_lite_compose_preflight; then
    return 1
  fi
  local compose_file
  compose_file="$(plume_docker_lite_compose_file)"
  if [[ -n "${compose_file}" && -f "${compose_file}" ]]; then
    if declare -F plume_services_workspace_reconcile_php_matrix >/dev/null 2>&1; then
      plume_services_workspace_reconcile_php_matrix "${compose_file}" "up" || return 1
    fi
  fi
  plume_sites_publish_native "${id}" "${mode}" "publish"
}

plume_sites_publish_laradock_bridge() {
  local id="$1"
  local mode="${2:-laradock-bridge}"
  local record_file server
  record_file="$(plume_sites_file "${id}")"
  server="$(plume_sites_record_value "${record_file}" server)"
  if ! plume_laradock_bridge_preflight "${server}"; then
    return 1
  fi
  plume_sites_publish_native "${id}" "${mode}" "publish"
}

plume_docker_compose_has_v2() {
  command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1
}

plume_docker_compose_has_v1() {
  command -v docker-compose >/dev/null 2>&1
}

plume_docker_compose_exec() {
  local compose_file="${1:-}"
  shift || true
  if plume_docker_compose_has_v2; then
    if [[ -n "${compose_file}" ]]; then
      docker compose -f "${compose_file}" "$@"
    else
      docker compose "$@"
    fi
    return $?
  fi
  if plume_docker_compose_has_v1; then
    if [[ -n "${compose_file}" ]]; then
      docker-compose -f "${compose_file}" "$@"
    else
      docker-compose "$@"
    fi
    return $?
  fi
  return 127
}

plume_workspace_compose_state_file() {
  local mode="${1:-docker-lite}"
  printf '%s' "$(plume_state_dir)/workspace_${mode}.env"
}

plume_workspace_compose_state_set() {
  local mode="${1:-docker-lite}"
  local compose_file="${2:-}"
  local file
  file="$(plume_workspace_compose_state_file "${mode}")"
  mkdir -p "$(dirname "${file}")"
  printf 'compose_file=%s\n' "${compose_file}" > "${file}"
}

plume_workspace_compose_state_get() {
  local mode="${1:-docker-lite}"
  local file line
  file="$(plume_workspace_compose_state_file "${mode}")"
  [[ -f "${file}" ]] || return 1
  line="$(grep -E '^compose_file=' "${file}" || true)"
  [[ -n "${line}" ]] || return 1
  printf '%s' "${line#compose_file=}"
}

plume_docker_lite_compose_file() {
  if [[ -n "${PLUME_RUNTIME_DOCKER_LITE_COMPOSE_FILE:-}" ]]; then
    printf '%s' "${PLUME_RUNTIME_DOCKER_LITE_COMPOSE_FILE}"
    return 0
  fi
  if [[ -n "${PLUME_DOCKER_LITE_COMPOSE_FILE:-}" ]]; then
    printf '%s' "${PLUME_DOCKER_LITE_COMPOSE_FILE}"
    return 0
  fi
  local saved_path
  local compose_candidate
  saved_path="$(plume_mode_path_get docker-lite || true)"
  if [[ -n "${saved_path}" && -d "${saved_path}" ]]; then
    compose_candidate="${saved_path}/docker-compose.yml"
    if [[ -f "${compose_candidate}" ]]; then
      printf '%s' "${compose_candidate}"
      return 0
    fi
    compose_candidate="${saved_path}/compose.yml"
    if [[ -f "${compose_candidate}" ]]; then
      printf '%s' "${compose_candidate}"
      return 0
    fi
  fi
  local remembered
  remembered="$(plume_workspace_compose_state_get docker-lite || true)"
  if [[ -n "${remembered}" && -f "${remembered}" ]]; then
    printf '%s' "${remembered}"
    return 0
  fi
  if [[ -f "./docker-compose.yml" ]]; then
    printf '%s' "./docker-compose.yml"
    return 0
  fi
  if [[ -f "./compose.yml" ]]; then
    printf '%s' "./compose.yml"
    return 0
  fi
  printf '%s' ""
}

plume_docker_lite_compose_preflight() {
  local required
  required="$(plume_bool "${PLUME_DOCKER_LITE_COMPOSE_REQUIRED:-false}")"
  local compose_file
  compose_file="$(plume_docker_lite_compose_file)"
  if [[ "${required}" == "true" ]]; then
    if [[ -z "${compose_file}" || ! -f "${compose_file}" ]]; then
      plume_err "docker-lite compose file is required but not found (set mode path or create docker-compose.yml/compose.yml)"
      return 1
    fi
  fi
  return 0
}

plume_laradock_bridge_path() {
  local saved
  saved="$(plume_mode_path_get laradock-bridge || true)"
  if [[ -n "${saved}" ]]; then
    printf '%s' "${saved}"
    return 0
  fi
  printf '%s' "/opt/laradock"
}

plume_laradock_bridge_compose_file() {
  if [[ -n "${PLUME_LARADOCK_COMPOSE_FILE:-}" ]]; then
    printf '%s' "${PLUME_LARADOCK_COMPOSE_FILE}"
    return 0
  fi
  printf '%s/docker-compose.yml' "$(plume_laradock_bridge_path)"
}

plume_laradock_bridge_container_for_server() {
  local server="$1"
  case "${server}" in
    apache2) printf '%s' "${PLUME_LARADOCK_APACHE_CONTAINER_NAME:-apache2}" ;;
    caddy) printf '%s' "${PLUME_LARADOCK_CADDY_CONTAINER_NAME:-caddy}" ;;
    nginx|*) printf '%s' "${PLUME_LARADOCK_NGINX_CONTAINER_NAME:-nginx}" ;;
  esac
}

plume_laradock_bridge_preflight() {
  local server="${1:-nginx}"
  local strict
  strict="$(plume_bool "${PLUME_LARADOCK_STRICT:-false}")"
  if [[ "${strict}" != "true" ]]; then
    return 0
  fi

  local path compose_file
  path="$(plume_laradock_bridge_path)"
  compose_file="$(plume_laradock_bridge_compose_file)"

  if [[ ! -d "${path}" ]]; then
    plume_err "laradock strict mode: path not found: ${path}"
    return 1
  fi

  if [[ ! -f "${compose_file}" ]]; then
    plume_err "laradock strict mode: compose file not found: ${compose_file}"
    return 1
  fi

  if ! command -v docker >/dev/null 2>&1; then
    plume_err "laradock strict mode: docker is required"
    return 1
  fi

  local container_name
  container_name="$(plume_laradock_bridge_container_for_server "${server}")"
  if ! docker inspect "${container_name}" >/dev/null 2>&1; then
    plume_err "laradock strict mode: container not found: ${container_name}"
    return 1
  fi

  if [[ "$(docker inspect -f '{{.State.Running}}' "${container_name}" 2>/dev/null || true)" != "true" ]]; then
    plume_err "laradock strict mode: container is not running: ${container_name}"
    return 1
  fi
}

plume_sites_native_nginx_bin() {
  local nginx_bin=""
  if command -v nginx >/dev/null 2>&1; then
    nginx_bin="$(command -v nginx)"
  elif command -v brew >/dev/null 2>&1; then
    local nginx_prefix=""
    nginx_prefix="$(HOMEBREW_NO_AUTO_UPDATE=1 brew --prefix nginx 2>/dev/null || true)"
    if [[ -n "${nginx_prefix}" ]]; then
      if [[ -x "${nginx_prefix}/bin/nginx" ]]; then
        nginx_bin="${nginx_prefix}/bin/nginx"
      elif [[ -x "${nginx_prefix}/sbin/nginx" ]]; then
        nginx_bin="${nginx_prefix}/sbin/nginx"
      fi
    fi
  fi
  printf '%s' "${nginx_bin}"
}

# True when nginx master/pid is root-owned (port-80 brew/sudo path).
plume_sites_nginx_needs_elevated() {
  # Hermetic smokes / fake nginx: never require interactive sudo (D-158).
  if [[ "$(plume_bool "${PLUME_NATIVE_NGINX_FORCE_UNPRIVILEGED_RELOAD:-false}")" == "true" ]]; then
    return 1
  fi
  local pid_file="" prefix=""
  if command -v brew >/dev/null 2>&1; then
    prefix="$(HOMEBREW_NO_AUTO_UPDATE=1 brew --prefix 2>/dev/null || true)"
  fi
  [[ -n "${prefix}" ]] || prefix="/opt/homebrew"
  pid_file="${prefix}/var/run/nginx.pid"
  if [[ -f "${pid_file}" ]]; then
    # shellcheck disable=SC2012
    if [[ "$(ls -l "${pid_file}" 2>/dev/null | awk '{print $3}')" == "root" ]]; then
      return 0
    fi
  fi
  if pgrep -u root -f 'nginx: master process' >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

# Run nginx (or brew services) with sudo when root-owned daemon requires it.
# Interactive: confirm once (via /dev/tty) then password prompt.
# Noninteractive/CI: passwordless sudo -n only — never hang on Password: (D-158 / D-159).
plume_sites_nginx_run_elevated() {
  local reason="${1:-nginx is managed as root (often port 80); Plume needs administrator privileges.}"
  shift || true
  local rc=0
  if ! command -v sudo >/dev/null 2>&1; then
    return 1
  fi
  if sudo -n true 2>/dev/null; then
    sudo -n "$@" >/dev/null
    return $?
  fi
  if declare -F plume_interactive_is_noninteractive >/dev/null 2>&1 \
    && plume_interactive_is_noninteractive; then
    return 1
  fi
  if declare -F plume_macos_permissions_confirm_sudo >/dev/null 2>&1; then
    if ! plume_macos_permissions_confirm_sudo "sudo $*" "${reason}"; then
      return 1
    fi
  elif declare -F plume_interactive_enabled >/dev/null 2>&1; then
    if ! plume_interactive_enabled; then
      return 1
    fi
  elif [[ ! -t 0 && ! -r /dev/tty ]]; then
    return 1
  fi
  # Prompt on the real terminal when possible (IDE shells). Keep stderr for Password: / errors.
  set +e
  if [[ -r /dev/tty && -w /dev/tty ]]; then
    sudo "$@" </dev/tty >/dev/null
    rc=$?
  elif [[ -t 0 ]]; then
    sudo "$@" >/dev/null
    rc=$?
  else
    # Last resort: ask sudo to read the password from /dev/tty itself.
    sudo -p "Password: " "$@" >/dev/null
    rc=$?
  fi
  set -e
  return "${rc}"
}

plume_sites_nginx_config_test() {
  local nginx_bin err rc=0
  local test_pid=""
  nginx_bin="$(plume_sites_native_nginx_bin)"
  [[ -n "${nginx_bin}" ]] || return 0

  # Prefer an unprivileged -t that does not touch root-owned pid/error_log (D-159).
  # Root brew nginx on port 80 otherwise fails -t with Permission denied on nginx.pid
  # even when the config itself is valid — that wrongly blocks site publish.
  test_pid="$(mktemp -t plume-nginx-t.XXXXXX 2>/dev/null || echo "/tmp/plume-nginx-t.$$")"
  rm -f "${test_pid}" 2>/dev/null || true
  set +e
  err="$("${nginx_bin}" -t -g "pid ${test_pid}; error_log stderr;" 2>&1)"
  rc=$?
  set -e
  rm -f "${test_pid}" 2>/dev/null || true
  if [[ "${rc}" -eq 0 ]]; then
    return 0
  fi

  # Real config errors still fail above. Retry plain -t / elevated only for permission noise.
  set +e
  err="$("${nginx_bin}" -t 2>&1)"
  rc=$?
  set -e
  if [[ "${rc}" -eq 0 ]]; then
    return 0
  fi

  # macOS TCC / root nginx often reports "Operation not permitted" (not only "Permission denied").
  if printf '%s' "${err}" | grep -Eqi 'Permission denied|Operation not permitted' \
    || plume_sites_nginx_needs_elevated; then
    if plume_sites_nginx_run_elevated \
      "nginx config test needs admin because nginx is running as root." \
      "${nginx_bin}" -t; then
      return 0
    fi
    plume_err "elevated nginx -t failed (sudo cancelled, wrong password, or real config error)"
    if [[ -n "${err}" ]]; then
      plume_err "unprivileged nginx -t said:"
      printf '%s\n' "${err}" >&2
    fi
    return 1
  fi
  plume_err "nginx -t failed:"
  printf '%s\n' "${err}" >&2
  return 1
}

plume_sites_nginx_reload_or_restart() {
  local nginx_bin
  nginx_bin="$(plume_sites_native_nginx_bin)"

  if command -v systemctl >/dev/null 2>&1; then
    if systemctl list-units --type=service --state=running --no-legend 2>/dev/null | grep -q 'nginx.service'; then
      if command -v sudo >/dev/null 2>&1; then
        sudo systemctl reload nginx && return 0
      else
        systemctl reload nginx && return 0
      fi
    fi
  fi

  if plume_sites_nginx_needs_elevated; then
    if [[ -n "${nginx_bin}" ]] \
      && plume_sites_nginx_run_elevated \
        "nginx reload needs admin because nginx is running as root." \
        "${nginx_bin}" -s reload; then
      return 0
    fi
    if command -v brew >/dev/null 2>&1 \
      && plume_sites_nginx_run_elevated \
        "nginx restart needs admin (root brew service / port 80)." \
        env HOMEBREW_NO_AUTO_UPDATE=1 brew services restart nginx; then
      return 0
    fi
    plume_err "nginx reload needs administrator privileges (root-owned nginx / port 80)."
    plume_err "Approve sudo when prompted, or once: sudo brew services restart nginx"
    return 1
  fi

  if command -v brew >/dev/null 2>&1; then
    if HOMEBREW_NO_AUTO_UPDATE=1 brew services list 2>/dev/null | awk '{print $1" "$2}' | grep -q '^nginx started'; then
      HOMEBREW_NO_AUTO_UPDATE=1 brew services restart nginx >/dev/null 2>&1 && return 0
    fi
    # Process up but brew label not "started" (stale plist) — signal reload.
    if pgrep -f 'nginx: master process' >/dev/null 2>&1 && [[ -n "${nginx_bin}" ]]; then
      "${nginx_bin}" -s reload >/dev/null 2>&1 && return 0
    fi
    HOMEBREW_NO_AUTO_UPDATE=1 brew services start nginx >/dev/null 2>&1 \
      || HOMEBREW_NO_AUTO_UPDATE=1 brew services restart nginx >/dev/null 2>&1
    return $?
  fi

  if [[ -n "${nginx_bin}" ]]; then
    "${nginx_bin}" -s reload >/dev/null 2>&1
    return $?
  fi
  return 1
}

plume_sites_native_should_auto_provision_web() {
  [[ "$(plume_bool "${PLUME_SITE_AUTO_PROVISION_WEB:-true}")" == "true" ]] \
    || [[ "$(plume_bool "${PLUME_NATIVE_HOST_PROVISION:-false}")" == "true" ]]
}

plume_sites_native_ensure_web_runtime() {
  local server="${1:-nginx}"
  case "${server}" in
    nginx) ;;
    apache2)
      if command -v apachectl >/dev/null 2>&1 || command -v httpd >/dev/null 2>&1; then
        return 0
      fi
      ;;
    caddy)
      if command -v caddy >/dev/null 2>&1; then
        return 0
      fi
      plume_err "caddy is not installed; auto-provision supports nginx/apache2 via PLUME_WEB_SERVER_DRIVER"
      return 1
      ;;
    *)
      return 0
      ;;
  esac

  local nginx_bin
  nginx_bin="$(plume_sites_native_nginx_bin)"
  if [[ -n "${nginx_bin}" ]]; then
    if command -v brew >/dev/null 2>&1; then
      if ! HOMEBREW_NO_AUTO_UPDATE=1 brew services list 2>/dev/null | awk '{print $1" "$2}' | grep -q '^nginx started'; then
        # Root/port-80 nginx often shows brew "error" while master is still up — do not
        # fight it with an unprivileged brew start; elevated reload handles that (D-159).
        if pgrep -f 'nginx: master process' >/dev/null 2>&1; then
          :
        elif plume_sites_nginx_needs_elevated; then
          plume_info "starting nginx (elevated brew services)"
          plume_sites_nginx_run_elevated \
            "Starting nginx needs admin (root brew service / port 80)." \
            env HOMEBREW_NO_AUTO_UPDATE=1 brew services start nginx || true
        else
          plume_info "starting nginx (brew services)"
          HOMEBREW_NO_AUTO_UPDATE=1 brew services start nginx >/dev/null 2>&1 || true
        fi
      fi
    fi
    return 0
  fi

  if [[ "${server}" == "apache2" ]]; then
    if ! plume_sites_native_should_auto_provision_web; then
      plume_err "apache2 not installed; set PLUME_SITE_AUTO_PROVISION_WEB=true or install httpd manually"
      return 1
    fi
    if declare -F plume_native_host_provision_install >/dev/null 2>&1; then
      plume_info "apache2 not found; auto-provisioning web server"
      PLUME_WEB_SERVER_DRIVER=apache2 PLUME_NATIVE_HOST_PROVISION=true plume_native_host_provision_install web || return 1
      PLUME_WEB_SERVER_DRIVER=apache2 PLUME_NATIVE_HOST_PROVISION=true plume_native_host_provision_start web || return 1
      return 0
    fi
    return 1
  fi

  if ! plume_sites_native_should_auto_provision_web; then
    plume_err "nginx not installed; set PLUME_SITE_AUTO_PROVISION_WEB=true (default) or: PLUME_NATIVE_HOST_PROVISION=true plumectl services install web && services up web"
    return 1
  fi
  if ! declare -F plume_native_host_provision_install >/dev/null 2>&1; then
    plume_err "native host provision module not available"
    return 1
  fi
  plume_info "nginx not found; auto-provisioning web server (native host)"
  if declare -F plume_macos_permissions_confirm_host_install >/dev/null 2>&1; then
    plume_macos_permissions_confirm_host_install \
      "brew install nginx (via PLUME_SITE_AUTO_PROVISION_WEB)" \
      "Site publish needs nginx; Plume can install it with Homebrew." || return 1
  fi
  PLUME_NATIVE_HOST_PROVISION=true plume_native_host_provision_install web || return 1
  PLUME_NATIVE_HOST_PROVISION=true plume_native_host_provision_start web || return 1
  return 0
}

plume_sites_reload_native() {
  local server="$1"
  local validate
  validate="$(plume_bool "${PLUME_SITE_RELOAD_VALIDATE:-true}")"

  if ! plume_sites_native_ensure_web_runtime "${server}"; then
    echo "warn: cannot ensure ${server} runtime for reload"
    return 1
  fi

  if [[ "${validate}" == "true" ]]; then
    if ! plume_sites_validate_native "${server}"; then
      echo "warn: ${server} config test failed; reload skipped"
      return 1
    fi
  fi

  case "${server}" in
    apache2)
      if command -v systemctl >/dev/null 2>&1; then
        if systemctl list-units --type=service --state=running --no-legend 2>/dev/null | grep -Eq 'apache2.service|httpd.service'; then
          if command -v sudo >/dev/null 2>&1; then
            sudo systemctl reload apache2 2>/dev/null || sudo systemctl reload httpd
          else
            systemctl reload apache2 2>/dev/null || systemctl reload httpd
          fi
          return 0
        fi
      fi
      if command -v brew >/dev/null 2>&1; then
        if HOMEBREW_NO_AUTO_UPDATE=1 brew services list 2>/dev/null | awk '{print $1" "$2}' | grep -Eq '^httpd started|^apache2 started'; then
          HOMEBREW_NO_AUTO_UPDATE=1 brew services restart httpd >/dev/null 2>&1 || HOMEBREW_NO_AUTO_UPDATE=1 brew services restart apache2 >/dev/null 2>&1
          return 0
        fi
      fi
      if command -v apachectl >/dev/null 2>&1; then
        apachectl -k graceful >/dev/null 2>&1
        return 0
      fi
      if command -v httpd >/dev/null 2>&1; then
        httpd -k graceful >/dev/null 2>&1
        return 0
      fi
      echo "warn: cannot detect apache2 reload method"
      return 1
      ;;
    caddy)
      if command -v caddy >/dev/null 2>&1; then
        caddy reload >/dev/null 2>&1 || caddy reload --config /etc/caddy/Caddyfile >/dev/null 2>&1 || true
        return 0
      fi
      echo "warn: cannot detect caddy reload method"
      return 1
      ;;
    nginx|*)
      ;;
  esac

  if [[ "${server}" == "nginx" || "${server}" == "" ]]; then
    if plume_sites_nginx_reload_or_restart; then
      return 0
    fi
    if plume_sites_nginx_needs_elevated; then
      # reload_or_restart already printed the admin hint
      return 1
    fi
  fi

  echo "warn: cannot detect nginx reload method — try: plumectl services restart web"
  return 1
}

plume_sites_validate_native() {
  local target="$1"
  case "${target}" in
    apache2)
      if command -v apachectl >/dev/null 2>&1; then
        apachectl -t >/dev/null 2>&1
        return $?
      fi
      if command -v httpd >/dev/null 2>&1; then
        httpd -t >/dev/null 2>&1
        return $?
      fi
      return 0
      ;;
    caddy)
      if command -v caddy >/dev/null 2>&1; then
        caddy validate >/dev/null 2>&1 || caddy validate --config /etc/caddy/Caddyfile >/dev/null 2>&1
        return $?
      fi
      return 0
      ;;
    nginx|*)
      plume_sites_nginx_config_test
      return $?
      ;;
  esac
}

plume_sites_reload_docker_lite() {
  local server="$1"
  if ! plume_docker_lite_compose_preflight; then
    return 1
  fi
  local compose_file
  compose_file="$(plume_docker_lite_compose_file)"
  if [[ -n "${compose_file}" ]] && [[ ! -f "${compose_file}" ]]; then
    plume_warn "docker-lite compose file not found: ${compose_file}"
    compose_file=""
  fi
  if plume_docker_compose_has_v2 || plume_docker_compose_has_v1; then
    local compose_service
    case "${server}" in
      apache2) compose_service="${PLUME_DOCKER_LITE_APACHE_SERVICE:-apache2}" ;;
      caddy) compose_service="${PLUME_DOCKER_LITE_CADDY_SERVICE:-caddy}" ;;
      nginx|*) compose_service="${PLUME_DOCKER_LITE_WEB_SERVICE:-nginx}" ;;
    esac
    case "${server}" in
      apache2)
        plume_docker_compose_exec "${compose_file}" exec -T "${compose_service}" apachectl -k graceful >/dev/null 2>&1 || true
        ;;
      caddy)
        plume_docker_compose_exec "${compose_file}" exec -T "${compose_service}" caddy reload >/dev/null 2>&1 || true
        ;;
      nginx|*)
        plume_docker_compose_exec "${compose_file}" exec -T "${compose_service}" nginx -s reload >/dev/null 2>&1 || true
        ;;
    esac
    return 0
  fi
  echo "warn: docker-lite reload not implemented on this environment (docker compose missing)"
  return 1
}

plume_sites_reload_laradock_bridge() {
  local server="$1"
  if ! plume_laradock_bridge_preflight "${server}"; then
    return 1
  fi
  if command -v docker >/dev/null 2>&1; then
    local container_name
    container_name="$(plume_laradock_bridge_container_for_server "${server}")"
    case "${server}" in
      apache2) docker exec "${container_name}" apachectl -k graceful >/dev/null 2>&1 || true ;;
      caddy) docker exec "${container_name}" caddy reload >/dev/null 2>&1 || true ;;
      nginx|*) docker exec "${container_name}" nginx -s reload >/dev/null 2>&1 || true ;;
    esac
    return 0
  fi
  echo "warn: laradock-bridge reload not implemented on this environment (docker missing)"
  return 1
}

plume_sites_publish_dispatch() {
  local id="$1"
  local action="$2"
  local mode="${3:-$(plume_mode_current)}"

  case "${mode}" in
    docker-lite)
      case "${action}" in
        publish)
          plume_sites_publish_docker_lite "${id}" "${mode}"
          ;;
        remove)
          return 0
          ;;
        reload)
          local file server
          file="$(plume_sites_file "${id}")"
          server="$(plume_sites_record_value "${file}" server)"
          plume_sites_reload_docker_lite "${server}"
          ;;
        *)
          return 2
          ;;
      esac
      ;;
    laradock-bridge)
      case "${action}" in
        publish)
          plume_sites_publish_laradock_bridge "${id}" "${mode}"
          ;;
        remove)
          return 0
          ;;
        reload)
          local file server
          file="$(plume_sites_file "${id}")"
          server="$(plume_sites_record_value "${file}" server)"
          plume_sites_reload_laradock_bridge "${server}"
          ;;
        *)
          return 2
          ;;
      esac
      ;;
    native|*)
      case "${action}" in
        publish)
          plume_sites_publish_native "${id}" "${mode}"
          ;;
        remove)
          return 0
          ;;
        reload)
          local file server
          file="$(plume_sites_file "${id}")"
          server="$(plume_sites_record_value "${file}" server)"
          plume_sites_reload_native "${server}"
          ;;
        *)
          return 2
          ;;
      esac
      ;;
  esac
}

plume_sites_publish_nginx() {
  local mode="${2:-$(plume_mode_current)}"
  plume_sites_publish_dispatch "$1" "publish" "${mode}"
}

plume_sites_unpublish_nginx() {
  local id="$1"
  local server
  local mode="${2:-${PLUME_MODE:-$(plume_mode_current)}}"
  local record_file server_conf_file
  record_file="$(plume_sites_file "${id}")"
  server="$(plume_sites_record_value "${record_file}" server)"
  server_conf_file="$(plume_sites_cache_dir "${server}" "${mode}")/${id}.conf"
  rm -f "${server_conf_file}"
  if [[ "${mode}" == "native" ]]; then
    local strict_enabled="false"
    case "${server}" in
      nginx) [[ "$(plume_bool "${PLUME_SITE_NGINX_STRICT:-false}")" == "true" ]] && strict_enabled="true" ;;
      apache2) [[ "$(plume_bool "${PLUME_SITE_APACHE2_STRICT:-false}")" == "true" ]] && strict_enabled="true" ;;
      caddy) [[ "$(plume_bool "${PLUME_SITE_CADDY_STRICT:-false}")" == "true" ]] && strict_enabled="true" ;;
    esac
    if [[ "${strict_enabled}" == "true" ]]; then
      local include_dir target_conf
      include_dir="$(plume_sites_native_include_dir_for_server "${server}")"
      if [[ -n "${include_dir}" && -d "${include_dir}" ]]; then
        target_conf="${include_dir}/${id}.conf"
        rm -f "${target_conf}" || true
        plume_sites_validate_native "${server}" >/dev/null 2>&1 || true
        plume_sites_reload_native "${server}" >/dev/null 2>&1 || true
      fi
    fi
  fi
  return 0
}

plume_sites_cleanup_mode_artifacts() {
  local id="$1"
  local mode="${2:-$(plume_mode_current)}"
  local record_file server cache_conf
  record_file="$(plume_sites_file "${id}")"
  server="$(plume_sites_record_value "${record_file}" server)"
  cache_conf="$(plume_sites_cache_dir "${server}" "${mode}")/${id}.conf"
  rm -f "${cache_conf}"

  if [[ "${mode}" == "native" ]]; then
    local include_dir target_conf
    include_dir="$(plume_sites_native_include_dir_for_server "${server}")"
    if [[ -n "${include_dir}" && -d "${include_dir}" ]]; then
      target_conf="${include_dir}/${id}.conf"
      rm -f "${target_conf}" || true
      plume_sites_validate_native "${server}" >/dev/null 2>&1 || true
      plume_sites_reload_native "${server}" >/dev/null 2>&1 || true
    fi
  fi
}

plume_sites_reload_nginx() {
  local id="$1"
  local file server mode="${2:-${PLUME_MODE:-$(plume_mode_current)}}"
  file="$(plume_sites_file "${id}")"
  server="$(plume_sites_record_value "${file}" server)"
  case "${mode}" in
    docker-lite)
      plume_sites_reload_docker_lite "${server}"
      ;;
    laradock-bridge)
      plume_sites_reload_laradock_bridge "${server}"
      ;;
    native|*)
      plume_sites_reload_native "${server}"
      ;;
  esac
}
