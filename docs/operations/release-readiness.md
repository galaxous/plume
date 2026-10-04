# Release Readiness Runbook (Phase-10+ Baseline)

This document defines the minimum pre-publish check chain for `plume`.

## 0) Unified smoke runner (recommended)

Same steps for local pre-release and CI:

```bash
./tests/run_smoke_suite.sh              # default --release
./tests/run_smoke_suite.sh --ci         # identical to GitHub Actions smoke-tests.yml
```

`--release` / `--ci` chain:

1. `phase10_e2e_matrix_smoke.sh` (includes `phase11_e2e_matrix_smoke.sh`)
2. `phase14_golden_json_smoke.sh`
3. `phase12_native_host_provision_smoke.sh`
4. `phase12_site_publish_auto_provision_web_smoke.sh`
5. `phase13_deploy_apply_smoke.sh`
6. `phase15_scheduler_queue_smoke.sh` (Phase 15 scheduler / queue ops)
7. `phase16_plume_yml_v2_smoke.sh` (Phase 16 project `plume.yml` MVP)
8. `phase17_native_stack_db_smoke.sh` (Phase 17 native DB/phpmyadmin)
9. `phase17_native_stack_broker_smoke.sh` (Phase 17 redis/mongodb/rabbitmq)
10. `phase17_native_stack_webui_smoke.sh` (Phase 17 web UI + url)
11. `phase18_native_pgadmin_smoke.sh` (Phase 18 native pgAdmin)
12. `phase19_native_service_contract_smoke.sh` (Phase 19 `@core` / `services use` / status truth)
13. `phase20_native_cache_broker_smoke.sh` (Phase 20 memcached + webuis)
14. `phase21_queue_honesty_smoke.sh` (Phase 21 meilisearch/minio toggle-only)
15. `phase22_native_horizon_smoke.sh` (Phase 22 native Horizon)
16. `phase23_supervisor_doctor_smoke.sh` (Phase 23 supervisor doctor/upgrade)
17. `phase24_per_site_horizon_smoke.sh` (D-150 per-site Horizon programs)

Expected result:

- Each step prints `[RUN]` / `[PASS]`; suite ends with `run-smoke-suite:ok`.
- First error fail-fasts with `[FAIL]`; summary `run-smoke-suite:fail`.

Extra coverage:

```bash
./tests/run_smoke_suite.sh --phase11-full
PLUME_RUN_LINUX_TESTS=1 ./tests/run_smoke_suite.sh --all
```

For the separate `phase3` Linux check in the README release matrix, use `--all --linux` or `PLUME_RUN_LINUX_TESTS=1`.

## 1) Baseline Matrix (manual)

The following command runs native + laradock-bridge + docker-lite(beta-frozen) regression in one shot (including the phase 11 summary runner):

```bash
./tests/phase10_e2e_matrix_smoke.sh
```

Phase 11 native adapter depth (separately or inside the matrix):

```bash
./tests/phase11_e2e_matrix_smoke.sh
```

Golden JSON contract (phase 14):

```bash
./tests/phase14_golden_json_smoke.sh
```

Expected result:

- The command ends with `phase10-e2e-matrix-smoke:ok`.
- Each sub-step prints a `[PASS]` line.

## 2) Critical Ops Regression

Critical operations before release:

```bash
./tests/phase10_install_to_operate_smoke.sh
./tests/phase10_rollback_regression_smoke.sh
./tests/phase9_critical_guard_smoke.sh
./tests/phase9_backup_smoke.sh
./tests/phase9_deploy_rollback_smoke.sh
./tests/phase9_security_smoke.sh
./tests/phase9_security_cert_smoke.sh
```

## 3) Adapter Contract Baseline

On changes that affect the CLI parse contract:

```bash
./tests/phase8_adapter_contract_normalization_smoke.sh
```

and `docs/contracts/cli-output-contract.md` must be updated.

## 4) Release Evidence

The following evidence should be collected:

- Matrix command outputs (`[PASS]` chain)
- Phase checklist updates (`implementation/phases/phase-10.md`, `phase-15.md`, etc.)
- Tracker row (`implementation/phase-tracker.md`)
- Decision log entry (`implementation/05-decision-log.md`)

## 5) Stop/No-Go Rules

- If any smoke script fails, the release is stopped.
- If any of `critical guard`, `rollback`, or `security cert` fails, it is a no-go.
- If a CLI contract change is not documented, it is a no-go.
