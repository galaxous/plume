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
  - `doctor` commands wired into the router/help chain (`check`, `services`, `ports`).
  - `tests/phase9_doctor_smoke.sh` added and baseline diagnostic tests passed.
  - `docs/commands/status-health-logs.md` aligned with doctor subcommands.
  - `status/health/logs/monitor` command family activated; `--watch` and `monitor events` added.
  - Runtime audit event recording (`ops.*`) added for `status/health/logs/monitor` calls.
  - `tests/phase9_status_monitor_smoke.sh` added.
  - `--yes` guard added for critical commands:
    - `mode use --force`
    - `mode path set|clear --force`
    - `services workspace reinit`
    - `services update`
  - Guard decisions are audited to the `runtime_events` table as `critical.*.(blocked|approved)`.
  - `tests/phase9_critical_guard_smoke.sh` added.
  - `monitor runbook` subcommand added (`incident|recovery|ports-conflict`).
  - `docs/operations/incident-triage-runbook.md` added and linked from the operations index.
  - `backup` command family baseline activated (`create|list|show|restore`).
  - `docs/commands/backup.md`, `docs/operations/backup-restore-runbook.md`, `docs/operations/security-ops-baseline.md` added.
  - `tests/phase9_backup_smoke.sh` added.
  - Rollback/failback baseline added to the `deploy` command family (`plan|rollback|failback`).
  - `docs/commands/deploy.md` and `tests/phase9_deploy_rollback_smoke.sh` added.
  - `security` command family added (`check`, `secrets list|get|set|unset|generate`).
  - `docs/commands/security.md` and `tests/phase9_security_smoke.sh` added.
  - `project env sync-secrets` added; `secrets.env` keys can be written to the Laravel project `.env` file.
  - `tests/phase9_project_env_sync_secrets_smoke.sh` added.
  - `security cert` command family added (`issue|list|show|renew`) and multi-domain local cert baseline delivered.
  - `tests/phase9_security_cert_smoke.sh` added.
  - `--cert-id` and `--https-port` support added to `site add|update` commands.
  - Site publish snippets render with HTTPS blocks when a cert is bound (nginx/apache2/caddy).
  - `tests/phase9_site_tls_smoke.sh` added.
- Open risks:
  - Resource consumption growth risk in long-lived terminal sessions for watch/monitor commands.
  - Production risk is high if root boundary and audit trail are not modeled correctly for cert/secret operations.
  - Mode/path context errors in backup/restore scenarios carry a hard-to-recover data-loss risk.
  - Because the local TLS baseline is self-signed, production trust/ACME lifecycle must be handled separately in Phase-10 scope.
  - Secret store is state-file based; KMS/Vault adapter integration is a candidate for phase-10 adapter readiness work.

## Herd Parity/Beyond Review

- Herd parity:
  - Site lifecycle (`add/update/publish/list/check/remove`) completed.
  - PHP version/site-level routing + TLS site binding baseline present.
  - Health/doctor/monitor visibility and single-command operation flows present.
- Beyond Herd:
  - Single command surface focused on `native` + `laradock-bridge` parity.
  - Rollback/failback + backup + security audit event chain.
  - Project `.env` secret sync bridge (`project env sync-secrets`).

## Active Delivery Slice

- First delivery slice:
  - `doctor` command family baseline (`doctor check`, `doctor services`, `doctor ports`)
  - Basic monitor output contract for `status/health/logs --watch` telemetry collection
  - Fail-fast + audit event recording for critical failures
