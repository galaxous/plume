#!/usr/bin/env bash
set -euo pipefail

plume_project_usage() {
  cat <<'EOF'
plumectl project <subcommand>

subcommands:
  init    Bootstrap a Laravel project folder
  env     Project environment operations

Init options:
  --path=</abs/project/path>      Required
  --dry-run                       Print planned actions without applying
  --migrate                       Run php artisan migrate --force
  --seed                          Run php artisan db:seed --force (implies --migrate)
  --npm-install                   Run npm install when package.json exists
  --npm-build                     Run npm run build (requires --npm-install or existing node_modules)
  --npm-dev                       Run npm run dev (requires --npm-install or existing node_modules)
  --skip-composer                 Skip composer install
  --skip-key-generate             Skip php artisan key:generate
  --skip-storage-link             Skip php artisan storage:link

Env subcommands:
  sync-secrets    Sync secrets from plume state into project .env

Env sync-secrets options:
  --path=</abs/project/path>      Required
  --keys=K1,K2                    Optional comma-separated keys (default: all)
  --dry-run                       Print planned .env updates without writing
  --create-env                    Create .env from .env.example if missing

Examples:
  plumectl project init --path=/var/www/myapp
  plumectl project init --path=/var/www/myapp --migrate --seed --npm-install --npm-build
  plumectl project init --path=/var/www/myapp --dry-run
  plumectl project env sync-secrets --path=/var/www/myapp --keys=APP_KEY,DB_PASSWORD
EOF
}

plume_project_cmd_exists() {
  command -v "$1" >/dev/null 2>&1
}

plume_project_run_in_path() {
  local path="$1"
  shift
  (
    cd "${path}"
    "$@"
  )
}

plume_project_step() {
  local dry_run="$1"
  local description="$2"
  shift 2

  if [[ "${dry_run}" == "true" ]]; then
    plume_info "[DRY-RUN] ${description}"
    return 0
  fi

  plume_info "${description}"
  "$@"
}

plume_project_set_env_kv() {
  local env_file="$1"
  local key="$2"
  local value="$3"
  local tmp
  tmp="$(mktemp)"
  if [[ -f "${env_file}" ]]; then
    grep -Ev "^${key}=" "${env_file}" > "${tmp}" 2>/dev/null || true
  fi
  printf '%s=%s\n' "${key}" "${value}" >> "${tmp}"
  mv "${tmp}" "${env_file}"
}

plume_project_secret_get() {
  local key="$1"
  local secrets_file
  secrets_file="$(plume_state_dir)/secrets.env"
  [[ -f "${secrets_file}" ]] || return 1
  local line
  line="$(grep -E "^${key}=" "${secrets_file}" 2>/dev/null | tail -n 1 || true)"
  [[ -n "${line}" ]] || return 1
  printf '%s' "${line#*=}"
}

plume_project_secret_keys_list() {
  local secrets_file
  secrets_file="$(plume_state_dir)/secrets.env"
  [[ -f "${secrets_file}" ]] || return 0
  awk -F= 'NF>=2 {print $1}' "${secrets_file}" | sort -u
}

cmd_project_init() {
  local path=""
  local dry_run="false"
  local migrate="false"
  local seed="false"
  local npm_install="false"
  local npm_build="false"
  local npm_dev="false"
  local skip_composer="false"
  local skip_key_generate="false"
  local skip_storage_link="false"

  local arg
  for arg in "$@"; do
    case "${arg}" in
      --path=*) path="${arg#*=}" ;;
      --dry-run) dry_run="true" ;;
      --migrate) migrate="true" ;;
      --seed) seed="true"; migrate="true" ;;
      --npm-install) npm_install="true" ;;
      --npm-build) npm_build="true" ;;
      --npm-dev) npm_dev="true" ;;
      --skip-composer) skip_composer="true" ;;
      --skip-key-generate) skip_key_generate="true" ;;
      --skip-storage-link) skip_storage_link="true" ;;
      *)
        plume_err "unknown project init option: ${arg}"
        return 2
        ;;
    esac
  done

  if [[ -z "${path}" ]]; then
    plume_err "project path is required"
    return 2
  fi

  if [[ ! -d "${path}" ]]; then
    plume_err "invalid project path: ${path}"
    return 2
  fi

  path="$(cd "${path}" && pwd)"

  local composer_bin="${PLUME_COMPOSER_BIN:-composer}"
  local php_bin="${PLUME_PHP_BIN:-php}"
  local npm_bin="${PLUME_NPM_BIN:-npm}"
  local artisan="${path}/artisan"
  local env_file="${path}/.env"
  local env_example="${path}/.env.example"
  local composer_json="${path}/composer.json"
  local package_json="${path}/package.json"

  if [[ "${skip_composer}" != "true" && -f "${composer_json}" ]]; then
    if ! plume_project_cmd_exists "${composer_bin}"; then
      plume_err "composer command not found: ${composer_bin}"
      return 2
    fi
  fi

  if { [[ "${skip_key_generate}" != "true" ]] || [[ "${skip_storage_link}" != "true" ]] || [[ "${migrate}" == "true" ]] || [[ "${seed}" == "true" ]]; } && [[ -f "${artisan}" ]]; then
    if ! plume_project_cmd_exists "${php_bin}"; then
      plume_err "php command not found: ${php_bin}"
      return 2
    fi
  fi

  if { [[ "${npm_install}" == "true" ]] || [[ "${npm_build}" == "true" ]] || [[ "${npm_dev}" == "true" ]]; } && [[ -f "${package_json}" ]]; then
    if ! plume_project_cmd_exists "${npm_bin}"; then
      plume_err "npm command not found: ${npm_bin}"
      return 2
    fi
  fi

  if [[ "${skip_composer}" != "true" ]]; then
    if [[ -f "${composer_json}" ]]; then
      plume_project_step "${dry_run}" "composer install" plume_project_run_in_path "${path}" "${composer_bin}" install || {
        plume_err "composer install failed"
        return 2
      }
    else
      plume_warn "composer.json not found; skipping composer install"
    fi
  fi

  if [[ ! -f "${env_file}" ]]; then
    if [[ -f "${env_example}" ]]; then
      if [[ "${dry_run}" == "true" ]]; then
        plume_info "[DRY-RUN] copy .env.example -> .env"
      else
        plume_info "copy .env.example -> .env"
        cp "${env_example}" "${env_file}"
      fi
    else
      plume_warn ".env and .env.example not found; skipping env bootstrap"
    fi
  fi

  if [[ -f "${artisan}" ]]; then
    if [[ "${skip_key_generate}" != "true" ]]; then
      plume_project_step "${dry_run}" "php artisan key:generate" plume_project_run_in_path "${path}" "${php_bin}" artisan key:generate --ansi || {
        plume_err "artisan key:generate failed"
        return 2
      }
    fi

    if [[ "${skip_storage_link}" != "true" ]]; then
      plume_project_step "${dry_run}" "php artisan storage:link" plume_project_run_in_path "${path}" "${php_bin}" artisan storage:link || {
        plume_err "artisan storage:link failed"
        return 2
      }
    fi

    if [[ "${migrate}" == "true" ]]; then
      plume_project_step "${dry_run}" "php artisan migrate --force" plume_project_run_in_path "${path}" "${php_bin}" artisan migrate --force || {
        plume_err "artisan migrate failed"
        return 2
      }
    fi

    if [[ "${seed}" == "true" ]]; then
      plume_project_step "${dry_run}" "php artisan db:seed --force" plume_project_run_in_path "${path}" "${php_bin}" artisan db:seed --force || {
        plume_err "artisan db:seed failed"
        return 2
      }
    fi
  else
    plume_warn "artisan not found; skipping laravel artisan steps"
  fi

  if [[ -f "${package_json}" ]]; then
    if [[ "${npm_install}" == "true" ]]; then
      plume_project_step "${dry_run}" "npm install" plume_project_run_in_path "${path}" "${npm_bin}" install || {
        plume_err "npm install failed"
        return 2
      }
    fi

    if [[ "${npm_build}" == "true" ]]; then
      plume_project_step "${dry_run}" "npm run build" plume_project_run_in_path "${path}" "${npm_bin}" run build || {
        plume_err "npm run build failed"
        return 2
      }
    fi

    if [[ "${npm_dev}" == "true" ]]; then
      plume_project_step "${dry_run}" "npm run dev" plume_project_run_in_path "${path}" "${npm_bin}" run dev || {
        plume_err "npm run dev failed"
        return 2
      }
    fi
  elif [[ "${npm_install}" == "true" || "${npm_build}" == "true" || "${npm_dev}" == "true" ]]; then
    plume_warn "package.json not found; skipping npm steps"
  fi

  if [[ "${PLUME_OUTPUT:-text}" == "json" ]]; then
    printf '{"ok":true,"command":"project init","data":{"path":"%s","dry_run":%s,"migrate":%s,"seed":%s,"npm_install":%s,"npm_build":%s,"npm_dev":%s},"warnings":[],"errors":[]}\n' \
      "${path}" "${dry_run}" "${migrate}" "${seed}" "${npm_install}" "${npm_build}" "${npm_dev}"
  else
    plume_info "project init complete: ${path}"
  fi
}

cmd_project_env_sync_secrets() {
  local path="" keys_csv="" dry_run="false" create_env="false"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --path=*) path="${arg#*=}" ;;
      --keys=*) keys_csv="${arg#*=}" ;;
      --dry-run) dry_run="true" ;;
      --create-env) create_env="true" ;;
      *)
        plume_err "unknown project env sync-secrets option: ${arg}"
        return 2
        ;;
    esac
  done

  if [[ -z "${path}" ]]; then
    plume_err "project path is required"
    return 2
  fi
  if [[ ! -d "${path}" ]]; then
    plume_err "invalid project path: ${path}"
    return 2
  fi
  path="$(cd "${path}" && pwd)"

  local env_file env_example
  env_file="${path}/.env"
  env_example="${path}/.env.example"

  if [[ ! -f "$(plume_state_dir)/secrets.env" ]]; then
    plume_err "secrets store not found: $(plume_state_dir)/secrets.env"
    return 2
  fi

  if [[ ! -f "${env_file}" ]]; then
    if [[ "${create_env}" == "true" && -f "${env_example}" ]]; then
      if [[ "${dry_run}" == "true" ]]; then
        plume_info "[DRY-RUN] copy .env.example -> .env"
      else
        cp "${env_example}" "${env_file}"
      fi
    else
      plume_err ".env not found under project path (use --create-env if .env.example exists)"
      return 2
    fi
  fi

  local -a keys=()
  if [[ -n "${keys_csv}" ]]; then
    IFS=',' read -r -a keys <<< "${keys_csv}"
  else
    while IFS= read -r arg; do
      [[ -z "${arg}" ]] && continue
      keys+=("${arg}")
    done < <(plume_project_secret_keys_list)
  fi

  if [[ ${#keys[@]} -eq 0 ]]; then
    plume_err "no secret keys to sync"
    return 2
  fi

  local synced=0 missing=0 key value
  for key in "${keys[@]}"; do
    key="$(printf '%s' "${key}" | tr -d ' ')"
    [[ -z "${key}" ]] && continue
    if ! value="$(plume_project_secret_get "${key}")"; then
      missing=$((missing + 1))
      plume_warn "secret key not found in store: ${key}"
      continue
    fi
    if [[ "${dry_run}" == "true" ]]; then
      plume_info "[DRY-RUN] set ${key}=*** in ${env_file}"
    else
      plume_project_set_env_kv "${env_file}" "${key}" "${value}"
    fi
    synced=$((synced + 1))
  done

  plume_state_db_append_event "native" "" "project.env.sync-secrets.ok" "path=${path},synced=${synced},missing=${missing},dry_run=${dry_run}"
  if [[ "${PLUME_OUTPUT:-text}" == "json" ]]; then
    printf '{"ok":true,"command":"project env sync-secrets","data":{"path":"%s","synced":%s,"missing":%s,"dry_run":%s},"warnings":[],"errors":[]}\n' \
      "${path}" "${synced}" "${missing}" "${dry_run}"
    return 0
  fi
  plume_info "project env sync complete: path=${path}, synced=${synced}, missing=${missing}"
}

cmd_project_env() {
  local sub="${1:-sync-secrets}"
  shift || true
  case "${sub}" in
    sync-secrets) cmd_project_env_sync_secrets "$@" ;;
    *)
      plume_err "unknown project env subcommand: ${sub}"
      return 2
      ;;
  esac
}

cmd_project() {
  local sub="${1:-help}"
  shift || true

  case "${sub}" in
    init) cmd_project_init "$@" ;;
    env) cmd_project_env "$@" ;;
    help|-h|--help) plume_project_usage ;;
    *)
      plume_err "unknown project subcommand: ${sub}"
      plume_project_usage
      return 2
      ;;
  esac
}
