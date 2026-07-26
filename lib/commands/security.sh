#!/usr/bin/env bash
set -euo pipefail

plume_security_parse_mode() {
  if declare -F plume_services_parse_mode >/dev/null 2>&1; then
    plume_services_parse_mode "$@"
    return $?
  fi
  plume_mode_current
}

plume_security_secrets_file() {
  printf '%s' "$(plume_state_dir)/secrets.env"
}

plume_security_secret_key_valid() {
  local key="${1:-}"
  [[ "${key}" =~ ^[A-Z0-9_]+$ ]]
}

plume_security_secrets_ensure_file() {
  local file
  file="$(plume_security_secrets_file)"
  mkdir -p "$(dirname "${file}")"
  if [[ ! -f "${file}" ]]; then
    : > "${file}"
  fi
  chmod 600 "${file}" 2>/dev/null || true
}

plume_security_secrets_get_value() {
  local key="$1"
  local file line
  file="$(plume_security_secrets_file)"
  [[ -f "${file}" ]] || return 1
  line="$(grep -E "^${key}=" "${file}" 2>/dev/null | tail -n 1 || true)"
  [[ -n "${line}" ]] || return 1
  printf '%s' "${line#*=}"
}

plume_security_secrets_set_value() {
  local key="$1"
  local value="$2"
  local file tmp
  file="$(plume_security_secrets_file)"
  plume_security_secrets_ensure_file
  tmp="$(mktemp)"
  grep -Ev "^${key}=" "${file}" > "${tmp}" 2>/dev/null || true
  printf '%s=%s\n' "${key}" "${value}" >> "${tmp}"
  mv "${tmp}" "${file}"
  chmod 600 "${file}" 2>/dev/null || true
}

plume_security_secrets_unset_value() {
  local key="$1"
  local file tmp
  file="$(plume_security_secrets_file)"
  plume_security_secrets_ensure_file
  tmp="$(mktemp)"
  grep -Ev "^${key}=" "${file}" > "${tmp}" 2>/dev/null || true
  mv "${tmp}" "${file}"
  chmod 600 "${file}" 2>/dev/null || true
}

plume_security_certs_dir() {
  printf '%s' "$(plume_state_dir)/certs"
}

plume_security_certs_ensure_dir() {
  mkdir -p "$(plume_security_certs_dir)"
}

plume_security_cert_sanitize_name() {
  local input="${1:-cert}"
  printf '%s' "${input}" | tr -cs 'A-Za-z0-9._-' '-'
}

plume_security_cert_parse_domains() {
  local domains_csv="${1:-}"
  local cleaned
  cleaned="$(printf '%s' "${domains_csv}" | tr -d ' ')"
  [[ -n "${cleaned}" ]] || return 1
  printf '%s' "${cleaned}"
}

plume_security_cert_domains_to_san() {
  local domains_csv="$1"
  local san=""
  local d
  IFS=',' read -r -a _domains_arr <<< "${domains_csv}"
  for d in "${_domains_arr[@]}"; do
    [[ -z "${d}" ]] && continue
    if [[ -n "${san}" ]]; then
      san="${san},"
    fi
    san="${san}DNS:${d}"
  done
  printf '%s' "${san}"
}

plume_security_cert_find_path() {
  local ref="${1:-}"
  local dir
  dir="$(plume_security_certs_dir)"
  [[ -n "${ref}" ]] || return 1
  if [[ -d "${ref}" && -f "${ref}/metadata.env" ]]; then
    printf '%s' "${ref}"
    return 0
  fi
  if [[ -d "${dir}/${ref}" && -f "${dir}/${ref}/metadata.env" ]]; then
    printf '%s' "${dir}/${ref}"
    return 0
  fi
  return 1
}

cmd_security_check() {
  local mode skip_prereq
  if ! mode="$(plume_security_parse_mode "$@")"; then
    return 2
  fi
  skip_prereq="false"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --skip-prereq) skip_prereq="true" ;;
    esac
  done

  local prereq_rc=0
  if [[ "${skip_prereq}" != "true" ]]; then
    set +e
    cmd_prereq check --profile=security-check >/dev/null 2>&1
    prereq_rc=$?
    set -e
  fi

  local os firewall_status firewall_detail
  os="$(plume_detect_os)"
  firewall_status="unknown"
  firewall_detail="-"

  if [[ "${os}" == "macos" ]]; then
    if command -v pfctl >/dev/null 2>&1; then
      set +e
      firewall_detail="$(pfctl -s info 2>/dev/null | awk -F: '/Status/{gsub(/^ /, "", $2); print $2; exit}')"
      set -e
      firewall_detail="${firewall_detail:-available}"
      firewall_status="checked"
    else
      firewall_status="missing"
      firewall_detail="pfctl not found"
    fi
  elif [[ "${os}" == "linux" ]]; then
    if command -v ufw >/dev/null 2>&1; then
      set +e
      firewall_detail="$(ufw status 2>/dev/null | head -n 1)"
      set -e
      firewall_detail="${firewall_detail:-ufw available}"
      firewall_status="checked"
    elif command -v firewall-cmd >/dev/null 2>&1; then
      set +e
      firewall_detail="$(firewall-cmd --state 2>/dev/null)"
      set -e
      firewall_detail="${firewall_detail:-firewalld available}"
      firewall_status="checked"
    elif command -v iptables >/dev/null 2>&1; then
      firewall_status="checked"
      firewall_detail="iptables available"
    else
      firewall_status="missing"
      firewall_detail="no firewall CLI found"
    fi
  fi

  printf 'MODE              %s\n' "${mode}"
  printf 'OS                %s\n' "${os}"
  printf 'PREREQ            %s\n' "$(if [[ "${prereq_rc}" -eq 0 ]]; then printf 'ok'; else printf 'fail'; fi)"
  printf 'FIREWALL          %s\n' "${firewall_status}"
  printf 'DETAIL            %s\n' "${firewall_detail}"

  if [[ "${prereq_rc}" -ne 0 ]]; then
    plume_audit_event "${mode}" "security.check.fail" "prereq=fail"
    return 2
  fi
  plume_audit_event "${mode}" "security.check.ok" "firewall=${firewall_status}"
}

cmd_security_secrets_list() {
  local mode file
  if ! mode="$(plume_security_parse_mode "$@")"; then
    return 2
  fi
  file="$(plume_security_secrets_file)"
  plume_security_secrets_ensure_file
  printf 'MODE              %s\n' "${mode}"
  printf 'SECRETS_FILE      %s\n' "${file}"
  echo "KEY"
  echo "------------------------------"
  awk -F= 'NF>=2 {print $1}' "${file}" | sort -u
  plume_audit_event "${mode}" "security.secret.list" "file=${file}"
}

cmd_security_secrets_get() {
  local mode key value
  if ! mode="$(plume_security_parse_mode "$@")"; then
    return 2
  fi
  key="${1:-}"
  if [[ -z "${key}" ]]; then
    plume_err "secret key required"
    return 2
  fi
  if ! plume_security_secret_key_valid "${key}"; then
    plume_err "invalid secret key: ${key} (use [A-Z0-9_])"
    return 2
  fi
  if ! value="$(plume_security_secrets_get_value "${key}")"; then
    plume_err "secret not found: ${key}"
    return 2
  fi
  printf '%s\n' "${value}"
  plume_audit_event "${mode}" "security.secret.get" "key=${key}"
}

cmd_security_secrets_set() {
  local mode key value
  if ! mode="$(plume_security_parse_mode "$@")"; then
    return 2
  fi
  key="${1:-}"
  value="${2:-}"
  if [[ -z "${key}" || -z "${value}" ]]; then
    plume_err "usage: security secrets set <KEY> <VALUE>"
    return 2
  fi
  if ! plume_security_secret_key_valid "${key}"; then
    plume_err "invalid secret key: ${key} (use [A-Z0-9_])"
    return 2
  fi
  plume_security_secrets_set_value "${key}" "${value}"
  plume_audit_event "${mode}" "security.secret.set" "key=${key}"
  plume_info "secret set: ${key}"
}

cmd_security_secrets_unset() {
  local mode key
  if ! mode="$(plume_security_parse_mode "$@")"; then
    return 2
  fi
  key="${1:-}"
  if [[ -z "${key}" ]]; then
    plume_err "usage: security secrets unset <KEY>"
    return 2
  fi
  if ! plume_security_secret_key_valid "${key}"; then
    plume_err "invalid secret key: ${key} (use [A-Z0-9_])"
    return 2
  fi
  plume_security_secrets_unset_value "${key}"
  plume_audit_event "${mode}" "security.secret.unset" "key=${key}"
  plume_info "secret removed: ${key}"
}

cmd_security_secrets_generate() {
  local mode key length
  if ! mode="$(plume_security_parse_mode "$@")"; then
    return 2
  fi
  key="${1:-}"
  length="32"
  local arg
  shift || true
  for arg in "$@"; do
    case "${arg}" in
      --length=*) length="${arg#*=}" ;;
    esac
  done
  if [[ -z "${key}" ]]; then
    plume_err "usage: security secrets generate <KEY> [--length=32]"
    return 2
  fi
  if ! plume_security_secret_key_valid "${key}"; then
    plume_err "invalid secret key: ${key} (use [A-Z0-9_])"
    return 2
  fi
  if ! printf '%s' "${length}" | grep -Eq '^[0-9]+$'; then
    plume_err "invalid --length value: ${length}"
    return 2
  fi
  local value
  if command -v openssl >/dev/null 2>&1; then
    value="$(openssl rand -hex $(( (length + 1) / 2 )) | cut -c1-"${length}")"
  else
    value="$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c "${length}")"
  fi
  plume_security_secrets_set_value "${key}" "${value}"
  plume_audit_event "${mode}" "security.secret.generate" "key=${key},length=${length}"
  printf '%s\n' "${value}"
}

cmd_security_secrets() {
  local sub="${1:-list}"
  shift || true
  case "${sub}" in
    list) cmd_security_secrets_list "$@" ;;
    get) cmd_security_secrets_get "$@" ;;
    set) cmd_security_secrets_set "$@" ;;
    unset) cmd_security_secrets_unset "$@" ;;
    generate) cmd_security_secrets_generate "$@" ;;
    *)
      plume_err "unknown security secrets subcommand: ${sub} (use list|get|set|unset|generate)"
      return 2
      ;;
  esac
}

cmd_security_cert_issue() {
  local mode domains_csv days primary cert_id cert_dir key_file crt_file san_ext_file
  if ! mode="$(plume_security_parse_mode "$@")"; then
    return 2
  fi
  domains_csv=""
  days="30"
  cert_id=""
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --domains=*) domains_csv="${arg#*=}" ;;
      --days=*) days="${arg#*=}" ;;
      --name=*) cert_id="${arg#*=}" ;;
    esac
  done
  if ! domains_csv="$(plume_security_cert_parse_domains "${domains_csv}")"; then
    plume_err "usage: security cert issue --domains=example.test,www.example.test [--days=30] [--name=custom-id]"
    return 2
  fi
  if ! printf '%s' "${days}" | grep -Eq '^[0-9]+$'; then
    plume_err "invalid --days value: ${days}"
    return 2
  fi
  if ! command -v openssl >/dev/null 2>&1; then
    plume_err "openssl is required for cert issue"
    return 2
  fi

  IFS=',' read -r -a _domains_primary <<< "${domains_csv}"
  primary="${_domains_primary[0]:-}"
  [[ -n "${primary}" ]] || {
    plume_err "invalid --domains list"
    return 2
  }

  if [[ -z "${cert_id}" ]]; then
    cert_id="cert-$(plume_security_cert_sanitize_name "${primary}")-$(date '+%Y%m%d-%H%M%S')"
  else
    cert_id="$(plume_security_cert_sanitize_name "${cert_id}")"
  fi

  plume_security_certs_ensure_dir
  cert_dir="$(plume_security_certs_dir)/${cert_id}"
  mkdir -p "${cert_dir}"
  key_file="${cert_dir}/cert.key"
  crt_file="${cert_dir}/cert.crt"
  san_ext_file="${cert_dir}/san.ext"

  cat > "${san_ext_file}" <<EOF_SAN
subjectAltName=$(plume_security_cert_domains_to_san "${domains_csv}")
EOF_SAN

  openssl req -x509 -nodes -newkey rsa:2048 \
    -keyout "${key_file}" \
    -out "${crt_file}" \
    -days "${days}" \
    -subj "/CN=${primary}" \
    -addext "$(cat "${san_ext_file}")" >/dev/null 2>&1

  chmod 600 "${key_file}" 2>/dev/null || true
  chmod 644 "${crt_file}" 2>/dev/null || true

  local not_after
  not_after="$(openssl x509 -enddate -noout -in "${crt_file}" 2>/dev/null | sed 's/notAfter=//')"
  cat > "${cert_dir}/metadata.env" <<EOF_META
ID=${cert_id}
MODE=${mode}
DOMAINS=${domains_csv}
PRIMARY_DOMAIN=${primary}
DAYS=${days}
CREATED_AT=$(date '+%Y-%m-%d %H:%M:%S')
NOT_AFTER=${not_after}
CRT_FILE=${crt_file}
KEY_FILE=${key_file}
EOF_META

  plume_audit_event "${mode}" "security.cert.issue.ok" "id=${cert_id},domains=${domains_csv},days=${days}"
  printf '%s\n' "${cert_id}"
}

cmd_security_cert_list() {
  local mode certs_dir d id domains not_after
  if ! mode="$(plume_security_parse_mode "$@")"; then
    return 2
  fi
  plume_security_certs_ensure_dir
  certs_dir="$(plume_security_certs_dir)"
  printf 'MODE              %s\n' "${mode}"
  printf 'CERTS_DIR         %s\n' "${certs_dir}"
  echo "ID                              DOMAINS                         NOT_AFTER"
  echo "------------------------------  ------------------------------  ------------------------------"
  shopt -s nullglob
  for d in "${certs_dir}"/*; do
    [[ -d "${d}" && -f "${d}/metadata.env" ]] || continue
    id="$(basename "${d}")"
    domains="$(grep -E '^DOMAINS=' "${d}/metadata.env" | head -n1 | cut -d= -f2-)"
    not_after="$(grep -E '^NOT_AFTER=' "${d}/metadata.env" | head -n1 | cut -d= -f2-)"
    printf '%-30s  %-30s  %s\n' "${id}" "${domains}" "${not_after}"
  done
  shopt -u nullglob
  plume_audit_event "${mode}" "security.cert.list" "dir=${certs_dir}"
}

cmd_security_cert_show() {
  local mode ref cert_dir
  if ! mode="$(plume_security_parse_mode "$@")"; then
    return 2
  fi
  ref="${1:-}"
  if [[ -z "${ref}" || "${ref}" == --* ]]; then
    plume_err "usage: security cert show <id>"
    return 2
  fi
  if ! cert_dir="$(plume_security_cert_find_path "${ref}")"; then
    plume_err "certificate not found: ${ref}"
    return 2
  fi
  printf 'MODE              %s\n' "${mode}"
  printf 'CERT_DIR          %s\n' "${cert_dir}"
  cat "${cert_dir}/metadata.env"
  plume_audit_event "${mode}" "security.cert.show" "id=$(basename "${cert_dir}")"
}

cmd_security_cert_renew() {
  local mode ref days cert_dir domains
  if ! mode="$(plume_security_parse_mode "$@")"; then
    return 2
  fi
  ref="${1:-}"
  if [[ -z "${ref}" || "${ref}" == --* ]]; then
    plume_err "usage: security cert renew <id> [--days=30]"
    return 2
  fi
  days="30"
  local arg
  shift || true
  for arg in "$@"; do
    case "${arg}" in
      --days=*) days="${arg#*=}" ;;
    esac
  done
  if ! printf '%s' "${days}" | grep -Eq '^[0-9]+$'; then
    plume_err "invalid --days value: ${days}"
    return 2
  fi
  if ! cert_dir="$(plume_security_cert_find_path "${ref}")"; then
    plume_err "certificate not found: ${ref}"
    return 2
  fi
  domains="$(grep -E '^DOMAINS=' "${cert_dir}/metadata.env" | head -n1 | cut -d= -f2-)"
  [[ -n "${domains}" ]] || {
    plume_err "certificate metadata invalid: missing DOMAINS"
    return 2
  }

  local cert_id
  cert_id="$(basename "${cert_dir}")"
  local issued
  issued="$(cmd_security_cert_issue --mode="${mode}" --domains="${domains}" --days="${days}" --name="${cert_id}")"
  [[ -n "${issued}" ]] || {
    plume_err "certificate renew failed: ${ref}"
    return 2
  }
  plume_audit_event "${mode}" "security.cert.renew.ok" "id=${cert_id},days=${days}"
  printf '%s\n' "${cert_id}"
}

cmd_security_cert() {
  local sub="${1:-list}"
  shift || true
  case "${sub}" in
    issue) cmd_security_cert_issue "$@" ;;
    list) cmd_security_cert_list "$@" ;;
    show) cmd_security_cert_show "$@" ;;
    renew) cmd_security_cert_renew "$@" ;;
    *)
      plume_err "unknown security cert subcommand: ${sub} (use issue|list|show|renew)"
      return 2
      ;;
  esac
}

cmd_security() {
  local sub="${1:-check}"
  shift || true
  case "${sub}" in
    check) cmd_security_check "$@" ;;
    secrets) cmd_security_secrets "$@" ;;
    cert) cmd_security_cert "$@" ;;
    *)
      plume_err "unknown security subcommand: ${sub} (use check|secrets|cert)"
      return 2
      ;;
  esac
}
