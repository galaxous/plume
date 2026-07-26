# Phase 09 - Observability, Ops, Production

## Objective

- Production-grade operations: monitoring, security checks, certs, secrets, rollback, backups.

## Status

- `done` (started: 2026-04-03, completed: 2026-04-03)
- Priority: high

## Scope Checklist

- [x] `doctor/health/logs/monitor` suite (baseline)
- [x] TLS/certificate automation (multi-domain, local baseline via `security cert`)
- [x] Secret management baseline (`security secrets`)
- [x] Rollback/failback mechanism (`deploy rollback|failback`)
- [x] Optional backup scope: config + DB
- [x] Firewall/OS security checks (`security check`)

## Implementation Checklist

- [x] Status/health collectors complete (baseline wrappers + watch)
- [x] Alert-worthy failures clearly surfaced (`monitor summary` OVERALL + issues + `--strict`)
- [x] Critical commands protected and audited (`--yes` guards + runtime_events)
- [x] Recovery runbooks wired to commands (`monitor runbook` + incident runbook doc)

## Test Checklist

- [x] Health/doctor integration tests (smoke)
- [x] Cert issue/renew tests (smoke, local openssl)
- [x] Rollback failure-path tests (guard + failback smoke baseline)
- [x] Backup/restore E2E tests
- [x] Security/firewall smoke tests

## Documentation Checklist

- [x] `docs/commands/status-health-logs.md`
- [x] Production runbooks (incident triage baseline)
- [x] Security and backup docs
- [x] Decision log update

## Gate Checklist (Mandatory)

- [x] Feature scope complete
- [x] Tests pass
- [x] Decision log updated
- [x] Next-phase risks written
- [x] Herd parity/beyond impact reviewed

## Notes

- Date: 2026-04-03
- Owner:
- Related PR/Commit:
- Progress:
  - `doctor` komutlari router/help zincirine baglandi (`check`, `services`, `ports`).
  - `tests/phase9_doctor_smoke.sh` eklendi ve baseline tanisal testler gecti.
  - `docs/commands/status-health-logs.md` doctor alt komutlariyla hizalandi.
  - `status/health/logs/monitor` komut ailesi aktif edildi; `--watch` ve `monitor events` eklendi.
  - `status/health/logs/monitor` cagrilari icin runtime audit event kaydi (`ops.*`) eklendi.
  - `tests/phase9_status_monitor_smoke.sh` eklendi.
  - Kritik komutlar icin `--yes` guard eklendi:
    - `mode use --force`
    - `mode path set|clear --force`
    - `services workspace reinit`
    - `services update`
  - Guard kararlari `runtime_events` tablosuna `critical.*.(blocked|approved)` olarak audit ediliyor.
  - `tests/phase9_critical_guard_smoke.sh` eklendi.
  - `monitor runbook` alt komutu eklendi (`incident|recovery|ports-conflict`).
  - `docs/operations/incident-triage-runbook.md` eklendi ve operasyon indeksine baglandi.
  - `backup` komut ailesi baseline aktif edildi (`create|list|show|restore`).
  - `docs/commands/backup.md`, `docs/operations/backup-restore-runbook.md`, `docs/operations/security-ops-baseline.md` eklendi.
  - `tests/phase9_backup_smoke.sh` eklendi.
  - `deploy` komut ailesine rollback/failback baseline eklendi (`plan|rollback|failback`).
  - `docs/commands/deploy.md` ve `tests/phase9_deploy_rollback_smoke.sh` eklendi.
  - `security` komut ailesi eklendi (`check`, `secrets list|get|set|unset|generate`).
  - `docs/commands/security.md` ve `tests/phase9_security_smoke.sh` eklendi.
  - `project env sync-secrets` eklendi; `secrets.env` keyleri Laravel proje `.env` dosyasina yazilabiliyor.
  - `tests/phase9_project_env_sync_secrets_smoke.sh` eklendi.
  - `security cert` komut ailesi eklendi (`issue|list|show|renew`) ve multi-domain local cert baseline saglandi.
  - `tests/phase9_security_cert_smoke.sh` eklendi.
  - `site add|update` komutlarina `--cert-id` ve `--https-port` destegi eklendi.
  - Site publish snippetleri cert bagliyken HTTPS bloklariyla render ediliyor (nginx/apache2/caddy).
  - `tests/phase9_site_tls_smoke.sh` eklendi.
- Open risks:
  - Watch/monitor komutlarinda uzun sureli terminal oturumlarinda kaynak tuketimi artis riski.
  - Cert/secret islemlerinde root boundary ve audit izi dogru modellenmezse production riski yuksek.
  - Backup/restore senaryolarinda mode/path context hatalari geri donusu zor veri kaybi riski tasir.
  - Local TLS baseline self-signed oldugu icin production trust/ACME lifecycle ayrica Phase-10 scope'unda ele alinmali.
  - Secret store state-file tabanli; KMS/Vault adapter entegrasyonu phase-10 adapter hazirlik calismasina aday.

## Herd Parity/Beyond Review

- Herd parity:
  - Site lifecycle (`add/update/publish/list/check/remove`) tamamlandi.
  - PHP version/site-level routing + TLS site binding baseline mevcut.
  - Health/doctor/monitor gorunurlugu ve tek-komut operasyon akislari mevcut.
- Beyond Herd:
  - `native` + `laradock-bridge` parity odakli tek komut yuzeyi.
  - Rollback/failback + backup + security audit event zinciri.
  - Project `.env` secret sync bridge (`project env sync-secrets`).

## Active Delivery Slice

- Ilk teslim dilimi:
  - `doctor` komut ailesi baseline (`doctor check`, `doctor services`, `doctor ports`)
  - `status/health/logs --watch` telemetry toplamasi icin temel monitor output kontrati
  - Critical failures icin fail-fast + audit event kaydi
