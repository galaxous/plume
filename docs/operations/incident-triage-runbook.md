# Incident Triage Runbook

Bu runbook, `plumectl` komutlariyla hizli tespit ve toparlama akisini tanimlar.

## 1. Incident Snapshot

```bash
plumectl monitor runbook --mode=<native|laradock-bridge|docker-lite> --scenario=incident
plumectl monitor summary --mode=<mode>
plumectl doctor check --mode=<mode> --deep
plumectl monitor events --mode=<mode> --limit=50
```

## 2. Recovery Sequence

```bash
plumectl monitor runbook --mode=<mode> --scenario=recovery
plumectl services down all --mode=<mode>
plumectl sync state --mode=<mode>
plumectl services up all --mode=<mode>
plumectl monitor summary --mode=<mode> --strict
```

## 3. Port Conflict Sequence

```bash
plumectl monitor runbook --mode=<mode> --scenario=ports-conflict
plumectl status --mode=<mode>
plumectl doctor ports --mode=<mode>
plumectl sync state --mode=<mode>
```

## Notlar

- `monitor summary --strict` kritik issue varsa `exit code 2` dondurur.
- `monitor events` ciktilari `runtime_events` tablosundan okunur.
- Kritik guard gerektiren komutlarda `--yes` kullanilmalidir.
