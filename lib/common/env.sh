#!/usr/bin/env bash
set -euo pipefail

plume_global_env_file() {
  printf '%s' "${PLUME_GLOBAL_ENV_FILE:-$HOME/.config/plume/.env}"
}

plume_builtin_env_example_file() {
  printf '%s' "${PLUME_BUILTIN_ENV_EXAMPLE_FILE:-${ROOT_DIR}/templates/native-core.env.example}"
}

plume_resolve_env_file() {
  local requested="${1:-.env}"
  local resolved="${requested}"

  if [[ "${requested}" == ".env" ]]; then
    local global_env global_dir global_example builtin_example source_example
    global_env="$(plume_global_env_file)"
    global_dir="$(dirname "${global_env}")"
    global_example="${PLUME_GLOBAL_ENV_EXAMPLE_FILE:-${global_dir}/.env.example}"
    builtin_example="$(plume_builtin_env_example_file)"

    if [[ ! -f "${global_env}" ]]; then
      source_example=""
      if [[ -f "${global_example}" ]]; then
        source_example="${global_example}"
      elif [[ -f "${builtin_example}" ]]; then
        source_example="${builtin_example}"
      elif [[ -f ".env.example" ]]; then
        source_example=".env.example"
      fi
      if [[ -n "${source_example}" ]]; then
        mkdir -p "${global_dir}"
        cp "${source_example}" "${global_env}"
        plume_info "bootstrapped global env from ${source_example} -> ${global_env}"
      fi
    fi

    if [[ -f "${global_env}" ]]; then
      resolved="${global_env}"
    else
      # Backward-compatible fallback for callers expecting local .env.
      resolved=".env"
    fi
  fi

  printf '%s' "${resolved}"
}

plume_load_env() {
  local env_file="${1:-.env}"
  local mode_was_set="false" mode_prev=""
  local dl_compose_was_set="false" dl_compose_prev=""
  local laradock_path_was_set="false" laradock_path_prev=""
  local state_dir_was_set="false" state_dir_prev=""
  local log_dir_was_set="false" log_dir_prev=""
  local -a preserved_keys=()
  local -a preserved_values=()
  local preserved_key
  local preserved_idx

  env_file="$(plume_resolve_env_file "${env_file}")"
  if [[ "${env_file}" == "~"* ]]; then
    env_file="${HOME}${env_file#\~}"
  fi

  if [[ -z "${env_file}" ]]; then
    return 0
  fi

  if [[ -f "${env_file}" ]]; then
    plume_env_file_defines_key() {
      local key="$1"
      grep -q "^${key}=" "${env_file}" 2>/dev/null \
        || grep -q "^export[[:space:]]\\+${key}=" "${env_file}" 2>/dev/null
    }

    while IFS='=' read -r preserved_key _; do
      case "${preserved_key}" in
        PLUME_*|PMA_*)
          if plume_env_file_defines_key "${preserved_key}"; then
            continue
          fi
          if [[ -n "${!preserved_key+x}" ]]; then
            preserved_keys+=("${preserved_key}")
            preserved_values+=("${!preserved_key}")
          fi
          ;;
      esac
    done < <(env)

    if [[ -n "${PLUME_MODE+x}" ]]; then
      mode_was_set="true"
      mode_prev="${PLUME_MODE}"
    fi
    if [[ -n "${PLUME_DOCKER_LITE_COMPOSE_FILE+x}" ]]; then
      dl_compose_was_set="true"
      dl_compose_prev="${PLUME_DOCKER_LITE_COMPOSE_FILE}"
    fi
    if [[ -n "${PLUME_LARADOCK_PATH+x}" ]]; then
      laradock_path_was_set="true"
      laradock_path_prev="${PLUME_LARADOCK_PATH}"
    fi
    if [[ -n "${PLUME_STATE_DIR+x}" ]]; then
      state_dir_was_set="true"
      state_dir_prev="${PLUME_STATE_DIR}"
    fi
    if [[ -n "${PLUME_LOG_DIR+x}" ]]; then
      log_dir_was_set="true"
      log_dir_prev="${PLUME_LOG_DIR}"
    fi
    # shellcheck disable=SC1091
    source "${env_file}"
    for preserved_idx in "${!preserved_keys[@]}"; do
      export "${preserved_keys[$preserved_idx]}=${preserved_values[$preserved_idx]}"
    done
    # Mode/path are global state concerns; ignore .env-provided values.
    if [[ "${mode_was_set}" == "true" ]]; then
      export PLUME_MODE="${mode_prev}"
    else
      unset PLUME_MODE || true
    fi
    if [[ "${dl_compose_was_set}" == "true" ]]; then
      export PLUME_DOCKER_LITE_COMPOSE_FILE="${dl_compose_prev}"
    else
      unset PLUME_DOCKER_LITE_COMPOSE_FILE || true
    fi
    if [[ "${laradock_path_was_set}" == "true" ]]; then
      export PLUME_LARADOCK_PATH="${laradock_path_prev}"
    else
      unset PLUME_LARADOCK_PATH || true
    fi
    if [[ "${state_dir_was_set}" == "true" ]]; then
      export PLUME_STATE_DIR="${state_dir_prev}"
    fi
    if [[ "${log_dir_was_set}" == "true" ]]; then
      export PLUME_LOG_DIR="${log_dir_prev}"
    fi
    return 0
  fi

  if [[ -n "${1:-}" ]]; then
    plume_err "env file not found: ${env_file}"
    return 2
  fi
}

plume_bool() {
  local value="${1:-false}"
  case "${value}" in
    1|true|TRUE|yes|YES|on|ON) printf 'true' ;;
    *) printf 'false' ;;
  esac
}

plume_load_mode_context_env() {
  local mode path context_env
  mode="$(plume_mode_current)"
  case "${mode}" in
    docker-lite)
      path="$(plume_mode_path_get docker-lite || true)"
      [[ -n "${path}" ]] || return 0
      context_env="${path}/.env.docker-lite"
      if [[ -f "${context_env}" ]]; then
        plume_load_env "${context_env}" || return $?
      fi
      ;;
    *)
      ;;
  esac
}
