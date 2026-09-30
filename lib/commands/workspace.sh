#!/usr/bin/env bash
set -euo pipefail

# Phase 27 / D-154 — Composer + Node workspace CLI (Herd-like).
# Native: host binaries with site PHP on PATH for composer.
# docker-lite / laradock-bridge: exec into workspace container.

plume_workspace_usage() {
  cat <<'EOF'
plumectl composer|npm|node [plume options] [--] <tool args...>

Plume options:
  --path=</abs/project>   Project root (composer.json / package.json / artisan)
  --site=<site-id>        Use registered site path (+ PHP version for composer)
  --mode=native|docker-lite|laradock-bridge

Examples:
  plumectl composer install
  plumectl composer --path=/var/www/app require laravel/horizon
  plumectl npm install
  plumectl npm run build
  plumectl node -v
EOF
}

plume_workspace_parse_plume_flags() {
  PLUME_WORKSPACE_PATH=""
  PLUME_WORKSPACE_SITE_ID=""
  PLUME_WORKSPACE_MODE=""
  PLUME_WORKSPACE_TOOL_ARGS=()
  local after_delim="false" arg
  for arg in "$@"; do
    if [[ "${after_delim}" == "true" ]]; then
      PLUME_WORKSPACE_TOOL_ARGS+=("${arg}")
      continue
    fi
    case "${arg}" in
      --)
        after_delim="true"
        ;;
      --path=*)
        PLUME_WORKSPACE_PATH="${arg#*=}"
        ;;
      --site=*)
        PLUME_WORKSPACE_SITE_ID="${arg#*=}"
        ;;
      --mode=*)
        PLUME_WORKSPACE_MODE="${arg#*=}"
        ;;
      -h|--help)
        # Only treat as Plume help when no tool args yet and sole intent is help.
        if [[ ${#PLUME_WORKSPACE_TOOL_ARGS[@]} -eq 0 ]]; then
          plume_workspace_usage
          return 100
        fi
        PLUME_WORKSPACE_TOOL_ARGS+=("${arg}")
        ;;
      --path|--site|--mode)
        plume_err "${arg} requires =value (e.g. ${arg}=/path)"
        return 2
        ;;
      *)
        # All other flags/positionals belong to composer|npm|node (Herd-like).
        PLUME_WORKSPACE_TOOL_ARGS+=("${arg}")
        ;;
    esac
  done
  return 0
}

plume_workspace_resolve_mode() {
  if [[ -n "${PLUME_WORKSPACE_MODE}" ]]; then
    printf '%s' "${PLUME_WORKSPACE_MODE}"
    return 0
  fi
  plume_mode_current
}

plume_workspace_to_abs_path() {
  local raw="$1"
  if [[ "${raw}" == /* ]]; then
    printf '%s' "${raw}"
    return 0
  fi
  (cd "${raw}" 2>/dev/null && pwd) || return 1
}

plume_workspace_resolve_project_path() {
  local tool="$1"
  local cwd path file id mode active_path

  if [[ -n "${PLUME_WORKSPACE_PATH}" ]]; then
    path="$(plume_workspace_to_abs_path "${PLUME_WORKSPACE_PATH}")" || {
      plume_err "invalid --path: ${PLUME_WORKSPACE_PATH}"
      return 2
    }
    printf '%s' "${path}"
    return 0
  fi

  if [[ -n "${PLUME_WORKSPACE_SITE_ID}" ]]; then
    if ! declare -F plume_sites_exists >/dev/null 2>&1 || ! plume_sites_exists "${PLUME_WORKSPACE_SITE_ID}"; then
      plume_err "site not found: ${PLUME_WORKSPACE_SITE_ID}"
      return 2
    fi
    file="$(plume_sites_file "${PLUME_WORKSPACE_SITE_ID}")"
    path="$(plume_sites_record_value "${file}" path)"
    if [[ -z "${path}" || ! -d "${path}" ]]; then
      plume_err "site ${PLUME_WORKSPACE_SITE_ID} has no valid path"
      return 2
    fi
    PLUME_LARAVEL_SITE_ID="${PLUME_WORKSPACE_SITE_ID}"
    printf '%s' "${path}"
    return 0
  fi

  cwd="$(pwd -P 2>/dev/null || pwd)"
  if declare -F plume_sites_index_ids >/dev/null 2>&1; then
    while IFS= read -r id; do
      [[ -z "${id}" ]] && continue
      file="$(plume_sites_file "${id}" 2>/dev/null || true)"
      [[ -f "${file}" ]] || continue
      path="$(plume_sites_record_value "${file}" path)"
      [[ -n "${path}" ]] || continue
      if [[ "${cwd}" == "${path}" || "${cwd}" == "${path}/"* ]]; then
        PLUME_LARAVEL_SITE_ID="${id}"
        printf '%s' "${path}"
        return 0
      fi
    done < <(plume_sites_index_ids)
  fi

  case "${tool}" in
    composer)
      if [[ -f "${cwd}/composer.json" || -f "${cwd}/artisan" ]]; then
        printf '%s' "${cwd}"
        return 0
      fi
      ;;
    npm)
      # Do not accept bare cwd: Plume repo / random dirs have no package.json (ENOENT).
      if [[ -f "${cwd}/package.json" || -f "${cwd}/artisan" ]]; then
        printf '%s' "${cwd}"
        return 0
      fi
      ;;
    node)
      if [[ -f "${cwd}/package.json" || -f "${cwd}/artisan" || -f "${cwd}/composer.json" ]]; then
        printf '%s' "${cwd}"
        return 0
      fi
      ;;
  esac

  mode="$(plume_workspace_resolve_mode)"
  if declare -F plume_mode_path_get >/dev/null 2>&1; then
    active_path="$(plume_mode_path_get "${mode}" || true)"
    if [[ -n "${active_path}" ]]; then
      if path="$(plume_workspace_to_abs_path "${active_path}" 2>/dev/null || true)" && [[ -n "${path}" && -d "${path}" ]]; then
        case "${tool}" in
          npm)
            if [[ -f "${path}/package.json" || -f "${path}/artisan" ]]; then
              printf '%s' "${path}"
              return 0
            fi
            ;;
          composer)
            if [[ -f "${path}/composer.json" || -f "${path}/artisan" ]]; then
              printf '%s' "${path}"
              return 0
            fi
            ;;
          *)
            printf '%s' "${path}"
            return 0
            ;;
        esac
      fi
    fi
  fi

  # node -p / one-liners: allow cwd without a package.json
  if [[ "${tool}" == "node" ]]; then
    printf '%s' "${cwd}"
    return 0
  fi

  plume_err "could not resolve project path for ${tool} (use --path=, --site=, or run from a Laravel/Node project root with package.json|composer.json|artisan)"
  return 2
}

plume_workspace_composer_bin() {
  printf '%s' "${PLUME_COMPOSER_BIN:-composer}"
}

plume_workspace_npm_bin() {
  printf '%s' "${PLUME_NPM_BIN:-npm}"
}

plume_workspace_node_bin() {
  printf '%s' "${PLUME_NODE_BIN:-node}"
}

plume_workspace_run_native() {
  local tool="$1"
  local project_path="$2"
  shift 2
  local php_bin composer_bin npm_bin node_bin php_dir

  case "${tool}" in
    composer)
      composer_bin="$(plume_workspace_composer_bin)"
      if ! command -v "${composer_bin}" >/dev/null 2>&1 && [[ ! -x "${composer_bin}" ]]; then
        plume_err "composer not found (${composer_bin}); install Composer or set PLUME_COMPOSER_BIN"
        return 2
      fi
      php_bin=""
      if declare -F plume_laravel_resolve_php_bin >/dev/null 2>&1; then
        php_bin="$(plume_laravel_resolve_php_bin 2>/dev/null || true)"
      fi
      if [[ -z "${php_bin}" ]]; then
        php_bin="${PLUME_PHP_BIN:-php}"
      fi
      if ! command -v "${php_bin}" >/dev/null 2>&1 && [[ ! -x "${php_bin}" ]]; then
        plume_err "php not found for composer (${php_bin})"
        return 2
      fi
      php_dir="$(dirname "${php_bin}")"
      (
        cd "${project_path}"
        # Prefer site/default PHP ahead of PATH (Herd-like).
        PATH="${php_dir}:${PATH}"
        export PATH
        if [[ "${php_bin}" == /* || "${php_bin}" == ./* ]]; then
          export COMPOSER_PHP="${php_bin}"
        fi
        exec "${composer_bin}" "$@"
      )
      ;;
    npm)
      npm_bin="$(plume_workspace_npm_bin)"
      if ! command -v "${npm_bin}" >/dev/null 2>&1 && [[ ! -x "${npm_bin}" ]]; then
        plume_err "npm not found (${npm_bin}); install Node.js or set PLUME_NPM_BIN"
        return 2
      fi
      (
        cd "${project_path}"
        exec "${npm_bin}" "$@"
      )
      ;;
    node)
      node_bin="$(plume_workspace_node_bin)"
      if ! command -v "${node_bin}" >/dev/null 2>&1 && [[ ! -x "${node_bin}" ]]; then
        plume_err "node not found (${node_bin}); install Node.js or set PLUME_NODE_BIN"
        return 2
      fi
      (
        cd "${project_path}"
        exec "${node_bin}" "$@"
      )
      ;;
    *)
      plume_err "unknown workspace tool: ${tool}"
      return 2
      ;;
  esac
}

plume_workspace_compose_exec_tool() {
  local mode="$1"
  local tool="$2"
  shift 2
  local compose_file compose_service tty_flag="-T"

  case "${mode}" in
    docker-lite)
      compose_file="$(plume_docker_lite_compose_file 2>/dev/null || true)"
      compose_service="$(plume_docker_lite_service_name composer 2>/dev/null || echo workspace)"
      ;;
    laradock-bridge)
      if declare -F plume_services_laradock_runtime_prepare >/dev/null 2>&1; then
        plume_services_laradock_runtime_prepare --mode=laradock-bridge || true
      fi
      compose_file="$(plume_laradock_bridge_compose_file_runtime 2>/dev/null || true)"
      compose_service="$(plume_laradock_bridge_service_name composer 2>/dev/null || echo workspace)"
      ;;
    *)
      plume_err "unsupported mode for workspace exec: ${mode}"
      return 2
      ;;
  esac

  if [[ -z "${compose_file}" || ! -f "${compose_file}" ]]; then
    plume_err "${mode} compose file not found (init workspace / set mode path)"
    return 2
  fi
  if ! declare -F plume_docker_compose_exec >/dev/null 2>&1; then
    plume_err "docker compose helper unavailable"
    return 2
  fi

  # shellcheck disable=SC2086
  plume_docker_compose_exec "${compose_file}" exec ${tty_flag} "${compose_service}" "${tool}" "$@"
}

plume_workspace_run_tool() {
  local tool="$1"
  shift
  local rc=0 mode project_path

  if ! plume_workspace_parse_plume_flags "$@"; then
    rc=$?
    if [[ "${rc}" -eq 100 ]]; then
      return 0
    fi
    return "${rc}"
  fi

  mode="$(plume_workspace_resolve_mode)"
  case "${mode}" in
    native|docker-lite|laradock-bridge) ;;
    *)
      plume_err "invalid --mode: ${mode}"
      return 2
      ;;
  esac

  if ! project_path="$(plume_workspace_resolve_project_path "${tool}")"; then
    return 2
  fi

  if [[ "${#PLUME_WORKSPACE_TOOL_ARGS[@]}" -eq 0 ]]; then
    case "${tool}" in
      # Avoid plumectl global -v/--version swallowing tool version flags.
      composer) PLUME_WORKSPACE_TOOL_ARGS=(-V) ;;
      npm) PLUME_WORKSPACE_TOOL_ARGS=(help) ;;
      node) PLUME_WORKSPACE_TOOL_ARGS=(-p 'process.version') ;;
    esac
  fi

  plume_info "workspace ${tool}: mode=${mode} path=${project_path}"

  case "${mode}" in
    native)
      plume_workspace_run_native "${tool}" "${project_path}" "${PLUME_WORKSPACE_TOOL_ARGS[@]}"
      ;;
    docker-lite|laradock-bridge)
      plume_workspace_compose_exec_tool "${mode}" "${tool}" "${PLUME_WORKSPACE_TOOL_ARGS[@]}"
      ;;
  esac
}

cmd_composer() {
  plume_workspace_run_tool composer "$@"
}

cmd_npm() {
  plume_workspace_run_tool npm "$@"
}

cmd_node() {
  plume_workspace_run_tool node "$@"
}
