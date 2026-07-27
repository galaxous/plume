#!/usr/bin/env bash
set -euo pipefail

plume_services_manifest_file() {
  printf '%s' "${PLUME_SERVICES_MANIFEST_FILE:-$HOME/.config/plume/services.yml}"
}

plume_services_manifest_builtin_example() {
  printf '%s' "${PLUME_SERVICES_MANIFEST_EXAMPLE:-${ROOT_DIR}/templates/services.yml.example}"
}

plume_services_manifest_exists() {
  [[ -f "$(plume_services_manifest_file)" ]]
}

plume_services_manifest_bootstrap_if_missing() {
  local dest example dir
  dest="$(plume_services_manifest_file)"
  if [[ -f "${dest}" ]]; then
    return 0
  fi
  example="$(plume_services_manifest_builtin_example)"
  if [[ ! -f "${example}" ]]; then
    return 0
  fi
  dir="$(dirname "${dest}")"
  mkdir -p "${dir}"
  cp "${example}" "${dest}"
  plume_info "bootstrapped services manifest from ${example} -> ${dest}"
}

plume_services_manifest_trim() {
  local s="$1"
  s="${s%%#*}"
  printf '%s' "${s}" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g'
}

plume_services_manifest_unquote() {
  local v="$1"
  v="${v#\"}"; v="${v%\"}"
  v="${v#\'}"; v="${v%\'}"
  printf '%s' "${v}"
}

# Read scalar `key:` under services.<section> (two-space indent under section).
plume_services_manifest_yaml_scalar() {
  local file="$1"
  local section="$2"
  local key="$3"

  if [[ ! -f "${file}" ]]; then
    return 1
  fi

  local line trimmed in_services="false" current_section="" section_indent=0
  while IFS= read -r line; do
    trimmed="$(plume_services_manifest_trim "${line}")"
    [[ -z "${trimmed}" ]] && continue

    if [[ "${trimmed}" == "services:" ]]; then
      in_services="true"
      current_section=""
      continue
    fi

    if [[ "${in_services}" != "true" ]]; then
      continue
    fi

    if [[ "${line}" =~ ^[^[:space:]] ]]; then
      in_services="false"
      current_section=""
      continue
    fi

    if [[ "${line}" =~ ^[[:space:]][[:space:]][^[:space:]#]+:[[:space:]]*$ ]]; then
      local sect="${trimmed%:}"
      sect="$(plume_services_manifest_unquote "${sect}")"
      current_section="${sect}"
      section_indent=2
      continue
    fi

    [[ -n "${current_section}" ]] || continue
    [[ "${current_section}" == "${section}" ]] || continue

    if [[ "${trimmed}" == "${key}:"* ]]; then
      local val="${trimmed#${key}:}"
      val="$(plume_services_manifest_trim "${val}")"
      val="$(plume_services_manifest_unquote "${val}")"
      [[ -n "${val}" ]] || return 1
      printf '%s' "${val}"
      return 0
    fi
  done < "${file}"

  return 1
}

# Read YAML list under services.<section>.<key> (- item lines).
plume_services_manifest_yaml_list() {
  local file="$1"
  local section="$2"
  local key="$3"

  if [[ ! -f "${file}" ]]; then
    return 1
  fi

  local line trimmed in_services="false" current_section="" in_list="false"
  local -a items=()

  while IFS= read -r line; do
    trimmed="$(plume_services_manifest_trim "${line}")"
    [[ -z "${trimmed}" ]] && continue

    if [[ "${trimmed}" == "services:" ]]; then
      in_services="true"
      current_section=""
      in_list="false"
      continue
    fi

    if [[ "${in_services}" != "true" ]]; then
      continue
    fi

    if [[ "${line}" =~ ^[^[:space:]] ]]; then
      in_services="false"
      in_list="false"
      continue
    fi

    if [[ "${line}" =~ ^[[:space:]][[:space:]][^[:space:]#]+:[[:space:]]*$ ]]; then
      local sect="${trimmed%:}"
      sect="$(plume_services_manifest_unquote "${sect}")"
      current_section="${sect}"
      in_list="false"
      continue
    fi

    [[ "${current_section}" == "${section}" ]] || continue

    if [[ "${trimmed}" == "${key}:" ]]; then
      in_list="true"
      continue
    fi

    if [[ "${in_list}" == "true" ]]; then
      if [[ "${trimmed}" == "-"* ]]; then
        local item="${trimmed#-}"
        item="$(plume_services_manifest_trim "${item}")"
        item="$(plume_services_manifest_unquote "${item}")"
        items+=("${item}")
        continue
      fi
      if [[ "${line}" =~ ^[[:space:]][[:space:]][[:space:]][[:space:]] ]]; then
        continue
      fi
      in_list="false"
    fi
  done < "${file}"

  if ((${#items[@]} == 0)); then
    return 1
  fi
  local IFS=','
  printf '%s' "${items[*]}"
}

# Inline flow map on a service line: `composer: { enabled: true, version: "latest" }`
plume_services_manifest_yaml_inline_field() {
  local file="$1"
  local section="$2"
  local key="$3"

  if [[ ! -f "${file}" ]]; then
    return 1
  fi

  local line trimmed in_services="false" rest val
  while IFS= read -r line; do
    trimmed="$(plume_services_manifest_trim "${line}")"
    [[ -z "${trimmed}" ]] && continue

    if [[ "${trimmed}" == "services:" ]]; then
      in_services="true"
      continue
    fi

    if [[ "${in_services}" != "true" ]]; then
      continue
    fi

    if [[ "${line}" =~ ^[^[:space:]] ]]; then
      in_services="false"
      continue
    fi

    [[ "${trimmed}" == "${section}:"* ]] || continue
    rest="${trimmed#${section}:}"
    rest="$(plume_services_manifest_trim "${rest}")"
    [[ "${rest}" == \{* ]] || return 1

    if [[ "${rest}" =~ ${key}:[[:space:]]*([^,}]+) ]]; then
      val="${BASH_REMATCH[1]}"
      val="$(plume_services_manifest_trim "${val}")"
      val="$(plume_services_manifest_unquote "${val}")"
      [[ -n "${val}" ]] || return 1
      printf '%s' "${val}"
      return 0
    fi
    return 1
  done < "${file}"

  return 1
}

# Block scalar or inline `{ key: value }` under services.<section>.
plume_services_manifest_service_field() {
  local file="$1"
  local section="$2"
  local key="$3"
  local v=""

  if v="$(plume_services_manifest_yaml_scalar "${file}" "${section}" "${key}" 2>/dev/null)"; then
    printf '%s' "${v}"
    return 0
  fi
  if v="$(plume_services_manifest_yaml_inline_field "${file}" "${section}" "${key}" 2>/dev/null)"; then
    printf '%s' "${v}"
    return 0
  fi
  return 1
}

# Single mapping table: registry service → PLUME_* env keys (enabled + version).
plume_services_manifest_env_mapping_rows() {
  local svc enabled_key version_key
  if ! declare -F plume_service_names >/dev/null 2>&1; then
    return 0
  fi
  while IFS= read -r svc; do
    [[ -n "${svc}" ]] || continue
    case "${svc}" in
      web|php) continue ;;
    esac
    enabled_key="$(plume_service_env_key "${svc}" 2>/dev/null || true)"
    version_key="$(plume_service_version_env_key "${svc}" 2>/dev/null || true)"
    [[ -n "${enabled_key}" ]] || continue
    printf '%s|%s|%s\n' "${svc}" "${enabled_key}" "${version_key:-}"
  done < <(plume_service_names)
}

plume_services_manifest_apply_registry_services() {
  local file="$1"
  local row section enabled_key version_key v
  while IFS='|' read -r section enabled_key version_key; do
    [[ -n "${section}" && -n "${enabled_key}" ]] || continue
    if v="$(plume_services_manifest_service_field "${file}" "${section}" enabled 2>/dev/null)"; then
      plume_services_manifest_export "${enabled_key}" "${v}"
    fi
    if [[ -n "${version_key}" ]]; then
      if v="$(plume_services_manifest_service_field "${file}" "${section}" version 2>/dev/null)"; then
        plume_services_manifest_export "${version_key}" "${v}"
      fi
    fi
  done < <(plume_services_manifest_env_mapping_rows)
}

plume_services_manifest_native_provisionable() {
  local service="$1"
  if declare -F plume_native_host_provision_supported >/dev/null 2>&1; then
    plume_native_host_provision_supported "${service}"
    return $?
  fi
  case "${service}" in
    web|nginx|apache2|mariadb|mysql|redis) return 0 ;;
    *) return 1 ;;
  esac
}

plume_services_manifest_provision_enabled_native() {
  local service="$1"
  local auto_start="${2:-true}"
  local enabled_key enabled_val

  enabled_key="$(plume_service_env_key "${service}" 2>/dev/null || true)"
  [[ -n "${enabled_key}" ]] || return 0
  enabled_val="${!enabled_key:-false}"
  if [[ "$(plume_bool "${enabled_val}")" != "true" ]]; then
    return 0
  fi

  if ! plume_services_manifest_native_provisionable "${service}"; then
    plume_warn "manifest: ${service} enabled but no native host package hook; use docker-lite/laradock-bridge or install manually"
    return 0
  fi

  plume_native_host_provision_install "${service}" || return 2
  if [[ "${auto_start}" == "true" ]]; then
    plume_native_host_provision_start "${service}" || return 2
  fi
}

plume_services_manifest_provision_php_matrix() {
  local csv="${PLUME_PHP_INSTALLED_VERSIONS:-}"
  local version

  if [[ "$(plume_bool "${PLUME_PHP_ENABLED:-true}")" != "true" ]]; then
    return 0
  fi
  [[ -n "${csv}" ]] || return 0

  if ! declare -F plume_native_php_install_host_version >/dev/null 2>&1; then
    plume_warn "manifest: php versions listed but native php install helpers unavailable"
    return 0
  fi

  IFS=',' read -r -a _manifest_php_versions <<< "${csv}"
  for version in "${_manifest_php_versions[@]}"; do
    version="$(printf '%s' "${version}" | sed 's/^ *//;s/ *$//')"
    [[ -n "${version}" ]] || continue
    version="$(plume_php_version_normalize "${version}")" || return 2
    plume_native_php_install_host_version "${version}" || return 2
    plume_native_php_verify_host_binaries "${version}" || return 2
    if declare -F plume_php_register_installed_version >/dev/null 2>&1; then
      plume_php_register_installed_version "${version}" || return 2
    fi
  done
}

plume_services_manifest_export() {
  local key="$1"
  local value="$2"
  [[ -n "${value}" ]] || return 0
  export "${key}=${value}"
}

plume_services_manifest_apply() {
  local file
  file="$(plume_services_manifest_file)"
  if [[ ! -f "${file}" ]]; then
    return 0
  fi

  local v engine db_engine versions

  if v="$(plume_services_manifest_yaml_scalar "${file}" web engine 2>/dev/null)"; then
    plume_services_manifest_export "PLUME_WEB_SERVER_DRIVER" "${v}"
  fi
  if v="$(plume_services_manifest_yaml_scalar "${file}" web manage_main_config 2>/dev/null)"; then
    plume_services_manifest_export "PLUME_NATIVE_NGINX_MANAGE_MAIN_CONFIG" "${v}"
  fi
  if v="$(plume_services_manifest_yaml_scalar "${file}" web http_port 2>/dev/null)"; then
    plume_services_manifest_export "PLUME_NATIVE_NGINX_HTTP_PORT" "${v}"
    plume_services_manifest_export "PLUME_WEB_PORT" "${v}"
  fi
  if v="$(plume_services_manifest_yaml_scalar "${file}" web auto_provision 2>/dev/null)"; then
    plume_services_manifest_export "PLUME_SITE_AUTO_PROVISION_WEB" "${v}"
    if [[ "$(plume_bool "${v}")" == "true" ]]; then
      plume_services_manifest_export "PLUME_NATIVE_HOST_PROVISION" "true"
    fi
  fi
  if v="$(plume_services_manifest_service_field "${file}" web enabled 2>/dev/null)"; then
    plume_services_manifest_export "PLUME_WEB_SERVER_ENABLED" "${v}"
  fi

  if v="$(plume_services_manifest_service_field "${file}" php enabled 2>/dev/null)"; then
    plume_services_manifest_export "PLUME_PHP_ENABLED" "${v}"
  fi
  if v="$(plume_services_manifest_yaml_scalar "${file}" php default_version 2>/dev/null)"; then
    plume_services_manifest_export "PLUME_PHP_DEFAULT_VERSION" "${v}"
    plume_services_manifest_export "PLUME_PHP_VERSION" "${v}"
  fi
  if versions="$(plume_services_manifest_yaml_list "${file}" php versions 2>/dev/null)"; then
    plume_services_manifest_export "PLUME_PHP_INSTALLED_VERSIONS" "${versions}"
  fi
  if v="$(plume_services_manifest_yaml_scalar "${file}" php extensions_profile 2>/dev/null)"; then
    plume_services_manifest_export "PLUME_PHP_EXTENSIONS_AUTO_SYNC_PROFILE" "${v}"
  fi

  if db_engine="$(plume_services_manifest_yaml_scalar "${file}" database engine 2>/dev/null)"; then
    case "${db_engine}" in
      mariadb)
        plume_services_manifest_export "PLUME_MARIADB_ENABLED" "true"
        plume_services_manifest_export "PLUME_MYSQL_ENABLED" "false"
        ;;
      mysql)
        plume_services_manifest_export "PLUME_MARIADB_ENABLED" "false"
        plume_services_manifest_export "PLUME_MYSQL_ENABLED" "true"
        ;;
    esac
  fi
  if v="$(plume_services_manifest_yaml_scalar "${file}" database version 2>/dev/null)"; then
    if [[ "$(plume_bool "${PLUME_MYSQL_ENABLED:-false}")" == "true" ]]; then
      plume_services_manifest_export "PLUME_MYSQL_VERSION" "${v}"
    else
      plume_services_manifest_export "PLUME_MARIADB_VERSION" "${v}"
    fi
  fi

  plume_services_manifest_apply_registry_services "${file}"

  if v="$(plume_services_manifest_yaml_scalar "${file}" provision interactive 2>/dev/null)"; then
    if [[ "$(plume_bool "${v}")" == "false" ]]; then
      plume_services_manifest_export "PLUME_NONINTERACTIVE" "true"
    fi
  fi

  export PLUME_SERVICES_MANIFEST_LOADED=true
  export PLUME_SERVICES_MANIFEST_PATH="${file}"
}

plume_services_manifest_print_effective() {
  local file
  file="$(plume_services_manifest_file)"
  if [[ ! -f "${file}" ]]; then
    echo "services_manifest=(none)"
    return 0
  fi
  echo "services_manifest=${file}"
  echo "effective_web_driver=${PLUME_WEB_SERVER_DRIVER:-nginx}"
  echo "effective_nginx_manage_main=${PLUME_NATIVE_NGINX_MANAGE_MAIN_CONFIG:-false}"
  echo "effective_http_port=${PLUME_NATIVE_NGINX_HTTP_PORT:-80}"
  echo "effective_plume_web_port=${PLUME_WEB_PORT:-80}"
  echo "effective_web_enabled=${PLUME_WEB_SERVER_ENABLED:-true}"
  echo "effective_php_default=${PLUME_PHP_DEFAULT_VERSION:-8.3}"
  echo "effective_php_enabled=${PLUME_PHP_ENABLED:-true}"
  echo "effective_php_installed_versions=${PLUME_PHP_INSTALLED_VERSIONS:-8.1,8.2,8.3}"
  echo "effective_native_host_provision=${PLUME_NATIVE_HOST_PROVISION:-false}"

  local row section enabled_key version_key enabled_val version_val
  while IFS='|' read -r section enabled_key version_key; do
    [[ -n "${section}" && -n "${enabled_key}" ]] || continue
    enabled_val="${!enabled_key:-false}"
    enabled_val="$(plume_bool "${enabled_val}")"
    echo "effective_${section}_enabled=${enabled_val}"
    if [[ -n "${version_key}" ]]; then
      version_val="${!version_key:-latest}"
      echo "effective_${section}_version=${version_val}"
    fi
  done < <(plume_services_manifest_env_mapping_rows)
}

plume_services_manifest_on_first_run_flag_file() {
  printf '%s/on_first_run_provision.done' "$(plume_state_dir)"
}

plume_services_manifest_on_first_run_requested() {
  local file v
  file="$(plume_services_manifest_file)"
  if [[ ! -f "${file}" ]]; then
    return 1
  fi
  if v="$(plume_services_manifest_yaml_scalar "${file}" provision on_first_run 2>/dev/null)"; then
    [[ "$(plume_bool "${v}")" == "true" ]]
    return $?
  fi
  return 1
}

plume_services_manifest_on_first_run_done() {
  [[ -f "$(plume_services_manifest_on_first_run_flag_file)" ]]
}

plume_services_manifest_mark_on_first_run_done() {
  local flag
  flag="$(plume_services_manifest_on_first_run_flag_file)"
  plume_ensure_state_dirs
  printf '%s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u)" > "${flag}"
}

plume_services_manifest_maybe_on_first_run_provision() {
  if [[ "$(plume_bool "${PLUME_SKIP_ON_FIRST_RUN_PROVISION:-false}")" == "true" ]]; then
    return 0
  fi
  if ! plume_services_manifest_on_first_run_requested; then
    return 0
  fi
  if plume_services_manifest_on_first_run_done; then
    return 0
  fi
  if [[ "$(plume_mode_current)" != "native" ]]; then
    plume_info "on_first_run provision skipped (mode=$(plume_mode_current); need native)"
    return 0
  fi

  plume_info "on_first_run: running manifest provision (once)"
  plume_services_manifest_provision_services "false"
}

plume_services_manifest_provision_services() {
  local dry_run="${1:-false}"
  local file auto_start
  file="$(plume_services_manifest_file)"
  if [[ ! -f "${file}" ]]; then
    plume_err "services manifest not found: ${file} (run: plumectl init host)"
    return 2
  fi

  if [[ "${dry_run}" == "true" ]]; then
    plume_services_manifest_print_effective
    plume_info "dry-run: no host packages installed"
    return 0
  fi

  if [[ "$(plume_mode_current)" != "native" ]]; then
    plume_err "manifest provision requires mode=native (current: $(plume_mode_current))"
    return 2
  fi

  plume_require_native_install_privileges || return 2
  export PLUME_NATIVE_HOST_PROVISION=true

  plume_macos_permissions_maybe_prompt_registry "services-provision" || return 2

  plume_native_host_provision_install web || return 2
  plume_native_host_provision_start web || return 2

  auto_start="true"
  if v="$(plume_services_manifest_service_field "${file}" database auto_start 2>/dev/null)"; then
    auto_start="$(plume_bool "${v}")"
  fi

  plume_services_manifest_provision_enabled_native mariadb "${auto_start}" || return 2
  plume_services_manifest_provision_enabled_native mysql "${auto_start}" || return 2
  plume_services_manifest_provision_enabled_native redis "true" || return 2
  plume_services_manifest_provision_enabled_native mailpit "true" || return 2

  plume_services_manifest_provision_php_matrix || return 2

  plume_info "manifest provision complete (native host packages for supported services; optional services: enable in YAML + docker mode or manual)"

  if plume_services_manifest_on_first_run_requested; then
    plume_services_manifest_mark_on_first_run_done
  fi
  return 0
}
