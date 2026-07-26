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

cmd_env() {
  local sub="${1:-where}"
  shift || true
  case "${sub}" in
    where) cmd_env_where "$@" ;;
    init) cmd_env_init "$@" ;;
    *)
      plume_err "unknown env subcommand: ${sub} (use where|init)"
      return 2
      ;;
  esac
}
