# macOS Permissions and Native Host Setup

Plume native mode runs **Homebrew nginx** and **php-fpm** as separate processes. macOS **TCC** (Transparency, Consent, and Control) limits which files those processes can read. Plume cannot grant **Full Disk Access (FDA)** programmatically — the user must add binaries in **System Settings** or move projects out of protected folders.

## What Plume can automate

| Area                                 | Plume behavior                                                                                                     |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------ |
| Detect TCC-risk paths                | `Desktop`, `Documents`, `Downloads` in site registry (`doctor web` → `macos-site-tcc`, `doctor php` → `MACOS_TCC`) |
| Explain why                          | Interactive menu + `init permissions` checklist (English CLI; Turkish summary in this doc)                         |
| Open System Settings                 | `init permissions --open`, menu option `[1]`                                                                       |
| Reveal nginx binaries                | `init permissions --reveal`, menu option `[1]`                                                                     |
| Suggest `~/Sites/...` bmove          | Menu option `[2]`, `plume_macos_permissions_suggest_sites_path`                                                    |
| Homebrew install (nginx, mariadb, …) | With TTY: confirm before `brew install` when `PLUME_NATIVE_HOST_PROVISION=true`                                    |
| Nginx port 80                        | Patch main config via `services web sync-config`; reload may prompt for **sudo** on interactive TTY                |
| Start services                       | `init onboarding --fix`, `brew services start …` (no FDA pane)                                                     |

## What still requires manual steps (FDA)

- Adding **nginx** and **php-fpm** to **Privacy & Security → Full Disk Access** (use `+`, pick binaries from `init permissions` output).
- **Do not** add `plume.sh`, `plumectl`, or a non-existent “Plume.app”.
- Optional: add **Terminal** or **iTerm** only if daemon binaries alone are insufficient.
- **Local Network** / **Automation** prompts: approve when macOS shows them (Plume can explain; cannot bypass dialogs).

## Interactive flow

When stdin/stdout are a TTY (or `PLUME_INTERACTIVE=1`), Plume may show a menu on:

- `site add` / `site update --path=...` (native mode, sensitive path)
- `init host`, `init onboarding` (registered sites under sensitive paths)
- `init permissions --interactive`

Options:

1. Open FDA + reveal nginx directory in Finder
2. Print move-to-`~/Sites/<app>` commands
3. Continue anyway
4. Cancel (`q`)

## Non-interactive / CI

```bash
export PLUME_NONINTERACTIVE=1
# or pass global --yes
./plume.sh services install web --mode=native --yes
```

- No menus; TCC risks surface as **WARN** in doctor output only.
- Brew/sudo installs proceed without prompts when TTY is absent (existing smoke tests).

## Environment flags

| Variable                       | Effect                                                       |
| ------------------------------ | ------------------------------------------------------------ |
| `PLUME_NONINTERACTIVE=1`       | Skip all permission/install prompts                          |
| `PLUME_INTERACTIVE=1`          | Force interactive prompts even if stdout is not a TTY (rare) |
| `PLUME_INTERACTIVE=0`          | Never prompt                                                 |
| `PLUME_ASSUME_YES=1` / `--yes` | Same as non-interactive for confirmations                    |

See also [first-run-onboarding.md](./first-run-onboarding.md) and [init-permissions.md](../commands/init-permissions.md).

## Turkish summary (product)

**Neden?** Masaüstü / Documents / Downloads altındaki Laravel projelerine nginx ve php-fpm erişemeyebilir; tarayıcıda “No input file specified” görürsünüz.

**Ne yapmalı?**

1. `./plume.sh init permissions --interactive` veya `--open --reveal`
2. System Settings’te **nginx** ve **php-fpm** binary’lerine Full Disk Access verin
3. Ya da projeyi `~/Sites/...` altına taşıyın (`site update --path=... --publish --reload`)

**Plume uygulaması yok** — FDA listesine plume.sh eklemeyin.

## Related decisions

- D-097 — TCC detection and nginx PHP location
- D-099 — FDA binary list UX
- D-100 — Interactive permission and host install prompts
