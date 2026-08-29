# AI-Assisted Development (Plume)

Kalici baglam: bu repoda insan + AI esli gelistirmede test ogrenimleri, dokuman yukumlulukleri ve smoke stratejisi unutulmasin diye.

Iliskili dokumanlar:

- [AGENTS.md](../../AGENTS.md) — agent kurallari (§1–8: dokuman, faz-gate, smoke, repo kimligi, config katmanlari, yeni faz bootstrap)
- [release-readiness.md](./release-readiness.md) — yayin oncesi smoke zinciri
- [macos-permissions.md](./macos-permissions.md) — TCC / FDA / `init permissions`
- [implementation/05-decision-log.md](../../implementation/05-decision-log.md) — karar kayitlari (orn. D-101, D-102)

---

## Session bootstrap (yeni sohbete yapistir)

Asagidaki blogu yeni Cursor/agent oturumunun basinda yapistirin; sonra gorevi yazin.

```text
Plume uzerinde calisiyoruz. GitHub: galaxous/plume (yerel klasor adi farkli olabilir). Laravel icin 3 modlu CLI (native, docker-lite, laradock-bridge).
Wrapper: ./plume.sh; resmi binary adi plumectl. Gercek kullanici state: ~/.config/plume (testlerde ASLA buna guvenme). Config: services.yml + .env + host.env (AGENTS.md §6–7).

Zorunlu: AGENTS.md §1–8 + docs/commands/ (yeni komut) + docs/contracts/ + implementation/05-decision-log.md (onemli karar).
Faz 1–22 tamamlandi (Faz 7 beta-frozen); yeni is = yeni implementation/phases/phase-NN.md + phase-tracker. Faz-gate: test + dokuman + karar kaydi.
Baslangic okuma: implementation/phase-tracker.md, en guncel implementation/11-status-*.md.

Smoke (PR oncesi varsayilan): ./tests/run_smoke_suite.sh --release  (CI ile ayni: --ci)
Hermetic testler: gecici HOME + PLUME_STATE_DIR; mock brew PATH = MOCK_BIN:/usr/bin:/bin only (Homebrew PATH'e ekleme).
pipefail: ./plume.sh ... | grep -q KULLANMA — once OUT="$(...)" sonra grep.
Nginx reload testleri: PLUME_SITE_NGINX_STRICT=false ve PLUME_SITE_NGINX_STRICT_ON_RELOAD=false (izole reload-validate).
Phase6 tarzi servis smoke: PLUME_PHP_EXTENSIONS_AUTO_SYNC=false.
Redis smoke: PLUME_NATIVE_REDIS_MAIN_CONF=temp dosya — host `/opt/homebrew/etc/redis.conf` asla patch edilmez.
macOS: Desktop/Documents/Downloads TCC; FDA nginx + php-fpm binary'leri (plume.sh degil); init permissions --interactive.

Detay: docs/operations/ai-assisted-development.md — oku ve kurallara uy.
```

---

## Project identity

| Kavram | Aciklama |
|--------|----------|
| **Plume** | Laravel projeleri icin operasyon CLI (urun adi) |
| **plumectl** | Resmi CLI binary (`bin/plumectl`) |
| **./plume.sh** | Yerel gelistirme / smoke test wrapper |
| **~/.config/plume** | Kullanici state (`.env`, site registry, nginx cache, servis state) |
| **native vs laradock-bridge** | Native: Homebrew/host servisleri; laradock-bridge: Docker Compose parity |
| **docker-lite** | Beta-frozen; regression matrix'te korunur |

Kod yapisi: `lib/commands/`, `lib/services/`, `lib/common/`, `tests/phase*_*.sh`.

---

## Documentation, decisions, contracts

1. **Her kod degisikligi** ile ilgili dokuman ayni degisiklikte guncellenir (`AGENTS.md` §1).
2. **Yeni `plumectl` komutu** → `docs/commands/<komut>.md` (amac, kullanim, parametreler, cikti/exit-code, ornekler, hata senaryolari).
3. **Onemli teknik karar** → `implementation/05-decision-log.md` (ADR-lite: durum, karar, gerekce, etki).
4. **CLI ciktilari** parse-edilebilir ve stabil tutulur; JSON/`--json` ve metin sozlesmeleri `docs/contracts/` ile hizalanir.

---

## Smoke test strategy

### Unified runner (CI default)

```bash
./tests/run_smoke_suite.sh              # default: --release
./tests/run_smoke_suite.sh --ci         # .github/workflows/smoke-tests.yml ile birebir
./tests/run_smoke_suite.sh --phase11-full   # tum phase11_* smoke (e2e_matrix haric)
./tests/run_smoke_suite.sh --all        # tum *smoke*.sh (e2e_matrix aggregator haric)
./tests/run_smoke_suite.sh --all --linux    # --all + PLUME_RUN_LINUX_TESTS=1 (phase3 Linux matrix)
```

`--release` / `--ci` zinciri (ozet): `phase10_e2e_matrix` (icinde `phase11_e2e_matrix`) → `phase14` → `phase12` (x2) → `phase13`. Suite sonu: `run-smoke-suite:ok` veya fail-fast `run-smoke-suite:fail`.

Bkz. [release-readiness.md](./release-readiness.md).

### Hermetic environment

Smoke scriptleri **gercek kullanici makinesine bagimli olmamali**:

- `mktemp -d` ile `TMP_ROOT`; `HOME="${TMP_ROOT}/home"`, `PLUME_STATE_DIR="${TMP_ROOT}/state"` (veya esdeger).
- Site registry: `PLUME_SITE_REGISTRY_DIR` gecici dizin.
- **Asla** test mantigini `~/.config/plume/.env` veya canli registry uzerinden dogrulamayin.
- CI: `PLUME_NONINTERACTIVE=1`, TTY yokken prompt atlanir (D-100).

### Mock Homebrew / PATH (phase12 dersi)

Host uzerinde gercek `brew` veya Homebrew nginx yakalanmasin diye:

```bash
SMOKE_PATH="${MOCK_BIN}:/usr/bin:/bin:/usr/sbin:/sbin"
# YANLIS: PATH="${MOCK_BIN}:${PATH}"  # Homebrew once gelir, mock brew devre disi kalir
```

Ornek: `tests/phase12_site_publish_auto_provision_web_smoke.sh`, `tests/phase12_native_host_provision_smoke.sh`.

Mock `brew` scripti kurulum cagrilarini loglar; nginx icin mock `--prefix` / sahte binary shims kullanilir.

### Mock nginx / PHP shims

- Fake `nginx` binary: `-t` / `-s reload` davranisini log dosyasina yazar (orn. `phase11_site_reload_validate_smoke.sh`).
- PHP: `PLUME_PHP_SHIM_SEARCH_PATH`, sahte `php8.x` binary'leri (`phase11_php_shim_smoke.sh`).
- Strict publish / include hedefi: **`PLUME_NGINX_INCLUDE_DIR`** gecici dizin (`phase11_site_nginx_strict_publish_smoke.sh`).

### Nginx strict flags (izole reload-validate)

Varsayilanlar production'a yakin olabilir; **yalnizca reload-validate davranisini** test ederken strict pipeline'i kapatın:

```bash
PLUME_SITE_NGINX_STRICT=false
PLUME_SITE_NGINX_STRICT_ON_RELOAD=false
```

Aksi halde test, gercek strict publish / cift reload / include dizini beklentilerine karisir. Strict publish testleri ayri scriptlerde `STRICT=true` ve `PLUME_NGINX_INCLUDE_DIR` ile calisir.

### Servis smoke (phase6 tarzi)

PHP extension auto-sync yan etkilerini kesmek icin:

```bash
PLUME_PHP_EXTENSIONS_AUTO_SYNC=false
```

Ornek: `tests/phase6_service_smoke.sh`.

### Native `services.yml` manifest (D-104)

- Tum registry servisleri `~/.config/plume/services.yml` ile `PLUME_*_ENABLED` / version env’lerine map edilir; eksik anahtar defaults kalir.
- Dogrulama: `tests/phase11_services_manifest_smoke.sh`, `tests/phase11_services_manifest_full_smoke.sh` (hermetic `PLUME_SERVICES_MANIFEST_FILE`).
- Detay: [services-manifest.md](./services-manifest.md), `services manifest show`, `services provision --from-manifest`.

### pipefail ve SIGPIPE

Ana smoke script `set -euo pipefail` kullanir. **`./plume.sh ... | grep -q`** pattern'i grep erken cikinca SIGPIPE / non-zero pipeline ile fail edebilir.

```bash
# YANLIS (pipefail altinda kirilgan)
./plume.sh site check "$ID" | grep -q '^mode: native$'

# DOGRU
OUT="$(./plume.sh site check "$ID")"
printf '%s\n' "$OUT" | grep -q '^mode: native$'
# veya: grep -q ... <<< "$OUT"  (tek satir icin)
```

Alt shell icinde `bash -lc '... | grep -q ...'` bazi testlerde bilincli kullanilir; **yeni test yazarken** ciktiyi once yakala.

### macOS permissions (native gelistirme)

- Site path **Desktop, Documents, Downloads** altindaysa TCC riski; `doctor web` / interaktif menu.
- **Full Disk Access**: Homebrew **nginx** ve **php-fpm** binary'leri — `plume.sh` / `plumectl` / hayali "Plume.app" **eklenmez**.
- Rehber: `plume init permissions --interactive`, `--open`, `--reveal`.
- Detay: [macos-permissions.md](./macos-permissions.md).

### Integration (opsiyonel)

Gercek host paket kurulumu:

```bash
PLUME_RUN_INTEGRATION=1 ./tests/phase12_native_host_provision_smoke.sh
```

Release `--release` zincirinde varsayilan mock/non-integration calisir.

---

## Where tests live

| Tur | Konum / ornek |
|-----|----------------|
| Tekil smoke | `tests/phase{N}_*_smoke.sh` |
| E2E aggregator | `phase10_e2e_matrix_smoke.sh`, `phase11_e2e_matrix_smoke.sh` — ic ice phase calistirir |
| Suite girisi | `tests/run_smoke_suite.sh` |
| `--all` | `*e2e_matrix*` **haric** (cift calisma onlemi, D-101) |

Yeni smoke eklerken: mevcut phase numarasi ve isimlendirme (`phase11_foo_smoke.sh`); gerekirse `phase11_e2e_matrix` veya `run_smoke_suite` listesine ekleme karari + dokuman.

---

## Pre-PR checklist

- [ ] `./tests/run_smoke_suite.sh --release` (veya degisiklik kapsamina gore `--phase11-full` / `--all`)
- [ ] Komut/flag/ENV sozlesmesi degisti mi → `docs/commands/` + `docs/contracts/` + `docs/operations/env-contract.md`
- [ ] Davranis/karar degisti mi → `implementation/05-decision-log.md`
- [ ] macOS UX / TCC → `docs/operations/macos-permissions.md` ve ilgili command doc
- [ ] Release adimlari degisti mi → [release-readiness.md](./release-readiness.md) + README Test bolumu
