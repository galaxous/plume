#!/usr/bin/env bash
set -euo pipefail

# Interactive / non-interactive policy (CI: PLUME_NONINTERACTIVE=1 or global --yes).
plume_interactive_is_noninteractive() {
  if [[ "$(plume_bool "${PLUME_NONINTERACTIVE:-false}")" == "true" ]]; then
    return 0
  fi
  if [[ "$(plume_bool "${PLUME_ASSUME_YES:-false}")" == "true" ]]; then
    return 0
  fi
  if [[ "$(plume_bool "${PLUME_INTERACTIVE:-}")" == "false" ]]; then
    return 0
  fi
  return 1
}

plume_interactive_enabled() {
  if plume_interactive_is_noninteractive; then
    return 1
  fi
  if [[ "$(plume_bool "${PLUME_INTERACTIVE:-false}")" == "true" ]]; then
    return 0
  fi
  [[ -t 0 && -t 1 ]]
}

plume_interactive_confirm() {
  local prompt="$1"
  local default_no="${2:-true}"
  if plume_interactive_is_noninteractive; then
    return 1
  fi
  if ! plume_interactive_enabled; then
    return 1
  fi
  local suffix="[y/N]"
  if [[ "${default_no}" != "true" ]]; then
    suffix="[Y/n]"
  fi
  local reply=""
  read -r -p "${prompt} ${suffix} " reply </dev/tty || return 1
  case "${reply}" in
    [yY]|[yY][eE][sS]) return 0 ;;
    [nN]|[nN][oO]|"") return 1 ;;
    *)
      if [[ "${default_no}" != "true" && -z "${reply}" ]]; then
        return 0
      fi
      return 1
      ;;
  esac
}

plume_macos_permissions_suggest_sites_path() {
  local path="$1"
  local base=""
  base="$(basename "${path}")"
  [[ -n "${base}" ]] || base="my-app"
  printf '%s/Sites/%s' "${HOME}" "${base}"
}

plume_macos_permissions_path_label() {
  local path="$1"
  case "${path}" in
    *"/Desktop/"*|*"/Desktop") printf '%s' "Desktop" ;;
    *"/Documents/"*|*"/Documents") printf '%s' "Documents" ;;
    *"/Downloads/"*|*"/Downloads") printf '%s' "Downloads" ;;
    *) printf '%s' "TCC-sensitive" ;;
  esac
}

plume_macos_permissions_print_why() {
  local path="${1:-}"
  local label=""
  if [[ -n "${path}" ]]; then
    label="$(plume_macos_permissions_path_label "${path}")"
    echo "macOS privacy (TCC): this project is under ${label} (${path})."
  else
    echo "macOS privacy (TCC): one or more registered sites use Desktop, Documents, or Downloads."
  fi
  echo "nginx and php-fpm are separate processes — without Full Disk Access they often cannot read"
  echo "your Laravel public/index.php (browser: \"No input file specified\" or 404)."
  echo "Plume is a CLI script; add Homebrew nginx and php-fpm binaries in System Settings, not plume.sh."
}

plume_macos_permissions_open_fda_flow() {
  if declare -F plume_onboarding_macos_print_fda_binaries >/dev/null 2>&1; then
    plume_onboarding_macos_print_fda_binaries
  fi
  if declare -F plume_onboarding_macos_reveal_nginx_dir >/dev/null 2>&1; then
    plume_onboarding_macos_reveal_nginx_dir >/dev/null 2>&1 || true
  fi
  if declare -F plume_onboarding_macos_open_privacy_all_files >/dev/null 2>&1; then
    plume_onboarding_macos_open_privacy_all_files || plume_warn "could not open System Settings — use init permissions --open"
  fi
}

plume_macos_permissions_print_move_hint() {
  local path="$1"
  local suggested=""
  suggested="$(plume_macos_permissions_suggest_sites_path "${path}")"
  echo "Suggested path (usually no Full Disk Access needed):"
  echo "  ${suggested}"
  echo ""
  echo "Example (adjust site id and domain):"
  echo "  mkdir -p \"$(dirname "${suggested}")\""
  echo "  mv \"${path}\" \"${suggested}\""
  echo "  plumectl site update <site-id> --path=\"${suggested}\" --publish --reload"
}

plume_macos_permissions_interactive_menu() {
  local context="${1:-}"
  local path="${2:-}"
  local summary=""

  if [[ -z "${path}" ]] && declare -F plume_sites_macos_tcc_sensitive_site_summary >/dev/null 2>&1; then
    summary="$(plume_sites_macos_tcc_sensitive_site_summary)"
  fi

  if [[ -n "${path}" ]]; then
    if ! plume_sites_path_is_macos_tcc_sensitive "${path}"; then
      return 0
    fi
  elif [[ -z "${summary}" ]]; then
    return 0
  fi

  if ! plume_interactive_enabled; then
    plume_warn "macOS TCC risk detected (${context:-site}); non-interactive — see: init permissions (docs/operations/macos-permissions.md)"
    return 0
  fi

  echo ""
  plume_macos_permissions_print_why "${path}"
  if [[ -n "${summary}" ]]; then
    echo "Registered sites: ${summary}"
  fi
  echo ""
  echo "Choose:"
  echo "  [1] Open Full Disk Access + reveal nginx in Finder (add nginx/php-fpm with +)"
  echo "  [2] Show how to move the project to ~/Sites (recommended)"
  echo "  [3] Continue anyway"
  echo "  [q] Cancel this operation"
  echo ""

  local choice=""
  read -r -p "Option [1/2/3/q]: " choice </dev/tty || choice="q"
  case "${choice}" in
    1)
      plume_macos_permissions_open_fda_flow
      echo ""
      echo "After adding binaries: brew services restart nginx; brew services restart php (or php@8.3)."
      read -r -p "Press Enter when done (or Ctrl+C to abort)..." _ </dev/tty || true
      return 0
      ;;
    2)
      if [[ -n "${path}" ]]; then
        plume_macos_permissions_print_move_hint "${path}"
      else
        echo "Move each site path out of Desktop/Documents/Downloads, then:"
        echo "  plumectl site update <site-id> --path=/Users/you/Sites/your-app --publish --reload"
      fi
      read -r -p "Press Enter to return to the menu (or q to cancel)..." choice </dev/tty || choice="q"
      if [[ "${choice}" == "q" || "${choice}" == "Q" ]]; then
        return 2
      fi
      plume_macos_permissions_interactive_menu "${context}" "${path}"
      return $?
      ;;
    3)
      plume_warn "continuing without TCC remediation — expect nginx/php-fpm file access failures"
      return 0
      ;;
    q|Q)
      plume_err "cancelled by user (macOS permissions prompt)"
      return 2
      ;;
    *)
      plume_warn "unknown option; continuing anyway"
      return 0
      ;;
  esac
}

plume_macos_permissions_site_tcc_hint() {
  local path="$1"
  local label="" suggested=""
  label="$(plume_macos_permissions_path_label "${path}")"
  suggested="$(plume_macos_permissions_suggest_sites_path "${path}")"
  printf 'macOS TCC (%s): nginx/php-fpm may not read project files — prefer %s; run: init permissions --interactive (docs/operations/local-dev-macos.md)' \
    "${label}" "${suggested}"
}

plume_macos_permissions_warn_site_path() {
  local path="$1"
  local mode="${2:-native}"

  [[ "$(plume_detect_os)" == "macos" ]] || return 0
  if [[ -n "${mode}" && "${mode}" != "native" ]]; then
    return 0
  fi
  if ! plume_sites_path_is_macos_tcc_sensitive "${path}"; then
    return 0
  fi
  plume_warn "$(plume_macos_permissions_site_tcc_hint "${path}")"
}

plume_macos_permissions_maybe_prompt_site_path() {
  local context="$1"
  local path="$2"
  local mode="${3:-}"

  [[ "$(plume_detect_os)" == "macos" ]] || return 0
  if [[ -n "${mode}" && "${mode}" != "native" ]]; then
    return 0
  fi
  plume_macos_permissions_interactive_menu "${context}" "${path}"
}

plume_macos_permissions_maybe_prompt_registry() {
  local context="$1"
  [[ "$(plume_detect_os)" == "macos" ]] || return 0
  if ! declare -F plume_sites_macos_tcc_sensitive_site_summary >/dev/null 2>&1; then
    return 0
  fi
  local summary=""
  summary="$(plume_sites_macos_tcc_sensitive_site_summary)"
  [[ -n "${summary}" ]] || return 0
  plume_macos_permissions_interactive_menu "${context}" ""
}

plume_macos_permissions_confirm_host_install() {
  local package_label="$1"
  local reason="${2:-Install packages on the host for native mode.}"
  if plume_interactive_is_noninteractive; then
    return 0
  fi
  if [[ "$(plume_detect_os)" != "macos" ]]; then
    return 0
  fi
  if ! plume_interactive_enabled; then
    return 0
  fi
  echo ""
  echo "${reason}"
  echo "Action: ${package_label}"
  if plume_interactive_confirm "Proceed?" "true"; then
    return 0
  fi
  plume_err "host install cancelled"
  return 2
}

plume_macos_permissions_confirm_sudo() {
  local cmd_desc="$1"
  local reason="${2:-This step needs administrator privileges on macOS.}"
  if plume_interactive_is_noninteractive; then
    return 0
  fi
  if [[ "$(plume_detect_os)" != "macos" ]]; then
    return 0
  fi
  if ! plume_interactive_enabled; then
    return 1
  fi
  echo ""
  echo "${reason}"
  echo "Command: ${cmd_desc}"
  plume_interactive_confirm "Run with sudo now?" "true"
}

plume_macos_permissions_doctor_hint() {
  printf '%s' "run: plumectl init permissions --interactive (or init permissions --open)"
}
