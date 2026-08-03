#!/usr/bin/env bash
set -euo pipefail

# Phase-16 MVP: project-local plume.yml v2 (mode, php_version, type).
# Full schema lives in implementation/03-config-yaml-draft.md; only a subset is loaded here.

plume_yml_trim() {
  local s="$1"
  s="${s%%#*}"
  printf '%s' "${s}" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g'
}

plume_yml_unquote() {
  local v="$1"
  v="${v#\"}"; v="${v%\"}"
  v="${v#\'}"; v="${v%\'}"
  printf '%s' "${v}"
}

plume_yml_manifest_basename() {
  local configured="${PLUME_CONFIG_FILE:-plume.yml}"
  if [[ "${configured}" == */* ]]; then
    basename "${configured}"
  else
    printf '%s' "${configured}"
  fi
}

plume_yml_manifest_path() {
  local project_root="$1"
  local configured="${PLUME_CONFIG_FILE:-plume.yml}"
  local path=""

  if [[ "${configured}" = /* ]]; then
    path="${configured}"
  else
    path="${project_root%/}/${configured}"
  fi

  if [[ ! -f "${path}" ]]; then
    return 1
  fi

  printf '%s' "${path}"
}

plume_yml_root_scalar() {
  local file="$1"
  local key="$2"

  if [[ ! -f "${file}" ]]; then
    return 1
  fi

  local line trimmed
  while IFS= read -r line; do
    [[ "${line}" =~ ^[[:space:]] ]] && continue
    trimmed="$(plume_yml_trim "${line}")"
    [[ -z "${trimmed}" ]] && continue
    [[ "${trimmed}" == "${key}:"* ]] || continue
    local val="${trimmed#${key}:}"
    val="$(plume_yml_trim "${val}")"
    val="$(plume_yml_unquote "${val}")"
    [[ -n "${val}" ]] || return 1
    printf '%s' "${val}"
    return 0
  done < "${file}"

  return 1
}

# Scalar under `project:` (two-space indent keys).
plume_yml_project_scalar() {
  local file="$1"
  local key="$2"

  if [[ ! -f "${file}" ]]; then
    return 1
  fi

  local line trimmed in_project="false"
  while IFS= read -r line; do
    trimmed="$(plume_yml_trim "${line}")"
    [[ -z "${trimmed}" ]] && continue

    if [[ "${trimmed}" == "project:" ]]; then
      in_project="true"
      continue
    fi

    if [[ "${in_project}" == "true" && "${line}" =~ ^[^[:space:]] ]]; then
      in_project="false"
    fi

    [[ "${in_project}" == "true" ]] || continue
    [[ "${line}" =~ ^[[:space:]][[:space:]] ]] || continue

    if [[ "${trimmed}" == "${key}:"* ]]; then
      local val="${trimmed#${key}:}"
      val="$(plume_yml_trim "${val}")"
      val="$(plume_yml_unquote "${val}")"
      [[ -n "${val}" ]] || return 1
      printf '%s' "${val}"
      return 0
    fi
  done < "${file}"

  return 1
}

plume_yml_project_mode() {
  local project_root="$1"
  local file mode=""

  if ! file="$(plume_yml_manifest_path "${project_root}")"; then
    return 1
  fi

  if mode="$(plume_yml_project_scalar "${file}" mode)"; then
    printf '%s' "${mode}"
    return 0
  fi

  if mode="$(plume_yml_root_scalar "${file}" mode)"; then
    printf '%s' "${mode}"
    return 0
  fi

  return 1
}

plume_yml_project_php_version() {
  local project_root="$1"
  local file val=""

  if ! file="$(plume_yml_manifest_path "${project_root}")"; then
    return 1
  fi

  if val="$(plume_yml_project_scalar "${file}" php_version)"; then
    printf '%s' "${val}"
    return 0
  fi

  return 1
}

plume_yml_project_type() {
  local project_root="$1"
  local file val=""

  if ! file="$(plume_yml_manifest_path "${project_root}")"; then
    return 1
  fi

  if val="$(plume_yml_project_scalar "${file}" type)"; then
    printf '%s' "${val}"
    return 0
  fi

  return 1
}

plume_yml_validate_project_type() {
  local type="$1"
  case "${type}" in
    laravel|generic-php|static) return 0 ;;
    *) return 1 ;;
  esac
}

plume_yml_schema_version() {
  local project_root="$1"
  local file val=""

  if ! file="$(plume_yml_manifest_path "${project_root}")"; then
    return 1
  fi

  if val="$(plume_yml_root_scalar "${file}" version)"; then
    printf '%s' "${val}"
    return 0
  fi

  return 1
}
