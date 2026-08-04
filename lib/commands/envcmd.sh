#!/usr/bin/env bash
set -euo pipefail

cmd_env_where() {
  local env_file example_file builtin_example
  env_file="$(plume_global_env_file)"
  example_file="${PLUME_GLOBAL_ENV_EXAMPLE_FILE:-$(dirname "${env_file}")/.env.example}"
  builtin_example="$(plume_builtin_env_example_file)"

  if [[ "${PLUME_OUTPUT:-text}" == "json" ]]; then
    printf '{"ok":true,"command":"env where","data":{"global_env":"%s","global_env_example":"%s","builtin_env_example":"%s"},"warnings":[],"errors":[]}\n' \
      "${env_file}" "${example_file}" "${builtin_example}"
    return 0
  fi

  printf 'GLOBAL_ENV        %s\n' "${env_file}"
  printf 'GLOBAL_EXAMPLE    %s\n' "${example_file}"
  printf 'BUILTIN_EXAMPLE   %s\n' "${builtin_example}"
}

cmd_env_init() {
  local force="false"
  local from=""
  local token
  for token in "$@"; do
    case "${token}" in
      --force) force="true" ;;
      --from=*) from="${token#--from=}" ;;
      *)
        plume_err "unknown env init option: ${token}"
        return 2
        ;;
    esac
  done

  local env_file example_file builtin_example source_file
  env_file="$(plume_global_env_file)"
  example_file="${PLUME_GLOBAL_ENV_EXAMPLE_FILE:-$(dirname "${env_file}")/.env.example}"
  builtin_example="$(plume_builtin_env_example_file)"
  source_file="${from}"

  if [[ -z "${source_file}" ]]; then
    if [[ -f "${example_file}" ]]; then
      source_file="${example_file}"
    elif [[ -f "${builtin_example}" ]]; then
      source_file="${builtin_example}"
    elif [[ -f ".env.example" ]]; then
      source_file=".env.example"
    fi
  fi

  if [[ -z "${source_file}" || ! -f "${source_file}" ]]; then
    plume_err "env init requires an example file (.env.example, global .env.example, or --from=/path)"
    return 2
  fi

  mkdir -p "$(dirname "${env_file}")"
  if [[ -f "${env_file}" && "${force}" != "true" ]]; then
    plume_info "global env already exists: ${env_file}"
    plume_info "use --force to overwrite, or run: ./plume.sh env where"
    return 0
  fi

  cp "${source_file}" "${env_file}"
  plume_info "global env initialized: ${env_file}"
  plume_info "source: ${source_file}"
}

cmd_env_set() {
  local kv key value
  if [[ $# -lt 1 ]]; then
    plume_err "env set requires KEY=VALUE"
    return 2
  fi
  kv="$1"
  if [[ "${kv}" != *=* ]]; then
    plume_err "env set requires KEY=VALUE"
    return 2
  fi
  key="${kv%%=*}"
  value="${kv#*=}"
  if [[ ! "${key}" =~ ^PLUME_[A-Z0-9_]+$ ]]; then
    plume_err "env set only accepts PLUME_* keys (got: ${key})"
    return 2
  fi
  plume_stack_service_env_write_and_export "${key}" "${value}" || return $?
  if plume_stack_service_env_affected_services "${key}" >/dev/null 2>&1; then
    plume_info "restart affected services to apply runtime config:"
    while IFS= read -r svc; do
      [[ -n "${svc}" ]] || continue
      plume_info "  ./plume.sh services restart ${svc} --mode=native"
    done < <(plume_stack_service_env_affected_services "${key}")
  fi
}

cmd_env() {
  local sub="${1:-where}"
  shift || true
  case "${sub}" in
    where) cmd_env_where "$@" ;;
    init) cmd_env_init "$@" ;;
    set) cmd_env_set "$@" ;;
    *)
      plume_err "unknown env subcommand: ${sub} (use where|init|set)"
      return 2
      ;;
  esac
}
