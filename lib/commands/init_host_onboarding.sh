#!/usr/bin/env bash
set -euo pipefail

plume_onboarding_print_item() {
  local status="$1"
  local title="$2"
  local detail="${3:-}"
  printf '[%-4s] %s\n' "${status}" "${title}"
  if [[ -n "${detail}" ]]; then
    printf '       %s\n' "${detail}"
  fi
}

plume_onboarding_macos_open_privacy_all_files() {
  if ! command -v open >/dev/null 2>&1; then
    return 1
  fi
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles" 2>/dev/null \
    || open "/System/Library/PreferencePanes/Security.prefPane" 2>/dev/null \
    || return 1
}

plume_onboarding_resolve_nginx_binary() {
  local candidate=""
  if command -v nginx >/dev/null 2>&1; then
    candidate="$(command -v nginx)"
    printf '%s' "${candidate}"
    return 0
  fi
  if command -v brew >/dev/null 2>&1; then
    local prefix=""
    prefix="$(HOMEBREW_NO_AUTO_UPDATE=1 brew --prefix nginx 2>/dev/null || true)"
    if [[ -n "${prefix}" && -x "${prefix}/bin/nginx" ]]; then
      printf '%s' "${prefix}/bin/nginx"
      return 0
    fi
  fi
  return 1
}

plume_onboarding_resolve_php_fpm_binary() {
  local v bin default_v=""
  default_v="${PLUME_PHP_DEFAULT_VERSION:-8.3}"
  if declare -F plume_php_find_fpm_bin >/dev/null 2>&1; then
    for v in "${default_v}" 8.3 8.4 8.2 8.1; do
      bin="$(plume_php_find_fpm_bin "${v}" 2>/dev/null || true)"
      if [[ -n "${bin}" && -x "${bin}" ]]; then
        printf '%s' "${bin}"
        return 0
      fi
    done
  fi
  if command -v php-fpm >/dev/null 2>&1; then
    command -v php-fpm
    return 0
  fi
  if command -v brew >/dev/null 2>&1; then
    local prefix=""
    for v in "${default_v}" 8.3 8.4; do
      prefix="$(HOMEBREW_NO_AUTO_UPDATE=1 brew --prefix "php@${v}" 2>/dev/null || true)"
      if [[ -n "${prefix}" && -x "${prefix}/sbin/php-fpm" ]]; then
        printf '%s' "${prefix}/sbin/php-fpm"
        return 0
      fi
    done
  fi
  return 1
}

plume_onboarding_macos_terminal_app_hint() {
  case "${TERM_PROGRAM:-}" in
    iTerm.app)
      printf '%s' "/Applications/iTerm.app"
      ;;
    Apple_Terminal|Terminal)
      printf '%s' "/Applications/Utilities/Terminal.app"
      ;;
    *)
      printf '%s' "/Applications/Utilities/Terminal.app or /Applications/iTerm.app"
      ;;
  esac
}

plume_onboarding_macos_print_fda_binaries() {
  local nginx_bin="" php_fpm_bin="" term_hint=""
  nginx_bin="$(plume_onboarding_resolve_nginx_binary 2>/dev/null || true)"
  php_fpm_bin="$(plume_onboarding_resolve_php_fpm_binary 2>/dev/null || true)"
  term_hint="$(plume_onboarding_macos_terminal_app_hint 2>/dev/null || true)"

  echo "Plume is a CLI script — do NOT add plume.sh or a \"Plume\" app in Full Disk Access."
  echo "System Settings → Privacy & Security → Full Disk Access → + and add:"
  if [[ -n "${nginx_bin}" ]]; then
    echo "  nginx:     ${nginx_bin}"
  else
    echo "  nginx:     (install nginx or run: brew --prefix nginx)/bin/nginx"
  fi
  if [[ -n "${php_fpm_bin}" ]]; then
    echo "  php-fpm:   ${php_fpm_bin}"
  else
    echo "  php-fpm:   (brew --prefix php@8.3)/sbin/php-fpm or: command -v php-fpm"
  fi
  if [[ -n "${term_hint}" ]]; then
    echo "  optional:  ${term_hint} — only if file access still fails after daemon binaries"
  fi
  echo "After granting: brew services restart nginx; brew services restart php (or php@8.3)."
}

plume_onboarding_macos_tcc_steps() {
  plume_onboarding_macos_print_fda_binaries
}

plume_onboarding_macos_reveal_nginx_dir() {
  local nginx_bin="" dir=""
  nginx_bin="$(plume_onboarding_resolve_nginx_binary 2>/dev/null || true)"
  if [[ -n "${nginx_bin}" ]]; then
    dir="$(dirname "${nginx_bin}")"
  elif command -v brew >/dev/null 2>&1; then
    local prefix=""
    prefix="$(HOMEBREW_NO_AUTO_UPDATE=1 brew --prefix nginx 2>/dev/null || true)"
    if [[ -n "${prefix}" && -d "${prefix}/bin" ]]; then
      dir="${prefix}/bin"
    elif [[ -n "${prefix}" && -d "${prefix}/sbin" ]]; then
      dir="${prefix}/sbin"
    fi
  fi
  [[ -n "${dir}" && -d "${dir}" ]] || return 1
  open "${dir}" 2>/dev/null || return 1
}

plume_onboarding_dev_mode_active() {
  if [[ -n "${PLUME_REPO_ROOT:-}" ]]; then
    return 0
  fi
  if [[ -n "${ROOT_DIR:-}" && -f "${ROOT_DIR}/plume.sh" && -f "${ROOT_DIR}/bin/plumectl" ]]; then
    if [[ -d "${ROOT_DIR}/.git" ]]; then
      return 0
    fi
    # Repo checkout without .git (e.g. export) still uses ./plume.sh in dev
    if [[ "${ROOT_DIR}" == *"/larasite"* ]] || [[ -f "${ROOT_DIR}/AGENTS.md" ]]; then
      return 0
    fi
  fi
  return 1
}

plume_onboarding_macos_run_safe_fixes() {
  local pm="${1:-}"
  [[ "${pm}" == "brew" ]] || return 0
  if ! command -v brew >/dev/null 2>&1; then
    plume_onboarding_print_item "SKIP" "brew services" "Homebrew not available"
    return 0
  fi
  local svc started_any="false"
  for svc in nginx; do
    if HOMEBREW_NO_AUTO_UPDATE=1 brew services start "${svc}" >/dev/null 2>&1; then
      plume_onboarding_print_item "OK" "brew services start ${svc}" "started or already running"
      started_any="true"
    else
      plume_onboarding_print_item "WARN" "brew services start ${svc}" "failed — run manually: brew services start ${svc}"
    fi
  done
  local php_svc=""
  for php_svc in php "php@${PLUME_PHP_DEFAULT_VERSION:-8.3}" php@8.3 php@8.4 php; do
    if HOMEBREW_NO_AUTO_UPDATE=1 brew list --formula "${php_svc}" >/dev/null 2>&1; then
      if HOMEBREW_NO_AUTO_UPDATE=1 brew services start "${php_svc}" >/dev/null 2>&1; then
        plume_onboarding_print_item "OK" "brew services start ${php_svc}" "started or already running"
        started_any="true"
      else
        plume_onboarding_print_item "WARN" "brew services start ${php_svc}" "failed — run manually"
      fi
      break
    fi
  done
  if [[ "${started_any}" == "false" ]]; then
    plume_onboarding_print_item "INFO" "PHP-FPM service" "Install PHP (brew install php@8.3) then: brew services start php@8.3"
  fi
}

plume_onboarding_run() {
  local do_fix="${1:-false}"
  local do_open_settings="${2:-false}"
  local os
  os="$(plume_detect_os)"

  if ! plume_host_profile_exists; then
    plume_host_profile_detect_and_persist "false" || true
  fi

  local nginx_port homebrew_nginx pm
  nginx_port="$(plume_host_profile_read_value nginx_http_port_detected)"
  homebrew_nginx="$(plume_host_profile_read_value homebrew_nginx)"
  pm="$(plume_host_profile_read_value package_manager)"
  [[ -n "${nginx_port}" ]] || nginx_port="unknown"

  echo "Plume first-run onboarding checklist"
  echo "host_profile=$(plume_host_profile_file)"
  if declare -F plume_services_manifest_print_effective >/dev/null 2>&1; then
    plume_services_manifest_print_effective
  fi
  echo "os=${os}"
  echo ""

  if plume_onboarding_dev_mode_active; then
    plume_onboarding_print_item "NOTE" "Dev / repo checkout" "Plume runs as ./plume.sh — not an .app. Prefer ~/Sites or ~/Code for Laravel roots; Full Disk Access is optional if you avoid Desktop/Documents."
  fi

  case "${os}" in
    macos)
      local tcc_summary=""
      if declare -F plume_sites_macos_tcc_sensitive_site_summary >/dev/null 2>&1; then
        tcc_summary="$(plume_sites_macos_tcc_sensitive_site_summary)"
      fi
      if [[ -n "${tcc_summary}" ]]; then
        plume_onboarding_print_item "WARN" "macOS Full Disk Access (TCC)" "Sites under Desktop/Documents/Downloads: ${tcc_summary}"
      else
        plume_onboarding_print_item "INFO" "macOS Full Disk Access (TCC)" "Avoid ~/Desktop, ~/Documents, ~/Downloads for Laravel roots; prefer ~/Sites or ~/Code."
      fi
      plume_onboarding_print_item "INFO" "Recommended project paths" "~/Sites/your-app or ~/Code/your-app (not Desktop/Documents)."
      if [[ "${homebrew_nginx}" == "true" && "${nginx_port}" == "8080" ]]; then
        plume_onboarding_print_item "WARN" "Nginx HTTP port" "Homebrew default is 8080; Plume ensures port 80 via: plumectl services web ensure (see docs/commands/services-web.md)."
      elif [[ "${nginx_port}" == "80" ]]; then
        plume_onboarding_print_item "OK" "Nginx HTTP port" "Main config listen port is 80 (portsuz URLs)."
      else
        plume_onboarding_print_item "INFO" "Nginx HTTP port" "Detected listen port: ${nginx_port}. Align site publish and PLUME_NATIVE_HOMEBREW_HTTP_PORT if needed."
      fi
      if [[ "${pm}" == "brew" ]]; then
        plume_onboarding_print_item "INFO" "PHP-FPM services" "Start FPM for your PHP version: brew services start php (or php@8.3). Verify: plumectl doctor php"
        plume_onboarding_print_item "INFO" "Nginx service" "brew services start nginx — then plumectl doctor web"
      fi
      echo ""
      plume_onboarding_macos_print_fda_binaries
      echo ""
      if [[ "${do_fix}" == "true" ]]; then
        plume_onboarding_print_item "FIX" "Safe host fixes (macOS)" "Starting Homebrew nginx/php services if available..."
        plume_onboarding_macos_run_safe_fixes "${pm}"
        plume_onboarding_print_item "TIP" "Open Full Disk Access pane" "plumectl init permissions --open  (lists binaries before opening)"
      elif [[ "${do_open_settings}" == "true" ]]; then
        plume_info "opening Full Disk Access privacy pane (macOS)..."
        plume_onboarding_macos_open_privacy_all_files || {
          plume_err "could not open System Settings; use init permissions --open"
          return 2
        }
      else
        plume_onboarding_print_item "TIP" "Open privacy settings" "plumectl init permissions --open [--reveal] or init permissions --interactive"
      fi
      if [[ -n "${tcc_summary}" ]]; then
        plume_macos_permissions_maybe_prompt_registry "init-onboarding" || return 2
      fi
      ;;
    linux)
      plume_onboarding_print_item "INFO" "Project paths" "Use ~/Sites, ~/code, or /var/www per your distro policy."
      if [[ "${nginx_port}" == "80" ]]; then
        plume_onboarding_print_item "OK" "Nginx HTTP port" "Listen port 80 (may require root/capabilities)."
      elif [[ -n "${nginx_port}" && "${nginx_port}" != "unknown" ]]; then
        plume_onboarding_print_item "INFO" "Nginx HTTP port" "Detected: ${nginx_port}"
      fi
      plume_onboarding_print_item "INFO" "Services" "Use systemctl for nginx/php-fpm; plumectl doctor web && plumectl doctor php"
      if [[ "${do_fix}" == "true" || "${do_open_settings}" == "true" ]]; then
        plume_onboarding_print_item "INFO" "macOS-only flags" "--fix / --open-settings apply on macOS only"
      fi
      ;;
    windows)
      local note=""
      note="$(plume_host_profile_read_value native_support_note)"
      plume_onboarding_print_item "WARN" "Windows native mode" "${note:-limited native mode; use WSL2 or docker-lite/laradock-bridge for full stack.}"
      plume_onboarding_print_item "INFO" "Host profile" "Detection stored for tooling; nginx/site native paths are not supported on Windows yet."
      ;;
    *)
      plume_onboarding_print_item "WARN" "Unknown OS" "Run plumectl init host --force after installing prerequisites."
      ;;
  esac

  echo ""
  echo "Next: plumectl env init && plumectl doctor web && plumectl doctor onboarding"
  return 0
}

cmd_init_host() {
  local force="false" json="false" do_apply="false"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --force) force="true" ;;
      --json) json="true" ;;
      --apply) do_apply="true" ;;
      *)
        plume_err "unknown init host option: ${arg}"
        return 2
        ;;
    esac
  done

  plume_services_manifest_bootstrap_if_missing

  plume_host_profile_detect_and_persist "${force}" || return 2
  local file
  file="$(plume_host_profile_file)"

  if [[ "${json}" == "true" ]]; then
    printf '{'
    printf '"file":"%s",' "${file}"
    local k v first="true"
    while IFS='=' read -r k v; do
      [[ "${k}" =~ ^# ]] && continue
      [[ -z "${k}" ]] && continue
      [[ "${first}" == "true" ]] && first="false" || printf ','
      printf '"%s":"%s"' "${k}" "${v}"
    done < "${file}"
    printf '}\n'
    return 0
  fi

  cat "${file}"

  if [[ "${json}" != "true" ]]; then
    plume_macos_permissions_maybe_prompt_registry "init-host" || return 2
  fi

  if [[ "${do_apply}" == "true" ]]; then
    plume_services_manifest_provision_services "false" || return 2
  else
    plume_services_manifest_maybe_on_first_run_provision || return 2
  fi
}

cmd_init_onboarding() {
  local do_fix="false"
  local do_open_settings="false"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --fix) do_fix="true" ;;
      --open-settings) do_open_settings="true" ;;
      *)
        plume_err "unknown init onboarding option: ${arg} (use --fix for safe brew fixes; --open-settings to open Privacy pane on macOS)"
        return 2
        ;;
    esac
  done
  plume_onboarding_run "${do_fix}" "${do_open_settings}"
}

cmd_init_permissions() {
  local do_open="false"
  local do_reveal="false"
  local do_interactive="false"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --open) do_open="true" ;;
      --reveal) do_reveal="true" ;;
      --interactive) do_interactive="true" ;;
      *)
        plume_err "unknown init permissions option: ${arg}"
        return 2
        ;;
    esac
  done

  local os
  os="$(plume_detect_os)"
  if [[ "${os}" != "macos" ]]; then
    plume_info "init permissions is macOS-specific (current os=${os}); no grants required via this command."
    return 0
  fi

  echo "macOS permissions checklist for Plume native mode"
  echo ""

  if plume_onboarding_dev_mode_active; then
    echo "*** Dev mode: Plume is ./plume.sh from the repo — not listed as an app in System Settings."
    echo "    Recommended: move Laravel sites off Desktop; Full Disk Access is optional if paths are ~/Sites or ~/Code."
    echo ""
  fi

  echo "1. Full Disk Access — add daemon binaries (+), not plume.sh:"
  plume_onboarding_macos_print_fda_binaries
  echo ""
  echo "2. Local network (if prompted) — allow nginx/php-fpm for *.test sites"
  echo ""
  echo "3. Project location — prefer ~/Sites or ~/Code over Desktop/Documents"
  echo ""
  echo "Verify: plumectl doctor web (macos-site-tcc) and plumectl doctor php (MACOS_TCC)"
  echo "Docs: docs/commands/site.md (troubleshooting), docs/operations/macos-permissions.md"

  if [[ "${do_reveal}" == "true" ]]; then
    plume_onboarding_macos_reveal_nginx_dir || plume_err "could not reveal nginx binary directory in Finder"
  fi

  if [[ "${do_open}" == "true" ]]; then
    echo ""
    echo "Opening System Settings → Full Disk Access. Use + to add the nginx/php-fpm paths above (NOT plume.sh)."
    plume_onboarding_macos_open_privacy_all_files || {
      plume_err "could not open System Settings; follow the steps above manually"
      return 2
    }
  fi

  if [[ "${do_interactive}" == "true" ]]; then
    # Explicit --interactive must force the TTY menu even when stdin/stdout
    # are not detected as terminals (e.g. some IDE integrated shells).
    export PLUME_INTERACTIVE=true
    plume_macos_permissions_maybe_prompt_registry "init-permissions" || return 2
  fi
}

cmd_doctor_host() {
  local force="false"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --force) force="true" ;;
      *)
        plume_err "unknown doctor host option: ${arg}"
        return 2
        ;;
    esac
  done
  cmd_init_host $(if [[ "${force}" == "true" ]]; then printf '%s' "--force"; fi)
}

cmd_doctor_onboarding() {
  local do_fix="false"
  local do_open_settings="false"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --fix) do_fix="true" ;;
      --open-settings) do_open_settings="true" ;;
      *)
        plume_err "unknown doctor onboarding option: ${arg}"
        return 2
        ;;
    esac
  done
  plume_onboarding_run "${do_fix}" "${do_open_settings}"
}
