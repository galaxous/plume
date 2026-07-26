# Core Prerequisites Matrix

Amac: Servis paketlerinden once calismasi gereken cekirdek bagimliliklari standardize etmek.

## Kural

- Core prereq eksikse ilgili komut fail-fast durur.
- Cikti su bilgileri tasir:
  - eksik komut/paket
  - neden gerekli
  - OS'e ozel kurulum onerisi

## OS Bazli Paket Yoneticisi

- macOS: `brew`
- Linux:
  - Debian/Ubuntu: `apt`
  - RHEL/Fedora: `dnf`
  - Digerleri: `manual` (rehber verilir, otomatik kurulum yok)

## Prereq Profilleri (Phase 3)

1. `base`
- Komutlar: `bash sed awk grep cut xargs tar gzip curl`
- Kullanim: tum komutlar icin minimum profil

2. `native-install`
- Komutlar: `sudo` + OS package manager (`brew/apt/dnf`)
- Kullanim: host uzerine servis kurulum adimlari

3. `git-ops`
- Komutlar: `git ssh`
- Kullanim: repo/remote operasyonlari

4. `docker-lite`
- Komutlar: `docker`
- Kullanim: docker-lite ve laradock-bridge pathleri

5. `security-check`
- Komutlar:
  - macOS: `pfctl`
  - Linux baseline: `getenforce`
- Kullanim: firewall/OS security preflight baslangic kontrolu

6. `horizon-runtime`
- Komutlar: `supervisorctl php`
- Kullanim: Laravel Horizon process kontrolu

7. `laravel-bootstrap`
- Komutlar: `php composer`
- Kullanim: `project init` bootstrap adimlari

8. `frontend-build`
- Komutlar: `node npm`
- Kullanim: build/dev server akislari

## CLI Davranisi

- `./plume.sh prereq check --profile=<name>`
  - eksikleri listeler
  - exit code: eksik varsa `2`, yoksa `0`
- `./plume.sh prereq explain`
  - profil + gerekce listesini verir
- `./plume.sh --json prereq check --profile=<name>`
  - machine-readable cikti verir

## Root Boundary (Phase 3)

- Kurulum/guncelleme adimlari root/sudo ister:
  - `./plume.sh services install ...`
  - `./plume.sh services update`
- Runtime odakli komutlar root istemez:
  - `services status`, `services supported`, `services up/down` (phase1/2 stub seviyesinde)

## Linux Test Cozumu (Mac Uzerinde)

- Lokal Linux dogrulamasi container ile yapilir:
  - `tests/linux_prereq_matrix.sh`
  - Ubuntu (`apt`) ve Fedora (`dnf`) containerlarinda prereq profilleri calistirilir
- Tum Phase 3 smoke:
  - `tests/phase3_prereq_smoke.sh`
  - Linux matrix dahil calistirmak icin: `PLUME_RUN_LINUX_TESTS=1 tests/phase3_prereq_smoke.sh`
