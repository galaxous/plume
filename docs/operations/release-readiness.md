# Release Readiness Runbook (Phase-10+ Baseline)

Bu dokuman, `plume` yayin oncesi minimum kontrol zincirini tanimlar.

## 0) Unified smoke runner (onerilen)

Yerel pre-release ve CI ile ayni adimlar:

```bash
./tests/run_smoke_suite.sh              # default --release
./tests/run_smoke_suite.sh --ci         # GitHub Actions smoke-tests.yml ile birebir
```

`--release` / `--ci` zinciri:

1. `phase10_e2e_matrix_smoke.sh` (icinde `phase11_e2e_matrix_smoke.sh` dahil)
2. `phase14_golden_json_smoke.sh`
3. `phase12_native_host_provision_smoke.sh`
4. `phase12_site_publish_auto_provision_web_smoke.sh`
5. `phase13_deploy_apply_smoke.sh`
6. `phase15_scheduler_queue_smoke.sh` (Faz 15 scheduler / queue ops)
7. `phase16_plume_yml_v2_smoke.sh` (Faz 16 project `plume.yml` MVP)
8. `phase17_native_stack_db_smoke.sh` (Faz 17 native DB/phpmyadmin)
9. `phase17_native_stack_broker_smoke.sh` (Faz 17 redis/mongodb/rabbitmq)
10. `phase17_native_stack_webui_smoke.sh` (Faz 17 web UI + url)

Beklenen sonuc:

- Her adim `[RUN]` / `[PASS]` verir; suite sonu `run-smoke-suite:ok`.
- Ilk hata `[FAIL]` ile fail-fast; ozet `run-smoke-suite:fail`.

Ek kapsam:

```bash
./tests/run_smoke_suite.sh --phase11-full
PLUME_RUN_LINUX_TESTS=1 ./tests/run_smoke_suite.sh --all
```

README release matrix’teki ayri `phase3` Linux kontrolu icin `--all --linux` veya `PLUME_RUN_LINUX_TESTS=1` kullanin.

## 1) Baseline Matrix (manuel)

Asagidaki komut tek seferde native + laradock-bridge + docker-lite(beta-frozen) regresyon kontrolunu yapar (phase 11 ozet runner dahil):

```bash
./tests/phase10_e2e_matrix_smoke.sh
```

Phase 11 native adapter derinligi (ayrica veya matrix icinde):

```bash
./tests/phase11_e2e_matrix_smoke.sh
```

Golden JSON contract (phase 14):

```bash
./tests/phase14_golden_json_smoke.sh
```

Beklenen sonuc:

- Komut `phase10-e2e-matrix-smoke:ok` ile biter.
- Her alt adim `[PASS]` satiri verir.

## 2) Critical Ops Regression

Release oncesi kritik operasyonlar:

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

CLI parse kontratini etkileyen degisikliklerde:

```bash
./tests/phase8_adapter_contract_normalization_smoke.sh
```

ve `docs/contracts/cli-output-contract.md` dosyasi guncellenmelidir.

## 4) Release Evidence

Asagidaki kanitlar toplanmis olmali:

- Matrix komut ciktilari (`[PASS]` zinciri)
- Phase checklist guncellemeleri (`implementation/phases/phase-10.md`, `phase-15.md` vb.)
- Tracker satiri (`implementation/phase-tracker.md`)
- Decision log kaydi (`implementation/05-decision-log.md`)

## 5) Stop/No-Go Rules

- Herhangi bir smoke script fail olursa release durdurulur.
- `critical guard`, `rollback`, `security cert` testlerinden biri fail ise no-go.
- CLI contract degisimi dokumante edilmediyse no-go.
