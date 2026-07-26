#!/usr/bin/env bash
set -euo pipefail

plume_backup_dir() {
  printf '%s' "$(plume_state_dir)/backups"
}

plume_backup_parse_mode() {
  if declare -F plume_services_parse_mode >/dev/null 2>&1; then
    plume_services_parse_mode "$@"
    return $?
  fi
  if declare -F plume_mode_current >/dev/null 2>&1; then
    plume_mode_current
    return 0
  fi
  printf '%s' "native"
}

plume_backup_scope_from_args() {
  local scope="all"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --scope=*) scope="${arg#*=}" ;;
    esac
  done
  case "${scope}" in
    all|config|db) ;;
    *)
      plume_err "invalid --scope value: ${scope} (use all|config|db)"
      return 2
      ;;
  esac
  printf '%s' "${scope}"
}

plume_backup_name_from_args() {
  local name=""
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --name=*) name="${arg#*=}" ;;
    esac
  done
  printf '%s' "${name}"
}

plume_backup_output_dir_from_args() {
  local output
  output="$(plume_backup_dir)"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --output-dir=*) output="${arg#*=}" ;;
    esac
  done
  printf '%s' "${output}"
}

plume_backup_resolve_file() {
  local ref="${1:-}"
  local dir
  dir="$(plume_backup_dir)"
  [[ -n "${ref}" ]] || return 1
  if [[ -f "${ref}" ]]; then
    printf '%s' "${ref}"
    return 0
  fi
  if [[ -f "${dir}/${ref}" ]]; then
    printf '%s' "${dir}/${ref}"
    return 0
  fi
  if [[ -f "${dir}/${ref}.tar.gz" ]]; then
    printf '%s' "${dir}/${ref}.tar.gz"
    return 0
  fi
  return 1
}

cmd_backup_create() {
  local mode scope name output_dir
  if ! mode="$(plume_backup_parse_mode "$@")"; then
    return 2
  fi
  if ! scope="$(plume_backup_scope_from_args "$@")"; then
    return 2
  fi
  name="$(plume_backup_name_from_args "$@")"
  output_dir="$(plume_backup_output_dir_from_args "$@")"
  if [[ "${output_dir}" != /* ]]; then
    output_dir="$(cd "${output_dir}" 2>/dev/null && pwd || true)"
  fi
  [[ -n "${output_dir}" ]] || {
    plume_err "invalid --output-dir"
    return 2
  }
  mkdir -p "${output_dir}"

  local backup_id ts archive_path
  ts="$(date '+%Y%m%d-%H%M%S')"
  if [[ -n "${name}" ]]; then
    backup_id="backup-${name}-${ts}"
  else
    backup_id="backup-${mode}-${ts}"
  fi
  archive_path="${output_dir}/${backup_id}.tar.gz"

  local tmp_root
  tmp_root="$(mktemp -d)"

  mkdir -p "${tmp_root}/config" "${tmp_root}/db"
  cat > "${tmp_root}/metadata.env" <<EOF_META
BACKUP_ID=${backup_id}
MODE=${mode}
SCOPE=${scope}
CREATED_AT=$(date '+%Y-%m-%d %H:%M:%S')
STATE_DIR=$(plume_state_dir)
EOF_META

  local state_dir
  state_dir="$(plume_state_dir)"
  if [[ "${scope}" == "all" || "${scope}" == "config" ]]; then
    if [[ -d "${state_dir}" ]]; then
      local entry base
      shopt -s dotglob nullglob
      for entry in "${state_dir}"/*; do
        base="$(basename "${entry}")"
        [[ "${base}" == "backups" ]] && continue
        [[ "${base}" == "plume-state.db" ]] && continue
        cp -R "${entry}" "${tmp_root}/config/" 2>/dev/null || true
      done
      shopt -u dotglob nullglob
    fi
  fi

  if [[ "${scope}" == "all" || "${scope}" == "db" ]]; then
    local db_file
    db_file="$(plume_state_db_file)"
    if [[ -f "${db_file}" ]]; then
      cp "${db_file}" "${tmp_root}/db/plume-state.db"
    fi
  fi

  tar -czf "${archive_path}" -C "${tmp_root}" .
  rm -rf "${tmp_root}"
  plume_audit_event "${mode}" "backup.create.ok" "id=${backup_id},scope=${scope},file=${archive_path}"
  if [[ "${PLUME_OUTPUT:-text}" == "json" ]]; then
    printf '{"ok":true,"command":"backup create","data":{"id":"%s","scope":"%s","file":"%s"},"warnings":[],"errors":[]}\n' \
      "${backup_id}" "${scope}" "${archive_path}"
    return 0
  fi
  plume_info "backup created: ${backup_id}"
  plume_info "file: ${archive_path}"
  printf '%s\n' "${backup_id}"
}

cmd_backup_list() {
  local mode
  if ! mode="$(plume_backup_parse_mode "$@")"; then
    return 2
  fi
  local dir
  dir="$(plume_backup_dir)"
  mkdir -p "${dir}"
  if [[ "${PLUME_OUTPUT:-text}" == "json" ]]; then
    local first="true"
    printf '{"ok":true,"command":"backup list","data":{"mode":"%s","backups":[' "${mode}"
    local file id
    shopt -s nullglob
    for file in "${dir}"/*.tar.gz; do
      id="$(basename "${file}" .tar.gz)"
      if [[ "${first}" == "true" ]]; then
        first="false"
      else
        printf ','
      fi
      printf '{"id":"%s","file":"%s"}' "${id}" "${file}"
    done
    shopt -u nullglob
    printf ']},"warnings":[],"errors":[]}\n'
    return 0
  fi
  printf 'MODE              %s\n' "${mode}"
  printf 'BACKUP_DIR        %s\n' "${dir}"
  echo "ID                              FILE"
  echo "------------------------------  ----------------------------------------"
  local file id
  shopt -s nullglob
  for file in "${dir}"/*.tar.gz; do
    id="$(basename "${file}" .tar.gz)"
    printf '%-30s  %s\n' "${id}" "${file}"
  done
  shopt -u nullglob
}

cmd_backup_show() {
  local mode ref file
  if ! mode="$(plume_backup_parse_mode "$@")"; then
    return 2
  fi
  ref="${1:-}"
  if [[ -z "${ref}" || "${ref}" == --* ]]; then
    plume_err "backup reference required (id or file)"
    return 2
  fi
  if ! file="$(plume_backup_resolve_file "${ref}")"; then
    plume_err "backup not found: ${ref}"
    return 2
  fi
  local metadata
  metadata="$(tar -xOf "${file}" metadata.env 2>/dev/null || true)"
  printf 'MODE              %s\n' "${mode}"
  printf 'BACKUP_FILE       %s\n' "${file}"
  if [[ -n "${metadata}" ]]; then
    printf '%s\n' "${metadata}"
  fi
}

cmd_backup_restore() {
  local mode ref file dry_run="false"
  if ! mode="$(plume_backup_parse_mode "$@")"; then
    return 2
  fi
  ref="${1:-}"
  if [[ -z "${ref}" || "${ref}" == --* ]]; then
    plume_err "backup reference required (id or file)"
    return 2
  fi
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --dry-run) dry_run="true" ;;
    esac
  done
  if ! file="$(plume_backup_resolve_file "${ref}")"; then
    plume_err "backup not found: ${ref}"
    return 2
  fi

  local tmp_root state_dir
  tmp_root="$(mktemp -d)"
  tar -xzf "${file}" -C "${tmp_root}"
  state_dir="$(plume_state_dir)"
  mkdir -p "${state_dir}"

  if [[ "${dry_run}" == "true" ]]; then
    plume_info "backup restore dry-run: ${file}"
    [[ -d "${tmp_root}/config" ]] && plume_info "would restore: config/* -> ${state_dir}"
    [[ -f "${tmp_root}/db/plume-state.db" ]] && plume_info "would restore: db/plume-state.db -> $(plume_state_db_file)"
    rm -rf "${tmp_root}"
    return 0
  fi

  if ! plume_require_yes_for_critical "${mode}" "critical.backup.restore" "file=${file}" "Use --yes backup restore <id|file>"; then
    rm -rf "${tmp_root}"
    return 2
  fi

  if [[ -d "${tmp_root}/config" ]]; then
    cp -R "${tmp_root}/config/." "${state_dir}/"
  fi
  if [[ -f "${tmp_root}/db/plume-state.db" ]]; then
    cp "${tmp_root}/db/plume-state.db" "$(plume_state_db_file)"
  fi
  rm -rf "${tmp_root}"
  plume_audit_event "${mode}" "backup.restore.ok" "file=${file}"
  plume_info "backup restored: ${file}"
}

cmd_backup() {
  local sub="${1:-list}"
  shift || true
  case "${sub}" in
    create) cmd_backup_create "$@" ;;
    list) cmd_backup_list "$@" ;;
    show) cmd_backup_show "$@" ;;
    restore) cmd_backup_restore "$@" ;;
    *)
      plume_err "unknown backup subcommand: ${sub} (use create|list|show|restore)"
      return 2
      ;;
  esac
}
