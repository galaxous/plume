# First-Run Onboarding

This runbook explains the recommended order and host-profile model for developers installing Plume for the first time.

## Recommended order

1. **CLI readiness** — [install.md](./install.md): Homebrew (macOS), `install.sh` / Composer / `make install` (Linux).
2. **Global env** — `./plume.sh env init` (or `--from=templates/native-local.env.example`).
3. **Service manifest (optional, recommended)** — `./plume.sh init host` creates `~/.config/plume/services.yml` if missing (Laradock-like stack definition). Greenfield: `./plume.sh init host --apply` or `./plume.sh services provision --from-manifest`. Detail: [services-manifest.md](./services-manifest.md).
4. **Host profile** — Together with step 3, `./plume.sh init host` is enough; if there is no profile, automatic bootstrap runs (`PLUME_AUTO_HOST_BOOTSTRAP=true`).
5. **Onboarding checklist** —
   ```bash
   ./plume.sh init onboarding
   ```
   On macOS, binary list for Full Disk Access first: `./plume.sh init permissions`  
   Interactive menu: `./plume.sh init permissions --interactive`  
   To open System Settings: `./plume.sh init permissions --open` (or `./plume.sh init onboarding --open-settings`)  
   To start services: `./plume.sh init onboarding --fix` (does not open Settings)
6. **Diagnostics** —
   ```bash
   ./plume.sh doctor web
   ./plume.sh doctor php
   ```
7. **Shell shim (optional)** — `./plume.sh init shell`
8. **Services** — `./plume.sh services up @core --mode=native`  
   Optional development mail (macOS native): `./plume.sh services up mailpit --mode=native` — see [services.md](../commands/services.md) (Mailpit, D-109).
9. **Site** — `./plume.sh site add ... --publish`

## Host profile (`host.env`)

Persistent file: `~/.config/plume/host.env`

Why `host.env` (not YAML):

- Same `key=value` contract as existing Plume state files (`php.env`, runtime env)
- Stable parse with `grep`/`awk` on the shell and adapter sides

Fields: see [init-host.md](../commands/init-host.md)

## macOS-specific notes

### Full Disk Access (TCC)

If you put the Laravel root under `~/Desktop`, `~/Documents`, or `~/Downloads`, nginx/php-fpm may not be able to read files. Plume is not a `.app`; **do not add Plume or plume.sh** in System Settings. Instead:

```bash
./plume.sh init permissions
./plume.sh init permissions --interactive   # TTY menu
```

Detail: [macos-permissions.md](./macos-permissions.md) — daily `.env` and TCC paths: [local-dev-macos.md](./local-dev-macos.md)

Add the Homebrew **nginx** and **php-fpm** binaries listed in the output to Full Disk Access with `+`. If needed: `./plume.sh init permissions --open --reveal`.

Recommended root: `~/Sites` or `~/Code` (FDA is often unnecessary).

### Nginx port 8080 vs 80

Homebrew nginx listens on **8080** by default (install that does not require root). The host profile writes this into `nginx_http_port_detected`.

Options:

- **Stay on 8080** — `PLUME_NATIVE_HOMEBREW_HTTP_PORT=8080`, URLs with `:8080`
- **Move to 80** — `plumectl services web ensure` (see [services-web.md](../commands/services-web.md))

### Homebrew services

```bash
brew services start nginx
brew services start php   # or php@8.3
```

## Linux

The host profile detects `apt`/`dnf`. Use distro packages and `systemctl` for Nginx/php-fpm; the onboarding list aligns with `doctor web` / `doctor php`.

## Windows

`init host` writes `os=windows` and `native_support_note=limited native mode...`. Full native nginx/site publish is **not** in this slice; use WSL2, `docker-lite`, or `laradock-bridge`.

## Environment variables

| Variable | Default | Description |
|----------|------------|----------|
| `PLUME_AUTO_HOST_BOOTSTRAP` | `true` | Silent detect on first command if profile is missing |
| `PLUME_HOST_PROFILE_FILE` | `~/.config/plume/host.env` | Profile path override |
| `PLUME_NONINTERACTIVE` | `false` | `1` = skip macOS permission/install prompts (CI) |
| `PLUME_INTERACTIVE` | (unset) | `1` = force prompts; `0` = prompts off |

## Related decisions

- D-103 — `services.yml` native stack manifest
- D-109 — Native Mailpit (Homebrew) + doctor web port hints
- D-098 — Host profile persistence and onboarding commands
- D-099 — macOS FDA UX: binary list, `--fix` vs `--open-settings`
