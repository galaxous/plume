---
search: false
---

# AI-Assisted Development (Plume)

Persistent context: so human + AI pair development on this repo does not forget test lessons, documentation obligations, and smoke strategy.

Related docs:

- [AGENTS.md](../../AGENTS.md) — agent rules (§1–8: docs, phase-gate, smoke, repo identity, config layers, new-phase bootstrap)
- [release-readiness.md](./release-readiness.md) — pre-release smoke chain
- [macos-permissions.md](./macos-permissions.md) — TCC / FDA / `init permissions`
- [implementation/05-decision-log.md](../../implementation/05-decision-log.md) — decision records (e.g. D-101, D-102)

---

## Session bootstrap (paste into a new chat)

Paste the block below at the start of a new Cursor/agent session, then write the task.

```text
We are working on Plume. GitHub: galaxous/plume (local folder name may differ). 3-mode CLI for Laravel (native, docker-lite, laradock-bridge).
Wrapper: `./plume.sh` (repo smokes); official binary: `plumectl`. Real user state: ~/.config/plume (NEVER trust that in tests). Config: services.yml + .env + host.env (AGENTS.md §6–7).

Required: AGENTS.md §1–8 + docs/commands/ (new command) + docs/contracts/ + implementation/05-decision-log.md (important decisions).
Phases 1–23 are complete (Phase 7 beta-frozen); active Phase 27 Composer/Node (D-154). New work = new phase-NN.md + phase-tracker. Phase-gate: tests + docs + decision record.
Start reading: implementation/phase-tracker.md, implementation/future-roadmap.md (P4→P3→P2; P1 deferred).

Smoke (default before PR): ./tests/run_smoke_suite.sh --release  (same as CI: --ci)
Hermetic tests: temp HOME + PLUME_STATE_DIR; mock brew PATH = MOCK_BIN:/usr/bin:/bin only (do not append Homebrew to PATH).
pipefail: do NOT use `./plume.sh ... | grep -q` — first OUT="$(...)" then grep.
Nginx reload tests: PLUME_SITE_NGINX_STRICT=false and PLUME_SITE_NGINX_STRICT_ON_RELOAD=false (isolated reload-validate); `PLUME_NATIVE_NGINX_ENSURE_ON_PUBLISH=false` + fake `PATH=MOCK:/usr/bin:/bin` (no host brew/sudo). Truncate mock nginx log before asserts.
Site registry smoke (phase4): `PLUME_NATIVE_NGINX_ENSURE_ON_PUBLISH=false`; do not use host `site publish --reload` / brew sudo (D-157). `[INFO]` goes to stderr — `SITE_ID="$(site add …)"` stays stdout-only. Tests that assert INFO/hook lines: `>/tmp/out 2>&1` (stdout-only capture breaks).
Suite: `PLUME_NONINTERACTIVE=1` + elevated nginx **never** interactively asks for a sudo password (`sudo -n` only, D-158). Interactive hosts: `/dev/tty` sudo confirm (D-159); ensure soft-fails reload when listen already correct. Hermetic fake-nginx smoke: `PLUME_NATIVE_NGINX_FORCE_UNPRIVILEGED_RELOAD=true` + temp `HOME` (real `.env` empty `PLUME_NATIVE_NGINX_MAIN_CONF=` must not override).
Phase6-style service smoke: PLUME_PHP_EXTENSIONS_AUTO_SYNC=false.
Redis smoke: PLUME_NATIVE_REDIS_MAIN_CONF=temp file — never patch host `/opt/homebrew/etc/redis.conf`.
macOS: Desktop/Documents/Downloads TCC; FDA for nginx + php-fpm binaries (not plume.sh); init permissions --interactive.

Detail: docs/operations/ai-assisted-development.md — read it and follow the rules.
```

---

## Project identity

| Concept | Description |
|--------|----------|
| **Plume** | Operations CLI for Laravel projects (product name) |
| **plumectl** | Official CLI binary (`bin/plumectl`) |
| **./plume.sh** | Local development / smoke-test wrapper |
| **~/.config/plume** | User state (`.env`, site registry, nginx cache, service state) |
| **native vs laradock-bridge** | Native: Homebrew/host services; laradock-bridge: Docker Compose parity |
| **docker-lite** | Beta-frozen; kept in the regression matrix |

Code layout: `lib/commands/`, `lib/services/`, `lib/common/`, `tests/phase*_*.sh`.

---

## Documentation, decisions, contracts

1. **Every code change** updates related docs in the same change (`AGENTS.md` §1).
2. **New `plumectl` command** → `docs/commands/<command>.md` (purpose, usage, parameters, output/exit-code, examples, error scenarios).
3. **Important technical decision** → `implementation/05-decision-log.md` (ADR-lite: context, decision, rationale, impact).
4. **CLI outputs** stay parseable and stable; JSON/`--json` and text contracts stay aligned with `docs/contracts/`.

---

## Smoke test strategy

### Unified runner (CI default)

```bash
./tests/run_smoke_suite.sh              # default: --release
./tests/run_smoke_suite.sh --ci         # same as .github/workflows/smoke-tests.yml
./tests/run_smoke_suite.sh --phase11-full   # all phase11_* smokes (except e2e_matrix)
./tests/run_smoke_suite.sh --all        # all *smoke*.sh (except e2e_matrix aggregator)
./tests/run_smoke_suite.sh --all --linux    # --all + PLUME_RUN_LINUX_TESTS=1 (phase3 Linux matrix)
```

`--release` / `--ci` chain (summary): `phase10_e2e_matrix` (includes `phase11_e2e_matrix`) → `phase14` → `phase12` (x2) → `phase13`. Suite end: `run-smoke-suite:ok` or fail-fast `run-smoke-suite:fail`.

See [release-readiness.md](./release-readiness.md).

### Hermetic environment

Smoke scripts **must not depend on the real user machine**:

- `mktemp -d` for `TMP_ROOT`; `HOME="${TMP_ROOT}/home"`, `PLUME_STATE_DIR="${TMP_ROOT}/state"` (or equivalent).
- Site registry: temporary `PLUME_SITE_REGISTRY_DIR`.
- **Never** validate test logic against `~/.config/plume/.env` or a live registry.
- CI: `PLUME_NONINTERACTIVE=1`; prompts are skipped when there is no TTY (D-100).

### Mock Homebrew / PATH (phase12 lesson)

So real `brew` or Homebrew nginx on the host is not picked up:

```bash
SMOKE_PATH="${MOCK_BIN}:/usr/bin:/bin:/usr/sbin:/sbin"
# WRONG: PATH="${MOCK_BIN}:${PATH}"  # Homebrew comes first; mock brew is disabled
```

Examples: `tests/phase12_site_publish_auto_provision_web_smoke.sh`, `tests/phase12_native_host_provision_smoke.sh`.

The mock `brew` script logs install calls; for nginx, mock `--prefix` / fake binary shims are used.

### Mock nginx / PHP shims

- Fake `nginx` binary: writes `-t` / `-s reload` behavior to a log file (e.g. `phase11_site_reload_validate_smoke.sh`).
- PHP: `PLUME_PHP_SHIM_SEARCH_PATH`, fake `php8.x` binaries (`phase11_php_shim_smoke.sh`).
- Strict publish / include target: **`PLUME_NGINX_INCLUDE_DIR`** temporary directory (`phase11_site_nginx_strict_publish_smoke.sh`).

### Nginx strict flags (isolated reload-validate)

Defaults may be close to production; when testing **only reload-validate behavior**, turn off the strict pipeline:

```bash
PLUME_SITE_NGINX_STRICT=false
PLUME_SITE_NGINX_STRICT_ON_RELOAD=false
```

Otherwise the test mixes with real strict publish / double reload / include-directory expectations. Strict publish tests run in separate scripts with `STRICT=true` and `PLUME_NGINX_INCLUDE_DIR`.

### Service smoke (phase6-style)

To cut PHP extension auto-sync side effects:

```bash
PLUME_PHP_EXTENSIONS_AUTO_SYNC=false
```

Example: `tests/phase6_service_smoke.sh`.

### Native `services.yml` manifest (D-104)

- All registry services map via `~/.config/plume/services.yml` to `PLUME_*_ENABLED` / version envs; missing keys keep defaults.
- Verification: `tests/phase11_services_manifest_smoke.sh`, `tests/phase11_services_manifest_full_smoke.sh` (hermetic `PLUME_SERVICES_MANIFEST_FILE`).
- Detail: [services-manifest.md](./services-manifest.md), `services manifest show`, `services provision --from-manifest`.

### pipefail and SIGPIPE

The main smoke script uses `set -euo pipefail`. The **`./plume.sh ... | grep -q`** pattern can fail with SIGPIPE / a non-zero pipeline when grep exits early.

```bash
# WRONG (fragile under pipefail)
./plume.sh site check "$ID" | grep -q '^mode: native$'

# RIGHT
OUT="$(./plume.sh site check "$ID")"
printf '%s\n' "$OUT" | grep -q '^mode: native$'
# or: grep -q ... <<< "$OUT"  (for a single line)
```

Some tests intentionally use `bash -lc '... | grep -q ...'` in a subshell; when **writing new tests**, capture output first.

### macOS permissions (native development)

- If the site path is under **Desktop, Documents, Downloads**, there is TCC risk; see `doctor web` / the interactive menu.
- **Full Disk Access**: Homebrew **nginx** and **php-fpm** binaries — do **not** add `plume.sh` / `plumectl` / a fictional "Plume.app".
- Guide: `plumectl init permissions --interactive`, `--open`, `--reveal`.
- Detail: [macos-permissions.md](./macos-permissions.md).

### Integration (optional)

Real host package install:

```bash
PLUME_RUN_INTEGRATION=1 ./tests/phase12_native_host_provision_smoke.sh
```

The release `--release` chain runs the default mock/non-integration path.

---

## Where tests live

| Type | Location / example |
|-----|----------------|
| Individual smoke | `tests/phase{N}_*_smoke.sh` |
| E2E aggregator | `phase10_e2e_matrix_smoke.sh`, `phase11_e2e_matrix_smoke.sh` — run nested phases |
| Suite entry | `tests/run_smoke_suite.sh` |
| `--all` | excludes `*e2e_matrix*` (prevents double runs, D-101) |

When adding a new smoke: follow existing phase numbers and naming (`phase11_foo_smoke.sh`); decide whether to add it to `phase11_e2e_matrix` or `run_smoke_suite`, and update docs.

---

## Pre-PR checklist

- [ ] `./tests/run_smoke_suite.sh --release` (or `--phase11-full` / `--all` based on change scope)
- [ ] Command/flag/ENV contract changed? → `docs/commands/` + `docs/contracts/` + `docs/operations/env-contract.md`
- [ ] Behavior/decision changed? → `implementation/05-decision-log.md`
- [ ] macOS UX / TCC → `docs/operations/macos-permissions.md` and related command doc
- [ ] Release steps changed? → [release-readiness.md](./release-readiness.md) + README Test section
