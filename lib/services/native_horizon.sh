#!/usr/bin/env bash
set -euo pipefail

# Native supervisor + Laravel Horizon (D-147). Plume-owned supervisord, not the
# Homebrew system-wide unit. Mock driver: no-op success.

plume_native_supervisor_dir() {
  printf '%s/native/supervisor' "$(plume_state_dir)"
}

plume_native_supervisor_conf() {
  printf '%s/supervisord.conf' "$(plume_native_supervisor_dir)"
}

plume_native_supervisor_sock() {
  printf '%s/supervisor.sock' "$(plume_native_supervisor_dir)"
}

plume_native_supervisor_programs_dir() {
  printf '%s/programs' "$(plume_native_supervisor_dir)"
}

plume_native_horizon_program_name() {
  printf '%s' "plume-horizon"
}

plume_native_horizon_program_file() {
  printf '%s/%s.conf' "$(plume_native_supervisor_programs_dir)" "$(plume_native_horizon_program_name)"
}

plume_native_supervisorctl() {
  local conf
  conf="$(plume_native_supervisor_conf)"
  if command -v supervisorctl >/dev/null 2>&1; then
    supervisorctl -c "${conf}" "$@"
    return $?
  fi
  return 1
}

plume_native_horizon_project_path() {
  local path="" id file candidate

  if [[ -n "${PLUME_HORIZON_PATH:-}" ]]; then
    path="${PLUME_HORIZON_PATH}"
    if [[ "${path}" != /* ]]; then
      path="$(cd "${path}" 2>/dev/null && pwd || true)"
    fi
    if [[ -n "${path}" && -f "${path}/artisan" ]]; then
      printf '%s' "${path}"
      return 0
    fi
  fi

  if declare -F plume_sites_index_ids >/dev/null 2>&1; then
    while IFS= read -r id; do
      [[ -z "${id}" ]] && continue
      file="$(plume_sites_file "${id}" 2>/dev/null || true)"
      [[ -f "${file}" ]] || continue
      candidate="$(plume_sites_record_value "${file}" path 2>/dev/null || true)"
      [[ -n "${candidate}" && -f "${candidate}/artisan" ]] || continue
      printf '%s' "${candidate}"
      return 0
    done < <(plume_sites_index_ids)
  fi

  if declare -F plume_laravel_resolve_project_context >/dev/null 2>&1; then
    if plume_laravel_resolve_project_context "" >/dev/null 2>&1 \
      && [[ -n "${PLUME_LARAVEL_PROJECT_PATH:-}" && -f "${PLUME_LARAVEL_PROJECT_PATH}/artisan" ]]; then
      printf '%s' "${PLUME_LARAVEL_PROJECT_PATH}"
      return 0
    fi
  fi

  return 1
}

plume_native_horizon_php_bin() {
  local project="$1"
  local version="" php_bin="" file id

  if [[ -n "${PLUME_PHP_BIN:-}" ]]; then
    printf '%s' "${PLUME_PHP_BIN}"
    return 0
  fi

  if declare -F plume_sites_index_ids >/dev/null 2>&1; then
    while IFS= read -r id; do
      [[ -z "${id}" ]] && continue
      file="$(plume_sites_file "${id}" 2>/dev/null || true)"
      [[ -f "${file}" ]] || continue
      if [[ "$(plume_sites_record_value "${file}" path 2>/dev/null || true)" == "${project}" ]]; then
        version="$(plume_sites_record_php_version "${file}" 2>/dev/null || true)"
        break
      fi
    done < <(plume_sites_index_ids)
  fi

  if [[ -z "${version}" || "${version}" == "default" ]]; then
    version="${PLUME_PHP_DEFAULT_VERSION:-${PLUME_PHP_VERSION:-8.3}}"
  fi

  if declare -F plume_php_find_cli_bin >/dev/null 2>&1; then
    php_bin="$(plume_php_find_cli_bin "${version}" 2>/dev/null || true)"
  fi
  if [[ -n "${php_bin}" ]]; then
    printf '%s' "${php_bin}"
    return 0
  fi
  if command -v php >/dev/null 2>&1; then
    printf '%s' "$(command -v php)"
    return 0
  fi
  return 1
}

plume_native_supervisor_write_conf() {
  local dir conf sock log_file pid_file
  dir="$(plume_native_supervisor_dir)"
  conf="$(plume_native_supervisor_conf)"
  sock="$(plume_native_supervisor_sock)"
  mkdir -p "${dir}" "$(plume_native_supervisor_programs_dir)"
  log_file="$(plume_service_log_file supervisor native 2>/dev/null || printf '%s/supervisord.log' "${dir}")"
  pid_file="$(plume_native_pid_file supervisor)"
  mkdir -p "$(dirname "${log_file}")" "$(dirname "${pid_file}")"

  cat > "${conf}" <<EOF
[unix_http_server]
file=${sock}
chmod=0700

[supervisord]
logfile=${log_file}
pidfile=${pid_file}
nodaemon=true
silent=true
identifier=plume-supervisor

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix://${sock}

[include]
files = ${dir}/programs/*.conf
EOF
}

plume_native_horizon_write_program() {
  local project php_bin name prog log_file
  project="$(plume_native_horizon_project_path)" || return 1
  php_bin="$(plume_native_horizon_php_bin "${project}")" || return 1
  name="$(plume_native_horizon_program_name)"
  prog="$(plume_native_horizon_program_file)"
  log_file="$(plume_service_log_file horizon native 2>/dev/null || printf '%s/horizon.log' "$(plume_native_supervisor_dir)")"
  mkdir -p "$(dirname "${prog}")" "$(dirname "${log_file}")"

  cat > "${prog}" <<EOF
[program:${name}]
directory=${project}
command=${php_bin} artisan horizon
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
stdout_logfile=${log_file}
redirect_stderr=true
environment=HOME="${HOME}"
EOF
  plume_info "native horizon: program ${name} project=${project} php=${php_bin}"
}

plume_native_supervisor_running() {
  local pid_file pid
  pid_file="$(plume_native_pid_file supervisor)"
  pid="$(cat "${pid_file}" 2>/dev/null || true)"
  [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null
}

plume_native_supervisor_start_daemon() {
  local conf pid_file log_file bin
  plume_native_supervisor_write_conf
  conf="$(plume_native_supervisor_conf)"
  pid_file="$(plume_native_pid_file supervisor)"
  log_file="$(plume_service_log_file supervisor native)"

  if plume_native_supervisor_running; then
    return 0
  fi

  bin="$(command -v supervisord || true)"
  if [[ -z "${bin}" ]]; then
    plume_err "supervisord not found; brew install supervisor (or apt install supervisor)"
    return 2
  fi

  rm -f "$(plume_native_supervisor_sock)"
  plume_native_detach_daemon "${pid_file}" "${log_file}" "${bin}" -c "${conf}" || return 2

  local i
  for i in 1 2 3 4 5 6 7 8; do
    if plume_native_supervisorctl status >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.25
  done
  plume_warn "native supervisor: daemon started but supervisorctl not ready yet"
  return 0
}

plume_native_supervisor_start() {
  if plume_native_driver_is_mock; then
    plume_info "native driver mock start: supervisor"
    return 0
  fi
  plume_native_supervisor_start_daemon
}

plume_native_supervisor_stop() {
  local pid_file pid
  if plume_native_driver_is_mock; then
    return 0
  fi
  plume_native_supervisorctl shutdown >/dev/null 2>&1 || true
  pid_file="$(plume_native_pid_file supervisor)"
  pid="$(cat "${pid_file}" 2>/dev/null || true)"
  [[ -n "${pid}" ]] && kill "${pid}" 2>/dev/null || true
  rm -f "${pid_file}" "$(plume_native_supervisor_sock)"
}

plume_native_horizon_start() {
  if plume_native_driver_is_mock; then
    plume_info "native driver mock start: horizon"
    return 0
  fi
  if ! plume_native_horizon_write_program; then
    plume_err "native horizon: no Laravel project with artisan (set PLUME_HORIZON_PATH or register a site)"
    return 2
  fi
  plume_native_supervisor_start_daemon || return 2
  plume_native_supervisorctl reread >/dev/null 2>&1 || true
  plume_native_supervisorctl update >/dev/null 2>&1 || true
  plume_native_supervisorctl start "$(plume_native_horizon_program_name)" >/dev/null 2>&1 || true
}

plume_native_horizon_stop() {
  if plume_native_driver_is_mock; then
    return 0
  fi
  plume_native_supervisorctl stop "$(plume_native_horizon_program_name)" >/dev/null 2>&1 || true
}

plume_native_supervisor_health() {
  if plume_native_driver_is_mock; then
    return 0
  fi
  plume_native_supervisor_running || return 1
  plume_native_supervisorctl status >/dev/null 2>&1
}

plume_native_horizon_health() {
  local name st
  if plume_native_driver_is_mock; then
    return 0
  fi
  plume_native_supervisor_running || return 1
  name="$(plume_native_horizon_program_name)"
  st="$(plume_native_supervisorctl status "${name}" 2>/dev/null || true)"
  printf '%s' "${st}" | grep -Eq 'RUNNING|STARTING'
}
