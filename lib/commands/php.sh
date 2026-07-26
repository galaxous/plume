#!/usr/bin/env bash
set -euo pipefail

plume_php_state_file() {
  printf '%s' "$(plume_state_dir)/php.env"
}

plume_php_version_normalize() {
  local raw="${1:-}"
  raw="$(printf '%s' "${raw}" | sed 's/^ *//;s/ *$//')"
  if [[ ! "${raw}" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]]; then
    plume_err "invalid php version: ${raw}"
    return 2
  fi
  printf '%s\n' "${raw}"
}

plume_php_versions_csv_normalize() {
  local input="${1:-}"
  local item norm
  local out_csv=""
  local list
  list="$(printf '%s' "${input}" | tr ',' ' ')"
  for item in ${list}; do
    item="$(printf '%s' "${item}" | sed 's/^ *//;s/ *$//')"
    [[ -z "${item}" ]] && continue
    norm="$(plume_php_version_normalize "${item}")" || return 2
    if ! plume_php_csv_has_version "${out_csv}" "${norm}"; then
      if [[ -n "${out_csv}" ]]; then
        out_csv="${out_csv},${norm}"
      else
        out_csv="${norm}"
      fi
    fi
  done
  if [[ -z "${out_csv}" ]]; then
    plume_err "installed php versions cannot be empty"
    return 2
  fi
  printf '%s\n' "${out_csv}"
}

plume_php_csv_has_version() {
  local csv="${1:-}"
  local version="${2:-}"
  local item
  local list
  list="$(printf '%s' "${csv}" | tr ',' ' ')"
  for item in ${list}; do
    item="$(printf '%s' "${item}" | sed 's/^ *//;s/ *$//')"
    [[ "${item}" == "${version}" ]] && return 0
  done
  return 1
}

plume_php_alias_key_for_name() {
  local alias_name="${1:-}"
  if [[ ! "${alias_name}" =~ ^[A-Za-z][A-Za-z0-9_]*$ ]]; then
    plume_err "invalid php alias name: ${alias_name}"
    return 2
  fi
  printf 'PLUME_PHP_ALIAS_%s\n' "$(printf '%s' "${alias_name}" | tr '[:lower:]' '[:upper:]')"
}

plume_php_alias_name_for_version() {
  local version="${1:-}"
  local compact
  compact="$(printf '%s' "${version}" | tr -d '.')"
  printf 'php%s\n' "${compact}"
}

plume_php_version_major_minor() {
  local version="${1:-}"
  version="$(printf '%s' "${version}" | sed 's/^ *//;s/ *$//')"
  if [[ "${version}" =~ ^([0-9]+)\.([0-9]+) ]]; then
    printf '%s.%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    return 0
  fi
  return 1
}

plume_php_candidate_from_search_path() {
  local bin_name="${1:-}"
  local search_path="${PLUME_PHP_SHIM_SEARCH_PATH:-}"
  local dir candidate
  [[ -n "${search_path}" ]] || return 1
  IFS=':' read -r -a _search_dirs <<< "${search_path}"
  for dir in "${_search_dirs[@]}"; do
    [[ -n "${dir}" ]] || continue
    candidate="${dir}/${bin_name}"
    if [[ -x "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done
  return 1
}

plume_php_candidate_from_path() {
  local bin_name="${1:-}"
  local shim_dir dir candidate
  shim_dir="$(plume_php_shim_dir)"
  IFS=':' read -r -a _path_dirs <<< "${PATH:-}"
  for dir in "${_path_dirs[@]}"; do
    [[ -n "${dir}" ]] || continue
    # Avoid recursive self-resolution from plume shim directory.
    if [[ "${dir}" == "${shim_dir}" ]]; then
      continue
    fi
    candidate="${dir}/${bin_name}"
    if [[ -x "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done
  return 1
}

plume_php_find_cli_bin() {
  local version="${1:-}"
  local mm candidate
  mm="$(plume_php_version_major_minor "${version}" || true)"
  [[ -n "${mm}" ]] || return 1

  candidate="$(plume_php_candidate_from_search_path "php${mm}" || true)"
  [[ -n "${candidate}" ]] && {
    printf '%s\n' "${candidate}"
    return 0
  }

  candidate="$(plume_php_candidate_from_search_path "php${mm//./}" || true)"
  [[ -n "${candidate}" ]] && {
    printf '%s\n' "${candidate}"
    return 0
  }

  candidate="$(plume_php_candidate_from_path "php${mm}" || true)"
  [[ -n "${candidate}" ]] && {
    printf '%s\n' "${candidate}"
    return 0
  }

  candidate="$(plume_php_candidate_from_path "php${mm//./}" || true)"
  [[ -n "${candidate}" ]] && {
    printf '%s\n' "${candidate}"
    return 0
  }

  candidate="/opt/homebrew/opt/php@${mm}/bin/php"
  [[ -x "${candidate}" ]] && {
    printf '%s\n' "${candidate}"
    return 0
  }

  candidate="/usr/local/opt/php@${mm}/bin/php"
  [[ -x "${candidate}" ]] && {
    printf '%s\n' "${candidate}"
    return 0
  }

  if command -v php >/dev/null 2>&1; then
    local current_mm
    current_mm="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || true)"
    if [[ "${current_mm}" == "${mm}" ]]; then
      command -v php
      return 0
    fi
  fi

  return 1
}

plume_php_find_fpm_bin() {
  local version="${1:-}"
  local mm candidate
  mm="$(plume_php_version_major_minor "${version}" || true)"
  [[ -n "${mm}" ]] || return 1

  candidate="$(plume_php_candidate_from_search_path "php-fpm-${mm}" || true)"
  [[ -n "${candidate}" ]] && {
    printf '%s\n' "${candidate}"
    return 0
  }

  candidate="$(plume_php_candidate_from_search_path "php-fpm${mm//./}" || true)"
  [[ -n "${candidate}" ]] && {
    printf '%s\n' "${candidate}"
    return 0
  }

  candidate="$(plume_php_candidate_from_path "php-fpm-${mm}" || true)"
  [[ -n "${candidate}" ]] && {
    printf '%s\n' "${candidate}"
    return 0
  }

  candidate="$(plume_php_candidate_from_path "php-fpm${mm//./}" || true)"
  [[ -n "${candidate}" ]] && {
    printf '%s\n' "${candidate}"
    return 0
  }

  candidate="/opt/homebrew/opt/php@${mm}/sbin/php-fpm"
  [[ -x "${candidate}" ]] && {
    printf '%s\n' "${candidate}"
    return 0
  }

  candidate="/usr/local/opt/php@${mm}/sbin/php-fpm"
  [[ -x "${candidate}" ]] && {
    printf '%s\n' "${candidate}"
    return 0
  }

  return 1
}

plume_php_shim_dir() {
  printf '%s' "${PLUME_PHP_SHIM_DIR:-$HOME/.config/plume/shims}"
}

plume_php_extensions_strict() {
  plume_bool "${PLUME_PHP_EXTENSIONS_STRICT:-true}"
}

plume_php_extensions_csv_minus() {
  local base_csv="${1:-}"
  local remove_csv="${2:-}"
  local out="" item
  base_csv="$(plume_php_extensions_csv_normalize "${base_csv}")"
  remove_csv="$(plume_php_extensions_csv_normalize "${remove_csv}")"
  [[ -n "${base_csv}" ]] || {
    printf '%s\n' ""
    return 0
  }
  IFS=',' read -r -a _minus_base <<< "${base_csv}"
  for item in "${_minus_base[@]}"; do
    [[ -n "${item}" ]] || continue
    if [[ -n "${remove_csv}" && ",${remove_csv}," == *",${item},"* ]]; then
      continue
    fi
    if [[ -n "${out}" ]]; then
      out="${out},${item}"
    else
      out="${item}"
    fi
  done
  printf '%s\n' "${out}"
}

plume_php_extensions_key_for_version() {
  local version="${1:-}"
  local mm compact
  mm="$(plume_php_version_major_minor "${version}" || true)"
  [[ -n "${mm}" ]] || return 1
  compact="$(printf '%s' "${mm}" | tr -d '.')"
  printf 'PLUME_PHP_EXTENSIONS_%s' "${compact}"
}

plume_php_extensions_preset_key_for_version() {
  local version="${1:-}"
  local mm compact
  mm="$(plume_php_version_major_minor "${version}" || true)"
  [[ -n "${mm}" ]] || return 1
  compact="$(printf '%s' "${mm}" | tr -d '.')"
  printf 'PLUME_PHP_EXT_PRESET_%s' "${compact}"
}

plume_php_extension_name_normalize() {
  local raw="${1:-}"
  local ext
  ext="$(printf '%s' "${raw}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  [[ -n "${ext}" ]] || return 1
  if ! printf '%s' "${ext}" | grep -Eq '^[a-z0-9_+-]+$'; then
    return 1
  fi
  printf '%s\n' "${ext}"
}

plume_php_extensions_csv_normalize() {
  local input="${1:-}"
  local out="" item norm
  local list
  list="$(printf '%s' "${input}" | tr ',' ' ')"
  for item in ${list}; do
    norm="$(plume_php_extension_name_normalize "${item}" || true)"
    [[ -n "${norm}" ]] || continue
    if [[ ",${out}," == *",${norm},"* ]]; then
      continue
    fi
    if [[ -n "${out}" ]]; then
      out="${out},${norm}"
    else
      out="${norm}"
    fi
  done
  printf '%s\n' "${out}"
}

plume_php_extensions_preset_csv() {
  local preset="${1:-none}"
  preset="$(printf '%s' "${preset}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  case "${preset}" in
    ""|none|off|false)
      printf '%s\n' ""
      ;;
    laravel-core|laravel|core)
      # Core Laravel runtime extensions.
      printf '%s\n' "bcmath,ctype,curl,dom,fileinfo,mbstring,openssl,pdo,pdo_mysql,tokenizer,xml,redis,opcache"
      ;;
    queue)
      printf '%s\n' "bcmath,ctype,curl,dom,fileinfo,mbstring,openssl,pdo,pdo_mysql,tokenizer,xml,redis,opcache,pcntl,posix"
      ;;
    media)
      printf '%s\n' "bcmath,ctype,curl,dom,fileinfo,mbstring,openssl,pdo,pdo_mysql,tokenizer,xml,redis,opcache,exif,gd,imagick"
      ;;
    full)
      printf '%s\n' "bcmath,ctype,curl,dom,fileinfo,mbstring,openssl,pdo,pdo_mysql,tokenizer,xml,redis,opcache,pcntl,posix,exif,gd,imagick,intl,zip,soap,sodium,xdebug"
      ;;
    *)
      plume_warn "unknown php extension preset: ${preset} (supported: none|laravel-core|queue|media|full)"
      printf '%s\n' ""
      ;;
  esac
}

plume_php_extensions_preset_for_version() {
  local version="${1:-}"
  local global_preset version_key version_preset merged_csv preset item csv
  global_preset="${PLUME_PHP_EXT_PRESET:-none}"
  version_key="$(plume_php_extensions_preset_key_for_version "${version}" || true)"
  version_preset=""
  if [[ -n "${version_key}" ]]; then
    version_preset="${!version_key:-}"
  fi
  merged_csv=""
  for preset in ${global_preset//,/ } ${version_preset//,/ }; do
    preset="$(printf '%s' "${preset}" | sed 's/^ *//;s/ *$//')"
    [[ -n "${preset}" ]] || continue
    csv="$(plume_php_extensions_preset_csv "${preset}")"
    if [[ -n "${csv}" ]]; then
      if [[ -n "${merged_csv}" ]]; then
        merged_csv="${merged_csv},${csv}"
      else
        merged_csv="${csv}"
      fi
    fi
  done
  plume_php_extensions_csv_normalize "${merged_csv}"
}

plume_php_extensions_toggles_for_version() {
  local version="${1:-}"
  local mode="${2:-enable}"
  local mm compact prefix key value ext_raw ext norm out=""
  mm="$(plume_php_version_major_minor "${version}" || true)"
  [[ -n "${mm}" ]] || return 1
  compact="$(printf '%s' "${mm}" | tr -d '.')"
  mode="$(printf '%s' "${mode}" | tr '[:lower:]' '[:upper:]')"
  case "${mode}" in
    ENABLE|DISABLE) ;;
    *) return 1 ;;
  esac
  prefix="PLUME_PHP_EXT_${mode}_"
  while IFS='=' read -r key value; do
    [[ -n "${key}" ]] || continue
    [[ "${key}" == ${prefix}* ]] || continue
    if ! plume_bool "${value:-false}" >/dev/null 2>&1; then
      continue
    fi
    if [[ "$(plume_bool "${value}")" != "true" ]]; then
      continue
    fi
    ext_raw="${key#${prefix}}"
    if [[ "${ext_raw}" =~ ^([0-9]{2})_(.+)$ ]]; then
      if [[ "${BASH_REMATCH[1]}" != "${compact}" ]]; then
        continue
      fi
      ext_raw="${BASH_REMATCH[2]}"
    fi
    ext="$(printf '%s' "${ext_raw}" | tr '[:upper:]' '[:lower:]')"
    norm="$(plume_php_extension_name_normalize "${ext}" || true)"
    [[ -n "${norm}" ]] || continue
    if [[ ",${out}," == *",${norm},"* ]]; then
      continue
    fi
    if [[ -n "${out}" ]]; then
      out="${out},${norm}"
    else
      out="${norm}"
    fi
  done < <(env)
  printf '%s\n' "${out}"
}

plume_php_extensions_for_version() {
  local version="${1:-}"
  local preset_csv global_csv version_key version_csv toggles_enable toggles_disable merged
  preset_csv="$(plume_php_extensions_preset_for_version "${version}")"
  global_csv="$(plume_php_extensions_csv_normalize "${PLUME_PHP_EXTENSIONS_GLOBAL:-}")"
  version_key="$(plume_php_extensions_key_for_version "${version}" || true)"
  version_csv=""
  if [[ -n "${version_key}" ]]; then
    version_csv="$(plume_php_extensions_csv_normalize "${!version_key:-}")"
  fi
  toggles_enable="$(plume_php_extensions_toggles_for_version "${version}" "enable" || true)"
  toggles_disable="$(plume_php_extensions_toggles_for_version "${version}" "disable" || true)"
  merged="${preset_csv}"
  if [[ -n "${global_csv}" ]]; then
    if [[ -n "${merged}" ]]; then
      merged="${merged},${global_csv}"
    else
      merged="${global_csv}"
    fi
  fi
  if [[ -n "${version_csv}" ]]; then
    if [[ -n "${merged}" ]]; then
      merged="${merged},${version_csv}"
    else
      merged="${version_csv}"
    fi
  fi
  if [[ -n "${toggles_enable}" ]]; then
    if [[ -n "${merged}" ]]; then
      merged="${merged},${toggles_enable}"
    else
      merged="${toggles_enable}"
    fi
  fi
  merged="$(plume_php_extensions_csv_normalize "${merged}")"
  merged="$(plume_php_extensions_csv_minus "${merged}" "${toggles_disable}")"
  plume_php_extensions_csv_normalize "${merged}"
}

plume_php_extension_verify_for_version() {
  local version="${1:-}"
  local ext="${2:-}"
  local php_bin
  php_bin="$(plume_php_find_cli_bin "${version}" || true)"
  [[ -n "${php_bin}" ]] || return 1
  "${php_bin}" -m 2>/dev/null | awk '{print tolower($0)}' | grep -qx "${ext}"
}

plume_php_extension_brew_required_packages() {
  local ext="${1:-}"
  local packages="pkgconf autoconf"
  case "${ext}" in
    imagick)
      packages="${packages} imagemagick"
      ;;
  esac
  printf '%s\n' "${packages}"
}

plume_php_extension_brew_ensure_packages() {
  local packages="${1:-}"
  local pkg
  for pkg in ${packages}; do
    [[ -n "${pkg}" ]] || continue
    if HOMEBREW_NO_AUTO_UPDATE=1 brew list --formula "${pkg}" >/dev/null 2>&1; then
      continue
    fi
    plume_info "installing brew prerequisite for php extensions: ${pkg}"
    HOMEBREW_NO_AUTO_UPDATE=1 brew install "${pkg}" || {
      plume_warn "failed to install brew prerequisite: ${pkg}"
      return 2
    }
  done
}

plume_php_extension_install_for_version() {
  local version="${1:-}"
  local ext="${2:-}"
  local driver mm pkg
  mm="$(plume_php_version_major_minor "${version}" || true)"
  [[ -n "${mm}" ]] || return 2
  driver="${PLUME_PHP_EXT_INSTALL_DRIVER:-$(plume_detect_package_manager)}"

  case "${driver}" in
    mock)
      plume_info "php extension install mock: php=${version} ext=${ext}"
      return 0
      ;;
    apt)
      pkg="php${mm}-${ext}"
      plume_info "installing php extension via apt: ${pkg}"
      apt update -y >/dev/null 2>&1 || return 2
      apt install -y "${pkg}" || return 2
      ;;
    brew)
      if plume_is_root; then
        plume_err "brew extension installs must run as normal user, not root"
        return 2
      fi
      local php_bin pecl_bin phpize_bin php_ini_scan_dir ini_file brew_pkgs
      local pecl_path pecl_pkg_config_path pkgconf_prefix imagick_prefix
      brew_pkgs="$(plume_php_extension_brew_required_packages "${ext}")"
      plume_php_extension_brew_ensure_packages "${brew_pkgs}" || return 2
      php_bin="$(plume_php_find_cli_bin "${version}" || true)"
      if [[ -z "${php_bin}" ]]; then
        plume_err "php ${version} cli binary not found for brew extension install"
        return 2
      fi
      phpize_bin="$(dirname "${php_bin}")/phpize"
      if [[ ! -x "${phpize_bin}" ]]; then
        plume_err "phpize not found for php ${version}; install php@${mm} developer tools first"
        return 2
      fi
      pecl_bin="$(dirname "${php_bin}")/pecl"
      if [[ ! -x "${pecl_bin}" ]]; then
        pecl_bin="$(command -v pecl 2>/dev/null || true)"
      fi
      if [[ -z "${pecl_bin}" || ! -x "${pecl_bin}" ]]; then
        plume_err "pecl not found for php ${version}; install php@${mm} first"
        return 2
      fi

      pecl_path="${PATH:-}"
      pecl_pkg_config_path="${PKG_CONFIG_PATH:-}"
      if ! command -v pkg-config >/dev/null 2>&1; then
        pkgconf_prefix="$(brew --prefix pkgconf 2>/dev/null || true)"
        if [[ -n "${pkgconf_prefix}" && -x "${pkgconf_prefix}/bin/pkg-config" ]]; then
          pecl_path="${pkgconf_prefix}/bin:${pecl_path}"
        fi
      fi
      if [[ "${ext}" == "imagick" ]]; then
        imagick_prefix="$(brew --prefix imagemagick 2>/dev/null || true)"
        if [[ -n "${imagick_prefix}" && -d "${imagick_prefix}/lib/pkgconfig" ]]; then
          if [[ -n "${pecl_pkg_config_path}" ]]; then
            pecl_pkg_config_path="${imagick_prefix}/lib/pkgconfig:${pecl_pkg_config_path}"
          else
            pecl_pkg_config_path="${imagick_prefix}/lib/pkgconfig"
          fi
        fi
      fi

      plume_info "installing php extension via pecl (brew/php@${mm}): ${ext}"
      # Prefer non-interactive pecl install.
      if ! printf "\n" | PATH="${pecl_path}" PKG_CONFIG_PATH="${pecl_pkg_config_path}" PHP_PEAR_PHP_BIN="${php_bin}" "${pecl_bin}" install -f "${ext}"; then
        plume_warn "pecl install failed for php=${version} ext=${ext}; manual install may be required"
        return 2
      fi

      php_ini_scan_dir="$("${php_bin}" --ini 2>/dev/null | awk -F': ' '/Scan for additional .ini files in:/ {print $2; exit}')"
      if [[ -z "${php_ini_scan_dir}" || ! -d "${php_ini_scan_dir}" ]]; then
        php_ini_scan_dir="$(dirname "${php_bin}")/../etc/php/${mm}/conf.d"
      fi
      mkdir -p "${php_ini_scan_dir}"
      ini_file="${php_ini_scan_dir}/50-plume-${ext}.ini"
      printf 'extension=%s.so\n' "${ext}" > "${ini_file}"
      plume_info "php extension ini written: ${ini_file}"
      ;;
    *)
      plume_err "unsupported php extension install driver: ${driver}"
      return 2
      ;;
  esac
}

plume_php_extensions_sync_version() {
  local version="${1:-}"
  local strict="${2:-$(plume_php_extensions_strict)}"
  local csv ext
  version="$(plume_php_version_normalize "${version}")" || return 2
  csv="$(plume_php_extensions_for_version "${version}")"
  [[ -n "${csv}" ]] || return 0

  local failed="0"
  IFS=',' read -r -a _ext_items <<< "${csv}"
  for ext in "${_ext_items[@]}"; do
    [[ -n "${ext}" ]] || continue
    if plume_php_extension_verify_for_version "${version}" "${ext}"; then
      plume_info "php extension ready: php=${version} ext=${ext}"
      continue
    fi
    plume_info "php extension missing: php=${version} ext=${ext} -> install"
    plume_php_extension_install_for_version "${version}" "${ext}" || failed="1"
    if ! plume_php_extension_verify_for_version "${version}" "${ext}"; then
      plume_warn "php extension still missing after install attempt: php=${version} ext=${ext}"
      failed="1"
    fi
  done

  if [[ "${failed}" == "1" && "${strict}" == "true" ]]; then
    return 2
  fi
  return 0
}

plume_php_extensions_sync_all() {
  local strict="${1:-$(plume_php_extensions_strict)}"
  local versions_csv default_v merged seen="" version
  default_v="$(plume_php_version_normalize "${PLUME_PHP_DEFAULT_VERSION:-${PLUME_PHP_VERSION:-8.3}}")" || return 2
  versions_csv="$(plume_php_versions_csv_normalize "${PLUME_PHP_INSTALLED_VERSIONS:-${default_v}}")" || return 2
  merged="${versions_csv},${default_v}"
  IFS=',' read -r -a _vers_items <<< "${merged}"
  for version in "${_vers_items[@]}"; do
    version="$(printf '%s' "${version}" | sed 's/^ *//;s/ *$//')"
    [[ -n "${version}" ]] || continue
    if [[ ",${seen}," == *",${version},"* ]]; then
      continue
    fi
    seen="${seen},${version}"
    plume_php_extensions_sync_version "${version}" "${strict}" || return 2
  done
}

plume_php_shell_alias_export() {
  local versions_csv default_v version mm compact
  versions_csv="$(plume_php_versions_csv_normalize "${PLUME_PHP_INSTALLED_VERSIONS}")" || return 2
  default_v="$(plume_php_version_normalize "${PLUME_PHP_DEFAULT_VERSION:-${PLUME_PHP_VERSION:-8.3}}")" || return 2

  printf '# plume php version aliases (non-default versions)\n'
  IFS=',' read -r -a _alias_versions <<< "${versions_csv}"
  for version in "${_alias_versions[@]}"; do
    version="$(printf '%s' "${version}" | sed 's/^ *//;s/ *$//')"
    [[ -n "${version}" ]] || continue
    if [[ "${version}" == "${default_v}" ]]; then
      continue
    fi
    mm="$(plume_php_version_major_minor "${version}" || true)"
    [[ -n "${mm}" ]] || continue
    compact="$(printf '%s' "${mm}" | tr -d '.')"
    printf "alias php%s='php%s'\n" "${compact}" "${mm}"
    printf "alias phpfpm%s='php-fpm-%s'\n" "${compact}" "${mm}"
  done
}

plume_php_shim_exec_plume() {
  if command -v plumectl >/dev/null 2>&1; then
    printf '%s\n' "plumectl"
    return 0
  fi
  local root_dir
  root_dir="${ROOT_DIR:-}"
  if [[ -n "${root_dir}" && -x "${root_dir}/plume.sh" ]]; then
    printf '%s\n' "${root_dir}/plume.sh"
    return 0
  fi
  if [[ -x "./plume.sh" ]]; then
    printf '%s\n' "./plume.sh"
    return 0
  fi
  return 1
}

plume_php_write_shim_file() {
  local target_file="${1:-}"
  local type="${2:-cli}"
  local version="${3:-}"
  local plume_exec
  plume_exec="$(plume_php_shim_exec_plume)" || {
    plume_err "plume executable not found for shim generation (needs plumectl or ./plume.sh)"
    return 2
  }
  cat > "${target_file}" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec "${plume_exec}" php shim run --type=${type} --version=${version} -- "\$@"
EOF
  chmod +x "${target_file}"
}

plume_php_write_state() {
  mkdir -p "$(plume_state_dir)"
  local file
  file="$(plume_php_state_file)"

  local normalized_installed
  normalized_installed="$(plume_php_versions_csv_normalize "${PLUME_PHP_INSTALLED_VERSIONS}")" || return 2
  PLUME_PHP_INSTALLED_VERSIONS="${normalized_installed}"

  local default_v
  default_v="$(plume_php_version_normalize "${PLUME_PHP_DEFAULT_VERSION:-${PLUME_PHP_VERSION:-8.3}}")" || return 2
  if ! plume_php_csv_has_version "${PLUME_PHP_INSTALLED_VERSIONS}" "${default_v}"; then
    PLUME_PHP_INSTALLED_VERSIONS="$(plume_php_versions_csv_normalize "${PLUME_PHP_INSTALLED_VERSIONS},${default_v}")" || return 2
  fi
  PLUME_PHP_DEFAULT_VERSION="${default_v}"
  PLUME_PHP_VERSION="${default_v}"
  : "${PLUME_PHP_DEFAULT_ALIAS:=php}"

  {
    printf 'PLUME_PHP_VERSION=%s\n' "${PLUME_PHP_VERSION}"
    printf 'PLUME_PHP_DEFAULT_VERSION=%s\n' "${PLUME_PHP_DEFAULT_VERSION}"
    printf 'PLUME_PHP_DEFAULT_ALIAS=%s\n' "${PLUME_PHP_DEFAULT_ALIAS}"
    printf 'PLUME_PHP_INSTALLED_VERSIONS=%s\n' "${PLUME_PHP_INSTALLED_VERSIONS}"
    local key
    while IFS= read -r key; do
      [[ -z "${key}" ]] && continue
      printf '%s=%s\n' "${key}" "${!key}"
    done < <(env | awk -F= '/^PLUME_PHP_ALIAS_[A-Z0-9_]+=/ { print $1 }' | sort)
  } > "${file}"
}

cmd_php_list() {
  local installed default_v
  installed="$(plume_php_versions_csv_normalize "${PLUME_PHP_INSTALLED_VERSIONS}")" || return 2
  default_v="$(plume_php_version_normalize "${PLUME_PHP_DEFAULT_VERSION:-${PLUME_PHP_VERSION:-8.3}}")" || return 2
  if [[ "${PLUME_OUTPUT:-text}" == "json" ]]; then
    local json_items="" item
    local list
    list="$(printf '%s' "${installed}" | tr ',' ' ')"
    for item in ${list}; do
      if [[ -n "${json_items}" ]]; then
        json_items="${json_items},\"${item}\""
      else
        json_items="\"${item}\""
      fi
    done
    printf '{"ok":true,"command":"php list","data":{"default":"%s","installed":[%s]},"warnings":[],"errors":[]}\n' \
      "${default_v}" "${json_items}"
    return 0
  fi
  printf 'DEFAULT           %s\n' "${default_v}"
  printf 'INSTALLED         %s\n' "${installed}"
}

cmd_php_install() {
  local version="${1:-}"
  if [[ -z "${version}" ]]; then
    plume_err "usage: php install <version>"
    return 2
  fi
  plume_php_register_installed_version "${version}" || return 2
  plume_info "php version installed in native matrix: ${version}"
}

plume_php_register_installed_version() {
  local version="${1:-}"
  if [[ -z "${version}" ]]; then
    plume_err "php register requires version"
    return 2
  fi
  version="$(plume_php_version_normalize "${version}")" || return 2

  local installed
  installed="$(plume_php_versions_csv_normalize "${PLUME_PHP_INSTALLED_VERSIONS}")" || return 2
  if ! plume_php_csv_has_version "${installed}" "${version}"; then
    installed="$(plume_php_versions_csv_normalize "${installed},${version}")" || return 2
  fi
  PLUME_PHP_INSTALLED_VERSIONS="${installed}"

  # Auto-create a canonical alias (php84 -> 8.4) unless already set.
  local auto_alias auto_key
  auto_alias="$(plume_php_alias_name_for_version "${version}")"
  auto_key="$(plume_php_alias_key_for_name "${auto_alias}")" || return 2
  if [[ -z "${!auto_key:-}" ]]; then
    export "${auto_key}=${version}"
  fi

  plume_php_write_state || return 2
}

cmd_php_use() {
  local version="${1:-}"
  if [[ -z "${version}" ]]; then
    plume_err "usage: php use <version|alias|default>"
    return 2
  fi
  local resolved installed
  resolved="$(plume_service_resolve_php_alias "${version}")"
  resolved="$(plume_php_version_normalize "${resolved}")" || return 2
  installed="$(plume_php_versions_csv_normalize "${PLUME_PHP_INSTALLED_VERSIONS}")" || return 2
  if ! plume_php_csv_has_version "${installed}" "${resolved}"; then
    installed="$(plume_php_versions_csv_normalize "${installed},${resolved}")" || return 2
    PLUME_PHP_INSTALLED_VERSIONS="${installed}"
  fi

  PLUME_PHP_DEFAULT_VERSION="${resolved}"
  PLUME_PHP_VERSION="${resolved}"
  plume_php_write_state || return 2
  plume_info "native default php version set to ${resolved}"
}

cmd_php_alias_list() {
  if [[ "${PLUME_OUTPUT:-text}" == "json" ]]; then
    local json="" key name
    while IFS= read -r key; do
      [[ -z "${key}" ]] && continue
      name="${key#PLUME_PHP_ALIAS_}"
      name="$(printf '%s' "${name}" | tr '[:upper:]' '[:lower:]')"
      if [[ -n "${json}" ]]; then
        json="${json},"
      fi
      json="${json}\"${name}\":\"${!key}\""
    done < <(env | awk -F= '/^PLUME_PHP_ALIAS_[A-Z0-9_]+=/ { print $1 }' | sort)
    printf '{"ok":true,"command":"php alias list","data":{"aliases":{%s}},"warnings":[],"errors":[]}\n' "${json}"
    return 0
  fi
  printf '%-18s %s\n' "ALIAS" "VERSION"
  printf '%-18s %s\n' "------------------" "--------"
  local key name
  while IFS= read -r key; do
    [[ -z "${key}" ]] && continue
    name="${key#PLUME_PHP_ALIAS_}"
    name="$(printf '%s' "${name}" | tr '[:upper:]' '[:lower:]')"
    printf '%-18s %s\n' "${name}" "${!key}"
  done < <(env | awk -F= '/^PLUME_PHP_ALIAS_[A-Z0-9_]+=/ { print $1 }' | sort)
}

cmd_php_alias_set() {
  local alias_name="${1:-}"
  local version="${2:-}"
  if [[ -z "${alias_name}" || -z "${version}" ]]; then
    plume_err "usage: php alias set <name> <version>"
    return 2
  fi
  local resolved
  resolved="$(plume_service_resolve_php_alias "${version}")"
  resolved="$(plume_php_version_normalize "${resolved}")" || return 2

  local installed
  installed="$(plume_php_versions_csv_normalize "${PLUME_PHP_INSTALLED_VERSIONS}")" || return 2
  if ! plume_php_csv_has_version "${installed}" "${resolved}"; then
    installed="$(plume_php_versions_csv_normalize "${installed},${resolved}")" || return 2
    PLUME_PHP_INSTALLED_VERSIONS="${installed}"
  fi

  local alias_key
  alias_key="$(plume_php_alias_key_for_name "${alias_name}")" || return 2
  export "${alias_key}=${resolved}"
  plume_php_write_state || return 2
  plume_info "php alias set: ${alias_name} -> ${resolved}"
}

cmd_php_alias_default() {
  local version="${1:-}"
  if [[ -z "${version}" ]]; then
    plume_err "usage: php alias default <version|alias>"
    return 2
  fi
  cmd_php_use "${version}"
}

cmd_php_ext_sync() {
  local target="${1:-all}"
  local strict
  strict="$(plume_php_extensions_strict)"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --strict) strict="true" ;;
      --no-strict) strict="false" ;;
      all) target="all" ;;
      --all) target="all" ;;
      --*) ;;
      *)
        if [[ "${arg}" != "${target}" ]]; then
          target="${arg}"
        fi
        ;;
    esac
  done
  if [[ "${target}" == "all" ]]; then
    plume_php_extensions_sync_all "${strict}" || return 2
  else
    plume_php_extensions_sync_version "${target}" "${strict}" || return 2
  fi
}

cmd_php_ext_doctor() {
  local strict="false"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --strict) strict="true" ;;
      --no-strict) strict="false" ;;
      *) ;;
    esac
  done

  local versions_csv default_v merged seen="" version csv ext status failed="0"
  default_v="$(plume_php_version_normalize "${PLUME_PHP_DEFAULT_VERSION:-${PLUME_PHP_VERSION:-8.3}}")" || return 2
  versions_csv="$(plume_php_versions_csv_normalize "${PLUME_PHP_INSTALLED_VERSIONS:-${default_v}}")" || return 2
  merged="${versions_csv},${default_v}"

  printf 'STRICT            %s\n' "${strict}"
  printf 'DEFAULT           %s\n' "${default_v}"
  echo "PHP      EXTENSION  STATUS"
  echo "-------- ---------- --------"
  IFS=',' read -r -a _doctor_vers <<< "${merged}"
  for version in "${_doctor_vers[@]}"; do
    version="$(printf '%s' "${version}" | sed 's/^ *//;s/ *$//')"
    [[ -n "${version}" ]] || continue
    if [[ ",${seen}," == *",${version},"* ]]; then
      continue
    fi
    seen="${seen},${version}"
    csv="$(plume_php_extensions_for_version "${version}")"
    [[ -n "${csv}" ]] || continue
    IFS=',' read -r -a _doctor_exts <<< "${csv}"
    for ext in "${_doctor_exts[@]}"; do
      [[ -n "${ext}" ]] || continue
      status="missing"
      if plume_php_extension_verify_for_version "${version}" "${ext}"; then
        status="ok"
      else
        failed="1"
      fi
      printf '%-8s %-10s %s\n' "${version}" "${ext}" "${status}"
    done
  done
  if [[ "${strict}" == "true" && "${failed}" == "1" ]]; then
    return 2
  fi
}

cmd_php_ext_resolve() {
  local target="${1:-all}"
  local versions_csv default_v merged seen="" version csv
  if [[ "${target}" == "all" || "${target}" == "--all" ]]; then
    default_v="$(plume_php_version_normalize "${PLUME_PHP_DEFAULT_VERSION:-${PLUME_PHP_VERSION:-8.3}}")" || return 2
    versions_csv="$(plume_php_versions_csv_normalize "${PLUME_PHP_INSTALLED_VERSIONS:-${default_v}}")" || return 2
    merged="${versions_csv},${default_v}"
  else
    version="$(plume_service_resolve_php_alias "${target}")"
    version="$(plume_php_version_normalize "${version}")" || return 2
    merged="${version}"
  fi

  if [[ "${PLUME_OUTPUT:-text}" == "json" ]]; then
    local first="true"
    printf '{"ok":true,"command":"php ext resolve","data":{"rows":['
    IFS=',' read -r -a _resolve_versions_json <<< "${merged}"
    for version in "${_resolve_versions_json[@]}"; do
      version="$(printf '%s' "${version}" | sed 's/^ *//;s/ *$//')"
      [[ -n "${version}" ]] || continue
      if [[ ",${seen}," == *",${version},"* ]]; then
        continue
      fi
      seen="${seen},${version}"
      csv="$(plume_php_extensions_for_version "${version}")"
      if [[ "${first}" == "true" ]]; then
        first="false"
      else
        printf ','
      fi
      printf '{"php":"%s","resolved":"%s"}' "${version}" "${csv}"
    done
    printf ']},"warnings":[],"errors":[]}\n'
    return 0
  fi

  printf 'PRESET            %s\n' "${PLUME_PHP_EXT_PRESET:-none}"
  printf 'GLOBAL            %s\n' "$(plume_php_extensions_csv_normalize "${PLUME_PHP_EXTENSIONS_GLOBAL:-}")"
  printf 'PHP      RESOLVED\n'
  printf '%-8s %s\n' '--------' '------------------------------------------------------------'
  IFS=',' read -r -a _resolve_versions <<< "${merged}"
  for version in "${_resolve_versions[@]}"; do
    version="$(printf '%s' "${version}" | sed 's/^ *//;s/ *$//')"
    [[ -n "${version}" ]] || continue
    if [[ ",${seen}," == *",${version},"* ]]; then
      continue
    fi
    seen="${seen},${version}"
    csv="$(plume_php_extensions_for_version "${version}")"
    printf '%-8s %s\n' "${version}" "${csv}"
  done
}

cmd_php_shim_env() {
  local dir
  dir="$(plume_php_shim_dir)"
  printf 'export PATH="%s:$PATH"\n' "${dir}"
  plume_php_shell_alias_export
}

cmd_php_shim_install() {
  local dir
  dir="$(plume_php_shim_dir)"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --dir=*) dir="${arg#*=}" ;;
    esac
  done
  mkdir -p "${dir}"

  local versions_csv version compact
  versions_csv="$(plume_php_versions_csv_normalize "${PLUME_PHP_INSTALLED_VERSIONS}")" || return 2
  IFS=',' read -r -a _shim_versions <<< "${versions_csv}"
  for version in "${_shim_versions[@]}"; do
    version="$(printf '%s' "${version}" | sed 's/^ *//;s/ *$//')"
    [[ -n "${version}" ]] || continue
    compact="$(printf '%s' "${version}" | tr -d '.')"
    plume_php_write_shim_file "${dir}/php${version}" "cli" "${version}" || return 2
    plume_php_write_shim_file "${dir}/php${compact}" "cli" "${version}" || return 2
    plume_php_write_shim_file "${dir}/php-fpm-${version}" "fpm" "${version}" || return 2
    plume_php_write_shim_file "${dir}/php-fpm${compact}" "fpm" "${version}" || return 2
  done
  plume_info "php shims installed: ${dir}"
  plume_info "activate with: eval \"\$($(plume_php_shim_exec_plume) php shim env)\""
}

cmd_php_shim_list() {
  local dir
  dir="$(plume_php_shim_dir)"
  if [[ ! -d "${dir}" ]]; then
    return 0
  fi
  if [[ "${PLUME_OUTPUT:-text}" == "json" ]]; then
    local first="true"
    printf '{"ok":true,"command":"php shim list","data":{"dir":"%s","files":[' "${dir}"
    local file base
    while IFS= read -r file; do
      [[ -n "${file}" ]] || continue
      base="$(basename "${file}")"
      if [[ "${first}" == "true" ]]; then
        first="false"
      else
        printf ','
      fi
      printf '"%s"' "${base}"
    done < <(find "${dir}" -maxdepth 1 -type f -perm -u+x | sort)
    printf ']},"warnings":[],"errors":[]}\n'
    return 0
  fi
  printf 'DIR               %s\n' "${dir}"
  printf 'FILES\n'
  printf '%s\n' '------------------------------'
  find "${dir}" -maxdepth 1 -type f -perm -u+x -exec basename {} \; | sort
}

cmd_php_shim_remove() {
  local dir
  dir="$(plume_php_shim_dir)"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --dir=*) dir="${arg#*=}" ;;
    esac
  done
  if [[ -d "${dir}" ]]; then
    rm -f "${dir}"/php* "${dir}"/php-fpm*
  fi
  plume_info "php shims removed: ${dir}"
}

cmd_php_shim_run() {
  local type="cli"
  local version=""
  local arg
  while (($#)); do
    arg="$1"
    shift
    case "${arg}" in
      --type=*) type="${arg#*=}" ;;
      --version=*) version="${arg#*=}" ;;
      --) break ;;
      *)
        plume_err "unknown php shim run option: ${arg}"
        return 2
        ;;
    esac
  done
  if [[ -z "${version}" ]]; then
    plume_err "php shim run requires --version"
    return 2
  fi
  version="$(plume_service_resolve_php_alias "${version}")"
  version="$(plume_php_version_normalize "${version}")" || return 2

  local bin=""
  case "${type}" in
    cli) bin="$(plume_php_find_cli_bin "${version}" || true)" ;;
    fpm) bin="$(plume_php_find_fpm_bin "${version}" || true)" ;;
    *)
      plume_err "unsupported php shim type: ${type} (use cli|fpm)"
      return 2
      ;;
  esac
  if [[ -z "${bin}" ]]; then
    plume_err "${type} binary for PHP ${version} not found on host"
    return 2
  fi
  exec "${bin}" "$@"
}

cmd_php() {
  local sub="${1:-list}"
  shift || true
  case "${sub}" in
    list)
      cmd_php_list "$@"
      ;;
    install)
      cmd_php_install "$@"
      ;;
    use)
      cmd_php_use "$@"
      ;;
    alias)
      local action="${1:-list}"
      shift || true
      case "${action}" in
        list) cmd_php_alias_list "$@" ;;
        set) cmd_php_alias_set "$@" ;;
        default) cmd_php_alias_default "$@" ;;
        *)
          plume_err "unknown php alias action: ${action} (use list|set|default)"
          return 2
          ;;
      esac
      ;;
    ext)
      local action="${1:-sync}"
      shift || true
      case "${action}" in
        sync) cmd_php_ext_sync "$@" ;;
        doctor) cmd_php_ext_doctor "$@" ;;
        resolve) cmd_php_ext_resolve "$@" ;;
        *)
          plume_err "unknown php ext action: ${action} (use sync|doctor|resolve)"
          return 2
          ;;
      esac
      ;;
    shim)
      local action="${1:-list}"
      shift || true
      case "${action}" in
        env) cmd_php_shim_env "$@" ;;
        install) cmd_php_shim_install "$@" ;;
        list) cmd_php_shim_list "$@" ;;
        remove) cmd_php_shim_remove "$@" ;;
        run) cmd_php_shim_run "$@" ;;
        *)
          plume_err "unknown php shim action: ${action} (use env|install|list|remove|run)"
          return 2
          ;;
      esac
      ;;
    *)
      plume_err "unknown php subcommand: ${sub} (use list|install|use|alias|ext|shim)"
      return 2
      ;;
  esac
}
