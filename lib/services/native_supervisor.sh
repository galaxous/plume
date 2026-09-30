#!/usr/bin/env bash
set -euo pipefail

# Native supervisor — system-primary (D-149): brew services / systemd + conf.d drop-ins.
# Legacy Plume-owned supervisord (D-147) detected and migrated via upgrade --force.

PLUME_SUPERVISOR_CONFIG_SCHEMA="${PLUME_SUPERVISOR_CONFIG_SCHEMA:-1}"

plume_native_supervisor_legacy_dir() {
  printf '%s/native/supervisor' "$(plume_state_dir)"
}

plume_native_supervisor_legacy_programs_dir() {
  printf '%s/programs' "$(plume_native_supervisor_legacy_dir)"
}

plume_native_supervisor_registry_file() {
  printf '%s/native/supervisor/programs-registry.env' "$(plume_state_dir)"
}

plume_native_supervisor_package_manager() {
  local pm
  pm="$(plume_host_profile_read_value package_manager 2>/dev/null || true)"
  if [[ -n "${pm}" && "${pm}" != "missing" && "${pm}" != "manual" ]]; then
    printf '%s' "${pm}"
    return 0
  fi
  plume_detect_package_manager
}

plume_native_supervisor_linux_id() {
  local id
  id="$(plume_host_profile_read_value os 2>/dev/null || true)"
  if [[ "${id}" == "linux" ]]; then
    plume_detect_linux_id
    return 0
  fi
  printf '%s' "${id:-unknown}"
}

plume_native_supervisor_systemd_unit_name() {
  local pm linux_id unit
  unit="$(plume_host_profile_read_value supervisor_systemd_unit 2>/dev/null || true)"
  if [[ -n "${unit}" ]]; then
    printf '%s' "${unit}"
    return 0
  fi
  pm="$(plume_native_supervisor_package_manager)"
  linux_id="$(plume_native_supervisor_linux_id)"
  case "${pm}" in
    apt) printf '%s' "supervisor" ;;
    dnf)
      if [[ "${linux_id}" == "fedora" || "${linux_id}" == "rhel" || "${linux_id}" == "centos" ]]; then
        printf '%s' "supervisord"
      else
        printf '%s' "supervisor"
      fi
      ;;
    *) printf '%s' "supervisor" ;;
  esac
}

plume_native_supervisor_brew_prefix() {
  if [[ -n "${PLUME_NATIVE_SUPERVISOR_BREW_PREFIX:-}" ]]; then
    printf '%s' "${PLUME_NATIVE_SUPERVISOR_BREW_PREFIX}"
    return 0
  fi
  if command -v brew >/dev/null 2>&1; then
    HOMEBREW_NO_AUTO_UPDATE=1 brew --prefix supervisor 2>/dev/null \
      || HOMEBREW_NO_AUTO_UPDATE=1 brew --prefix 2>/dev/null \
      || true
    return 0
  fi
  if [[ -d /opt/homebrew ]]; then
    printf '%s' "/opt/homebrew"
    return 0
  fi
  printf '%s' "/usr/local"
}

plume_native_supervisor_homebrew_cellar_prefix() {
  # Formula prefix (e.g. /opt/homebrew/opt/supervisor) — not always where brew services reads etc/
  plume_native_supervisor_brew_prefix
}

plume_native_supervisor_homebrew_etc_prefix() {
  if [[ -n "${PLUME_NATIVE_SUPERVISOR_HOMEBREW_PREFIX:-}" ]]; then
    printf '%s' "${PLUME_NATIVE_SUPERVISOR_HOMEBREW_PREFIX}"
    return 0
  fi
  if command -v brew >/dev/null 2>&1; then
    HOMEBREW_NO_AUTO_UPDATE=1 brew --prefix 2>/dev/null || true
    return 0
  fi
  if [[ -d /opt/homebrew ]]; then
    printf '%s' "/opt/homebrew"
    return 0
  fi
  printf '%s' "/usr/local"
}

plume_native_supervisor_include_files_line() {
  local main_conf="$1"
  [[ -n "${main_conf}" && -f "${main_conf}" ]] || return 1
  awk '
    BEGIN { in_include=0 }
    /^\[include\]/ { in_include=1; next }
    /^\[/ { in_include=0 }
    in_include && /^[[:space:]]*files[[:space:]]*=/ {
      sub(/^[[:space:]]*files[[:space:]]*=[[:space:]]*/, "")
      gsub(/[[:space:]]+$/, "")
      print
      exit
    }
  ' "${main_conf}"
}

plume_native_supervisor_program_ext() {
  local cached pm main_conf line first base
  if [[ -n "${PLUME_NATIVE_SUPERVISOR_PROGRAM_EXT:-}" ]]; then
    printf '%s' "${PLUME_NATIVE_SUPERVISOR_PROGRAM_EXT}"
    return 0
  fi
  cached="$(plume_host_profile_read_value supervisor_program_ext 2>/dev/null || true)"
  if [[ -n "${cached}" ]]; then
    printf '%s' "${cached}"
    return 0
  fi
  main_conf="$(plume_native_supervisor_main_conf_path 2>/dev/null || true)"
  if line="$(plume_native_supervisor_include_files_line "${main_conf}" 2>/dev/null)"; then
    first="${line%%[[:space:]]*}"
    base="$(basename "${first}")"
    case "${base}" in
      *.ini) printf '%s' "ini"; return 0 ;;
      *.conf) printf '%s' "conf"; return 0 ;;
    esac
  fi
  pm="$(plume_native_supervisor_package_manager)"
  case "${pm}" in
    brew) printf '%s' "ini" ;;
    *) printf '%s' "conf" ;;
  esac
}

plume_native_supervisor_main_conf_path() {
  local cached pm prefix etc_prefix
  if [[ -n "${PLUME_NATIVE_SUPERVISOR_MAIN_CONF:-}" ]]; then
    printf '%s' "${PLUME_NATIVE_SUPERVISOR_MAIN_CONF}"
    return 0
  fi
  cached="$(plume_host_profile_read_value supervisor_main_conf 2>/dev/null || true)"
  if [[ -n "${cached}" && -f "${cached}" ]]; then
    printf '%s' "${cached}"
    return 0
  fi
  pm="$(plume_native_supervisor_package_manager)"
  case "${pm}" in
    brew)
      etc_prefix="$(plume_native_supervisor_homebrew_etc_prefix)"
      if [[ -f "${etc_prefix}/etc/supervisord.conf" ]]; then
        printf '%s' "${etc_prefix}/etc/supervisord.conf"
        return 0
      fi
      prefix="$(plume_native_supervisor_homebrew_cellar_prefix)"
      if [[ -f "${prefix}/etc/supervisord.conf" ]]; then
        printf '%s' "${prefix}/etc/supervisord.conf"
        return 0
      fi
      ;;
    apt)
      if [[ -f /etc/supervisor/supervisord.conf ]]; then
        printf '%s' "/etc/supervisor/supervisord.conf"
        return 0
      fi
      ;;
    dnf)
      if [[ -f /etc/supervisord.conf ]]; then
        printf '%s' "/etc/supervisord.conf"
        return 0
      fi
      if [[ -f /etc/supervisor/supervisord.conf ]]; then
        printf '%s' "/etc/supervisor/supervisord.conf"
        return 0
      fi
      ;;
  esac
  printf '%s' ""
}

plume_native_supervisor_programs_dir_path() {
  local cached pm prefix etc_prefix main_conf line first dir
  if [[ -n "${PLUME_NATIVE_SUPERVISOR_PROGRAMS_DIR:-}" ]]; then
    printf '%s' "${PLUME_NATIVE_SUPERVISOR_PROGRAMS_DIR}"
    return 0
  fi

  main_conf="$(plume_native_supervisor_main_conf_path 2>/dev/null || true)"
  if line="$(plume_native_supervisor_include_files_line "${main_conf}" 2>/dev/null)"; then
    first="${line%%[[:space:]]*}"
    dir="$(dirname "${first}")"
    if [[ -n "${dir}" && "${dir}" != "." ]]; then
      printf '%s' "${dir}"
      return 0
    fi
  fi

  cached="$(plume_host_profile_read_value supervisor_programs_dir 2>/dev/null || true)"
  # Ignore stale brew cache pointing at formula opt/.../supervisor.d (not included by brew supervisord).
  if [[ -n "${cached}" ]]; then
    if [[ "${cached}" == *"/opt/supervisor/etc/supervisor.d" ]]; then
      cached=""
    elif [[ -d "${cached}" ]]; then
      printf '%s' "${cached}"
      return 0
    fi
  fi

  pm="$(plume_native_supervisor_package_manager)"
  case "${pm}" in
    brew)
      etc_prefix="$(plume_native_supervisor_homebrew_etc_prefix)"
      if [[ -d "${etc_prefix}/etc/supervisor.d" ]] || mkdir -p "${etc_prefix}/etc/supervisor.d" 2>/dev/null; then
        printf '%s' "${etc_prefix}/etc/supervisor.d"
        return 0
      fi
      prefix="$(plume_native_supervisor_homebrew_cellar_prefix)"
      printf '%s' "${prefix}/etc/supervisor.d"
      ;;
    apt) printf '%s' "/etc/supervisor/conf.d" ;;
    dnf)
      if [[ -d /etc/supervisord.d ]]; then
        printf '%s' "/etc/supervisord.d"
      else
        printf '%s' "/etc/supervisor/conf.d"
      fi
      ;;
    *)
      printf '%s' "$(plume_native_supervisor_legacy_programs_dir)"
      ;;
  esac
}

plume_native_supervisor_binary() {
  local bin cached
  cached="$(plume_host_profile_read_value supervisor_binary 2>/dev/null || true)"
  if [[ -n "${cached}" && -x "${cached}" ]]; then
    printf '%s' "${cached}"
    return 0
  fi
  bin="$(command -v supervisord 2>/dev/null || true)"
  printf '%s' "${bin}"
}

plume_native_supervisorctl_bin() {
  command -v supervisorctl 2>/dev/null || true
}

plume_native_supervisor_version_detect() {
  local bin out
  bin="$(plume_native_supervisor_binary)"
  [[ -n "${bin}" ]] || return 1
  out="$("${bin}" --version 2>/dev/null || true)"
  printf '%s' "${out}" | awk '{print $NF; exit}'
}

plume_native_supervisor_runtime_kind() {
  local pm
  if plume_native_supervisor_legacy_running; then
    printf '%s' "plume_legacy"
    return 0
  fi
  pm="$(plume_native_supervisor_package_manager)"
  case "${pm}" in
    brew) printf '%s' "brew" ;;
    apt|dnf) printf '%s' "systemd" ;;
    *) printf '%s' "unknown" ;;
  esac
}

plume_native_supervisor_conf() {
  plume_native_supervisor_main_conf_path
}

plume_native_supervisorctl() {
  local conf ctl
  conf="$(plume_native_supervisor_main_conf_path)"
  ctl="$(plume_native_supervisorctl_bin)"
  [[ -n "${ctl}" ]] || return 1
  if [[ -n "${conf}" && -f "${conf}" ]]; then
    supervisorctl -c "${conf}" "$@"
    return $?
  fi
  supervisorctl "$@"
}

plume_native_supervisor_legacy_running() {
  local pid_file pid
  pid_file="$(plume_native_pid_file supervisor 2>/dev/null || printf '%s/native-pids/supervisor.pid' "$(plume_state_dir)")"
  pid="$(cat "${pid_file}" 2>/dev/null || true)"
  [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null
}

plume_native_supervisor_system_unit_state() {
  local pm svc unit line
  pm="$(plume_native_supervisor_package_manager)"
  case "${pm}" in
    brew)
      svc="supervisor"
      if command -v brew >/dev/null 2>&1; then
        line="$(HOMEBREW_NO_AUTO_UPDATE=1 brew services list 2>/dev/null | awk -v s="${svc}" '$1==s {print $2; exit}' || true)"
        case "${line}" in
          started) printf '%s' "started" ;;
          stopped|"") printf '%s' "stopped" ;;
          *) printf '%s' "${line}" ;;
        esac
        return 0
      fi
      ;;
    apt|dnf)
      unit="$(plume_native_supervisor_systemd_unit_name)"
      if command -v systemctl >/dev/null 2>&1; then
        if systemctl is-active --quiet "${unit}.service" 2>/dev/null \
          || systemctl is-active --quiet "${unit}" 2>/dev/null; then
          printf '%s' "active"
          return 0
        fi
        printf '%s' "inactive"
        return 0
      fi
      ;;
  esac
  printf '%s' "unknown"
}

plume_native_supervisor_package_upgrade_available() {
  local pm
  if plume_native_driver_is_mock; then
    return 1
  fi
  pm="$(plume_native_supervisor_package_manager)"
  case "${pm}" in
    brew)
      if command -v brew >/dev/null 2>&1 && brew list supervisor >/dev/null 2>&1; then
        HOMEBREW_NO_AUTO_UPDATE=1 brew outdated supervisor >/dev/null 2>&1
        return $?
      fi
      ;;
    apt)
      if command -v apt-get >/dev/null 2>&1; then
        apt-get -s upgrade supervisor 2>/dev/null | grep -q '^Inst supervisor'
        return $?
      fi
      ;;
    dnf)
      if command -v dnf >/dev/null 2>&1; then
        dnf check-update supervisor >/dev/null 2>&1
        return $?
      fi
      ;;
  esac
  return 1
}

plume_host_profile_supervisor_persist() {
  local binary version runtime main_conf programs_dir schema upgrade_avail systemd_unit
  binary="$(plume_native_supervisor_binary)"
  version="$(plume_native_supervisor_version_detect 2>/dev/null || true)"
  runtime="$(plume_native_supervisor_runtime_kind)"
  main_conf="$(plume_native_supervisor_main_conf_path)"
  programs_dir="$(plume_native_supervisor_programs_dir_path)"
  schema="${PLUME_SUPERVISOR_CONFIG_SCHEMA}"
  systemd_unit="$(plume_native_supervisor_systemd_unit_name)"
  if plume_native_supervisor_package_upgrade_available; then
    upgrade_avail="true"
  else
    upgrade_avail="false"
  fi
  plume_host_profile_set_value supervisor_binary "${binary}"
  plume_host_profile_set_value supervisor_version "${version}"
  plume_host_profile_set_value supervisor_runtime "${runtime}"
  plume_host_profile_set_value supervisor_main_conf "${main_conf}"
  plume_host_profile_set_value supervisor_programs_dir "${programs_dir}"
  plume_host_profile_set_value supervisor_program_ext "$(plume_native_supervisor_program_ext)"
  plume_host_profile_set_value supervisor_config_schema "${schema}"
  plume_host_profile_set_value supervisor_upgrade_available "${upgrade_avail}"
  plume_host_profile_set_value supervisor_systemd_unit "${systemd_unit}"
}

plume_native_supervisor_program_conf_path() {
  local name="$1"
  local base="${name}"
  local ext
  if [[ "${base}" != plume-* ]]; then
    base="plume-${base}"
  fi
  base="${base//[^a-zA-Z0-9_-]/_}"
  ext="$(plume_native_supervisor_program_ext)"
  printf '%s/%s.%s' "$(plume_native_supervisor_programs_dir_path)" "${base}" "${ext}"
}

plume_native_supervisor_registry_add() {
  local name="$1"
  local path="$2"
  local template="${3:-generic}"
  local schema="${4:-${PLUME_SUPERVISOR_CONFIG_SCHEMA}}"
  local file line
  file="$(plume_native_supervisor_registry_file)"
  mkdir -p "$(dirname "${file}")"
  touch "${file}"
  line="${name}|${path}|${template}|${schema}"
  if grep -Fq "${name}|" "${file}" 2>/dev/null; then
    grep -Fv "${name}|" "${file}" > "${file}.tmp" 2>/dev/null || true
    mv "${file}.tmp" "${file}"
  fi
  printf '%s\n' "${line}" >> "${file}"
}

plume_native_supervisor_registry_list() {
  local file
  file="$(plume_native_supervisor_registry_file)"
  [[ -f "${file}" ]] || return 0
  grep -v '^#' "${file}" 2>/dev/null | grep -v '^$' || true
}

plume_native_supervisor_template_path() {
  local template="${1:-generic}"
  local root="${PLUME_ROOT:-}"
  if [[ -z "${root}" ]]; then
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd || true)"
  fi
  case "${template}" in
    horizon) printf '%s/templates/supervisor/program-horizon.conf.template' "${root}" ;;
    generic|*) printf '%s/templates/supervisor/program-generic.conf.template' "${root}" ;;
  esac
}

plume_native_supervisor_template_placeholders() {
  local template_file="$1"
  grep -oE '\{\{[a-zA-Z0-9_]+\}\}' "${template_file}" 2>/dev/null \
    | sed 's/[{}]//g' | sort -u || true
}

plume_native_supervisor_render_template() {
  local template_file="$1"
  shift
  local -a kv_pairs=("$@")
  local content key val placeholder
  content="$(cat "${template_file}")"
  for kv in "${kv_pairs[@]}"; do
    key="${kv%%=*}"
    val="${kv#*=}"
    placeholder="{{${key}}}"
    content="${content//${placeholder}/${val}}"
  done
  printf '%s' "${content}"
}

plume_native_supervisor_write_conf_file() {
  local dest="$1"
  local content="$2"
  local tmp
  tmp="$(mktemp)"
  printf '%s\n' "${content}" > "${tmp}"
  mkdir -p "$(dirname "${dest}")"
  if plume_fs_copy_no_tty "${tmp}" "${dest}"; then
    rm -f "${tmp}"
    return 0
  fi
  rm -f "${tmp}"
  if [[ -w "$(dirname "${dest}")" ]] || { [[ ! -e "${dest}" ]] && [[ -w "$(dirname "${dest}")" ]]; }; then
    printf '%s\n' "${content}" > "${dest}"
    return 0
  fi
  plume_err "cannot write supervisor program conf: ${dest} (need sudo or writable path)"
  return 2
}

plume_native_supervisor_ensure_programs_dir() {
  local dir
  dir="$(plume_native_supervisor_programs_dir_path)"
  mkdir -p "${dir}" 2>/dev/null || {
    if command -v sudo >/dev/null 2>&1; then
      sudo -n mkdir -p "${dir}" 2>/dev/null || return 2
    else
      return 2
    fi
  }
}

plume_native_supervisor_reload_program() {
  local name="$1"
  local st=""
  plume_native_supervisorctl reread >/dev/null 2>&1 || true
  plume_native_supervisorctl update >/dev/null 2>&1 || true
  plume_native_supervisorctl start "${name}" >/dev/null 2>&1 || true
  st="$(plume_native_supervisor_program_status "${name}" 2>/dev/null || true)"
  if printf '%s' "${st}" | grep -Eq 'RUNNING|STARTING'; then
    return 0
  fi
  # Drop-in not loaded yet: brew/systemd often needs a full unit restart before reread sees it.
  if [[ -z "${st}" ]] || printf '%s' "${st}" | grep -Eqi 'no such process|ERROR \(no such process\)'; then
    plume_info "reloading system supervisor for program ${name}"
    plume_native_supervisor_restart_system >/dev/null 2>&1 || true
    sleep 1
    plume_native_supervisorctl reread >/dev/null 2>&1 || true
    plume_native_supervisorctl update >/dev/null 2>&1 || true
    plume_native_supervisorctl start "${name}" >/dev/null 2>&1 || true
  fi
  return 0
}

plume_native_supervisor_stop_legacy() {
  local pid_file pid sock
  if ! plume_native_supervisor_legacy_running; then
    return 0
  fi
  if declare -F plume_native_supervisorctl >/dev/null 2>&1; then
    local legacy_conf
    legacy_conf="$(plume_native_supervisor_legacy_dir)/supervisord.conf"
    if [[ -f "${legacy_conf}" ]] && command -v supervisorctl >/dev/null 2>&1; then
      supervisorctl -c "${legacy_conf}" shutdown >/dev/null 2>&1 || true
    fi
  fi
  pid_file="$(plume_native_pid_file supervisor)"
  pid="$(cat "${pid_file}" 2>/dev/null || true)"
  [[ -n "${pid}" ]] && kill "${pid}" 2>/dev/null || true
  sock="$(plume_native_supervisor_legacy_dir)/supervisor.sock"
  rm -f "${pid_file}" "${sock}"
}

plume_native_supervisor_start_system() {
  local pm state
  if plume_native_driver_is_mock; then
    plume_info "native driver mock start: supervisor (system)"
    return 0
  fi
  plume_native_supervisor_stop_legacy || true
  pm="$(plume_native_supervisor_package_manager)"
  case "${pm}" in
    brew)
      if command -v brew >/dev/null 2>&1; then
        if HOMEBREW_NO_AUTO_UPDATE=1 brew services start supervisor >/dev/null 2>&1; then
          return 0
        fi
        HOMEBREW_NO_AUTO_UPDATE=1 brew services restart supervisor >/dev/null 2>&1
        return $?
      fi
      ;;
    apt|dnf)
      local unit
      unit="$(plume_native_supervisor_systemd_unit_name)"
      if command -v systemctl >/dev/null 2>&1; then
        systemctl enable "${unit}" >/dev/null 2>&1 || true
        systemctl start "${unit}" >/dev/null 2>&1
        return $?
      fi
      ;;
  esac
  plume_err "cannot start system supervisor (package manager=${pm})"
  return 2
}

plume_native_supervisor_stop_system() {
  local pm
  if plume_native_driver_is_mock; then
    return 0
  fi
  pm="$(plume_native_supervisor_package_manager)"
  case "${pm}" in
    brew)
      brew services stop supervisor 2>/dev/null || true
      ;;
    apt|dnf)
      local unit
      unit="$(plume_native_supervisor_systemd_unit_name)"
      systemctl stop "${unit}" 2>/dev/null || true
      ;;
  esac
  plume_native_supervisor_stop_legacy || true
}

plume_native_supervisor_restart_system() {
  local pm
  if plume_native_driver_is_mock; then
    return 0
  fi
  pm="$(plume_native_supervisor_package_manager)"
  case "${pm}" in
    brew)
      HOMEBREW_NO_AUTO_UPDATE=1 brew services restart supervisor >/dev/null 2>&1 \
        || HOMEBREW_NO_AUTO_UPDATE=1 brew services start supervisor >/dev/null 2>&1 \
        || true
      ;;
    apt|dnf)
      local unit
      unit="$(plume_native_supervisor_systemd_unit_name)"
      systemctl restart "${unit}" >/dev/null 2>&1 || systemctl start "${unit}" >/dev/null 2>&1 || true
      ;;
  esac
}

plume_native_supervisor_start() {
  plume_native_supervisor_start_system
}

plume_native_supervisor_stop() {
  plume_native_supervisor_stop_system
}

plume_native_supervisor_health() {
  local state
  if plume_native_driver_is_mock; then
    return 0
  fi
  if plume_native_supervisor_legacy_running; then
    return 1
  fi
  state="$(plume_native_supervisor_system_unit_state)"
  case "${state}" in
    started|active) ;;
    *)
      return 1
      ;;
  esac
  plume_native_supervisorctl status >/dev/null 2>&1
}

plume_native_supervisor_program_status() {
  local name="$1"
  plume_native_supervisorctl status "${name}" 2>/dev/null || true
}

plume_native_supervisor_horizon_defaults() {
  local project php_bin log_file name site_id
  site_id="${PLUME_HORIZON_SITE_ID:-__legacy__}"
  name="$(plume_native_horizon_program_name_for_site "${site_id}")"
  if ! declare -F plume_native_horizon_site_project_path >/dev/null 2>&1 \
    || ! project="$(plume_native_horizon_site_project_path "${site_id}")"; then
    return 1
  fi
  if ! declare -F plume_native_horizon_php_bin_for_site >/dev/null 2>&1 \
    || ! php_bin="$(plume_native_horizon_php_bin_for_site "${site_id}")"; then
    return 1
  fi
  if [[ "${site_id}" != "__legacy__" ]]; then
    log_file="$(plume_state_dir)/logs/services/native/horizon-${site_id}.log"
  else
    log_file="$(plume_service_log_file horizon native 2>/dev/null || printf '%s/logs/services/native/horizon.log' "$(plume_state_dir)")"
  fi
  mkdir -p "$(dirname "${log_file}")" 2>/dev/null || true
  printf 'name=%s\n' "${name}"
  printf 'command=%s\n' "${php_bin} artisan horizon"
  printf 'directory=%s\n' "${project}"
  printf 'autostart=true\n'
  printf 'autorestart=true\n'
  printf 'stopasgroup=true\n'
  printf 'killasgroup=true\n'
  printf 'stdout_logfile=%s\n' "${log_file}"
  printf 'redirect_stderr=true\n'
  printf 'environment=HOME="%s"\n' "${HOME}"
}

plume_native_supervisor_generic_defaults() {
  local name="${1:-plume-worker}"
  local log_file
  log_file="$(plume_service_log_file horizon native 2>/dev/null || printf '%s/logs/services/native/supervisor-worker.log' "$(plume_state_dir)")"
  printf 'name=%s\n' "${name}"
  printf 'command=\n'
  printf 'directory=%s\n' "${HOME}"
  printf 'autostart=true\n'
  printf 'autorestart=true\n'
  printf 'stopasgroup=true\n'
  printf 'killasgroup=true\n'
  printf 'stdout_logfile=%s\n' "${log_file}"
  printf 'redirect_stderr=true\n'
  printf 'environment=HOME="%s"\n' "${HOME}"
}

plume_native_supervisor_defaults_reset() {
  PLUME_SUPERVISOR_DEFAULTS_KV=""
}

plume_native_supervisor_defaults_set() {
  local k="$1"
  local v="$2"
  PLUME_SUPERVISOR_DEFAULTS_KV="${PLUME_SUPERVISOR_DEFAULTS_KV}${k}=${v}"$'\n'
}

plume_native_supervisor_defaults_get() {
  local k="$1"
  printf '%s' "${PLUME_SUPERVISOR_DEFAULTS_KV:-}" | awk -F= -v key="${k}" '$1==key { print substr($0, index($0, "=")+1); exit }'
}

plume_native_supervisor_defaults_load_stream() {
  local key val
  while IFS='=' read -r key val; do
    [[ -n "${key}" ]] || continue
    if [[ -z "$(plume_native_supervisor_defaults_get "${key}")" ]]; then
      plume_native_supervisor_defaults_set "${key}" "${val}"
    fi
  done
}

plume_native_supervisor_program_add() {
  local template="${PLUME_SUPERVISOR_PROGRAM_TEMPLATE:-generic}"
  local prog_name="${PLUME_SUPERVISOR_PROGRAM_NAME:-}"
  local non_interactive="${PLUME_SUPERVISOR_PROGRAM_NON_INTERACTIVE:-false}"
  local template_file dest content
  local key val placeholders

  template_file="$(plume_native_supervisor_template_path "${template}")"
  [[ -f "${template_file}" ]] || {
    plume_err "supervisor template not found: ${template}"
    return 2
  }

  plume_native_supervisor_defaults_reset

  if [[ "${template}" == "horizon" ]]; then
    plume_native_supervisor_defaults_load_stream < <(plume_native_supervisor_horizon_defaults || true)
  fi

  if [[ -z "${prog_name}" ]]; then
    prog_name="$(plume_native_supervisor_defaults_get name)"
  fi
  if [[ -z "${prog_name}" ]]; then
    prog_name="plume-worker"
  fi

  if [[ "${non_interactive}" != "true" ]]; then
    plume_native_supervisor_defaults_load_stream < <(plume_native_supervisor_generic_defaults "${prog_name}")
  fi

  placeholders="$(plume_native_supervisor_template_placeholders "${template_file}")"
  local -a kv_pairs=()
  while IFS= read -r key; do
    [[ -z "${key}" ]] && continue
    val="$(plume_native_supervisor_defaults_get "${key}")"
    if [[ "${non_interactive}" != "true" && -z "${val}" && "${key}" != "name" ]]; then
      val="$(plume_interactive_prompt "${key}" "" "${key}")"
    fi
    if [[ "${key}" == "name" && -z "${val}" ]]; then
      val="${prog_name}"
    fi
    kv_pairs+=("${key}=${val}")
  done <<< "${placeholders}"

  content="$(plume_native_supervisor_render_template "${template_file}" "${kv_pairs[@]}")"
  dest="$(plume_native_supervisor_program_conf_path "${prog_name}")"

  if [[ "${non_interactive}" != "true" ]]; then
    echo "--- preview ---" >&2
    printf '%s\n' "${content}" >&2
    plume_interactive_confirm_action "Write program conf to ${dest}?" "false" || return 2
  fi

  plume_native_supervisor_ensure_programs_dir || return 2
  plume_native_supervisor_write_conf_file "${dest}" "${content}" || return 2
  # Drop stale same-program files with wrong extension/path (Homebrew expects *.ini under etc/supervisor.d).
  local stale_dir stale
  for stale_dir in \
    "$(plume_native_supervisor_homebrew_cellar_prefix 2>/dev/null)/etc/supervisor.d" \
    "$(plume_native_supervisor_homebrew_etc_prefix 2>/dev/null)/etc/supervisor.d" \
    "$(plume_native_supervisor_programs_dir_path)"; do
    [[ -n "${stale_dir}" && -d "${stale_dir}" ]] || continue
    for stale in "${stale_dir}/${prog_name}.conf" "${stale_dir}/${prog_name}.ini"; do
      if [[ -f "${stale}" && "${stale}" != "${dest}" ]]; then
        rm -f "${stale}" || true
      fi
    done
  done
  plume_native_supervisor_registry_add "${prog_name}" "${dest}" "${template}"
  plume_native_supervisor_reload_program "${prog_name}"
  plume_info "supervisor program added: ${prog_name} -> ${dest}"
}

plume_native_supervisor_migrate_legacy_programs() {
  local legacy_dir dest_dir src dest base
  legacy_dir="$(plume_native_supervisor_legacy_programs_dir)"
  dest_dir="$(plume_native_supervisor_programs_dir_path)"
  [[ -d "${legacy_dir}" ]] || return 0
  plume_native_supervisor_ensure_programs_dir || return 2
  for src in "${legacy_dir}"/*.conf "${legacy_dir}"/*.ini; do
    [[ -f "${src}" ]] || continue
    base="$(basename "${src}")"
    dest="${dest_dir}/${base%.*}.$(plume_native_supervisor_program_ext)"
    if [[ ! -f "${dest}" ]]; then
      plume_fs_copy_no_tty "${src}" "${dest}" 2>/dev/null || cp "${src}" "${dest}" 2>/dev/null || true
      plume_native_supervisor_registry_add "${base%.*}" "${dest}" "migrated" "${PLUME_SUPERVISOR_CONFIG_SCHEMA}"
    fi
  done
}

plume_native_supervisor_upgrade_package() {
  local pm
  if plume_native_driver_is_mock; then
    plume_info "native driver mock upgrade: supervisor"
    return 0
  fi
  pm="$(plume_native_supervisor_package_manager)"
  case "${pm}" in
    brew) brew upgrade supervisor ;;
    apt) DEBIAN_FRONTEND=noninteractive apt-get install -y --only-upgrade supervisor ;;
    dnf) dnf upgrade -y supervisor ;;
    *)
      plume_err "unsupported package manager for supervisor upgrade: ${pm}"
      return 2
      ;;
  esac
}

plume_native_supervisor_upgrade() {
  local dry_run="${1:-false}"
  local steps=()

  steps+=("stop legacy Plume supervisord")
  steps+=("upgrade supervisor package (${PLUME_SUPERVISOR_PACKAGE_MANAGER:-$(plume_native_supervisor_package_manager)})")
  steps+=("migrate program confs to $(plume_native_supervisor_programs_dir_path)")
  steps+=("set supervisor_config_schema=${PLUME_SUPERVISOR_CONFIG_SCHEMA}")
  steps+=("restart system supervisor")

  if [[ "${dry_run}" == "true" ]]; then
    plume_info "supervisor upgrade dry-run:"
    local s
    for s in "${steps[@]}"; do
      printf '  - %s\n' "${s}"
    done
    return 0
  fi

  plume_native_supervisor_stop_legacy || true
  plume_native_supervisor_upgrade_package || return 2
  plume_native_supervisor_migrate_legacy_programs || return 2
  plume_host_profile_set_value supervisor_config_schema "${PLUME_SUPERVISOR_CONFIG_SCHEMA}"
  plume_host_profile_set_value supervisor_runtime "$(plume_native_supervisor_runtime_kind)"
  plume_native_supervisor_restart_system || return 2
  plume_host_profile_supervisor_persist || true
  plume_info "supervisor upgrade complete (schema=${PLUME_SUPERVISOR_CONFIG_SCHEMA})"
}

# Backward compat aliases used by native_horizon / drivers
plume_native_supervisor_write_conf() {
  plume_native_supervisor_ensure_programs_dir || true
}

plume_native_supervisor_start_daemon() {
  plume_native_supervisor_start_system
}

plume_native_supervisor_dir() {
  plume_native_supervisor_legacy_dir
}

plume_native_supervisor_programs_dir() {
  plume_native_supervisor_programs_dir_path
}

plume_native_supervisor_running() {
  plume_native_supervisor_health
}

plume_native_supervisor_doctor_needs_upgrade() {
  plume_native_supervisor_legacy_running && return 0
  plume_native_supervisor_package_upgrade_available && return 0
  local schema
  schema="$(plume_host_profile_read_value supervisor_config_schema 2>/dev/null || true)"
  [[ "${schema}" != "${PLUME_SUPERVISOR_CONFIG_SCHEMA}" ]] && return 0
  return 1
}
