# Plume

Plume, Laravel projeleri icin Linux/macOS uzerinde calisacak 3 modlu (`native`, `docker-lite`, `laradock-bridge`) bir operasyon util'idir.

**Guncel durum:** Faz 1–16 tamamlandi; sonraki aday **Faz 17** (docker-lite unfreeze, bkz. [implementation/future-roadmap.md](implementation/future-roadmap.md)). Faz 7 (`docker-lite`) **beta-frozen**.

Detayli ilerleme: [implementation/phase-tracker.md](implementation/phase-tracker.md)

## Naming Policy

- Product: `Plume`
- Official CLI binary: `plumectl`
- Local test wrapper: `./plume.sh`
- Optional alias: `plume`
- Repository: `plume` (GitHub); Packagist/formula alias: `laravel-plume`

## Ozellik Ozeti

- Modular CLI (`bin/plumectl`, `lib/*`), global flag'ler (`--json`, `--yes`, `--quiet`, `--env-file`)
- Modlar: `mode current`, `mode use`, `mode path` (laradock-bridge context)
- Site registry ve lifecycle: `site add|list|check|update|publish|remove|modes`, nginx/apache2/caddy, TLS, hosts sync, strict publish
- Servisler: `services supported|status|install|up|down|update|health|logs`, native laradock-benzeri alias contract (`php-fpm`, `workspace`, `@core/@web/@db/@queue`)
- Native PHP: `php list|install|use|alias`, `php ext sync|resolve|doctor`, `php shim`, `init shell`, `env where|init`
- Laradock-bridge: bootstrap, sync, runtime parity test paketi
- Ops: `doctor`, `backup`, `deploy plan|apply|rollback|failback`, `security`, `monitor`, `project init`
- OS prereq: `prereq check|explain` (`brew` / `apt` / `dnf`)

Native modda **PHP** icin gercek host kurulumu (`brew`/`apt`) vardir. Diger servisler varsayilan olarak state/port orchestration kullanir; gercek host kurulumu icin `PLUME_NATIVE_HOST_PROVISION=true` (bkz. [docs/commands/services.md](docs/commands/services.md)). macOS'ta **Mailpit** native brew ile desteklenir (`services up mailpit`; D-109).

## Local Run

Repo kokunden:

```bash
./plume.sh --help
./plume.sh version
./plume.sh mode current
```

Global env varsayilani: `~/.config/plume/.env` (`env init` ile olusturulabilir). Native stack manifest (Laradock benzeri): `~/.config/plume/services.yml` — bkz. [docs/operations/services-manifest.md](docs/operations/services-manifest.md).

Ilk kurulum runbook: [docs/operations/first-run-onboarding.md](docs/operations/first-run-onboarding.md)

```bash
./plume.sh env init
./plume.sh init host          # otomatik de olusur (PLUME_AUTO_HOST_BOOTSTRAP)
./plume.sh init onboarding
./plume.sh doctor web
```

## Kurulum (Release)

1. Repoyu klonlayin veya release artifact indirin.
2. `bin/plumectl` dosyasini PATH'e ekleyin veya `./plume.sh` kullanin.
3. `./plume.sh env init --from=templates/native-local.env.example` (native local preset, opsiyonel).
4. `./plume.sh init onboarding` — macOS TCC, nginx port ve path kontrol listesi.
5. `./plume.sh init shell` ile PHP shim PATH blogu (opsiyonel).

Release oncesi smoke: [docs/operations/release-readiness.md](docs/operations/release-readiness.md)

## Ornek Komutlar

```bash
./plume.sh site add --path=/path/to/laravel/public --domain=myapp.test --server=nginx --publish
./plume.sh services up @core --mode=native
./plume.sh php use 8.3
./plume.sh doctor check --mode=native --deep
./plume.sh deploy plan --mode=native
./plume.sh --yes deploy apply --mode=native --skip-backup
```

## Documentation Map

- Implementation context: `implementation/`
- Phase tracker: `implementation/phase-tracker.md`
- Per-phase checklists: `implementation/phases/`
- Commands docs: `docs/commands/`
- Operations docs: `docs/operations/`
- Contracts: `docs/contracts/`

## Test (Release Matrix)

Tek giris noktasi (CI ile ayni adimlar, onerilen yayin oncesi):

```bash
./tests/run_smoke_suite.sh              # default: --release
./tests/run_smoke_suite.sh --ci         # .github/workflows/smoke-tests.yml ile birebir
```

Ek derinlik (opsiyonel):

```bash
./tests/run_smoke_suite.sh --phase11-full   # tum phase11 smoke scriptleri (matrix haric)
PLUME_RUN_LINUX_TESTS=1 ./tests/run_smoke_suite.sh --all   # tum smoke scriptleri
./tests/run_smoke_suite.sh --all --linux    # --all + Linux prereq matrix (phase3)
```

Manuel matrix (eski dokuman uyumu; `phase10_e2e_matrix` zaten `phase11_e2e_matrix` calistirir):

```bash
./tests/phase10_e2e_matrix_smoke.sh
./tests/phase11_e2e_matrix_smoke.sh
PLUME_RUN_LINUX_TESTS=1 tests/phase3_prereq_smoke.sh
```

Integration (gercek host paket kurulumu, opsiyonel):

```bash
PLUME_RUN_INTEGRATION=1 ./tests/phase12_native_host_provision_smoke.sh
```

Detay: [docs/operations/release-readiness.md](docs/operations/release-readiness.md). AI/esli gelistirme ve smoke ogrenimleri: [docs/operations/ai-assisted-development.md](docs/operations/ai-assisted-development.md).
