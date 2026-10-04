# Incident Triage Runbook

This runbook defines a fast detect-and-recover flow with `plumectl` commands.

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

## Notes

- `monitor summary --strict` returns `exit code 2` if there is a critical issue.
- `monitor events` output is read from the `runtime_events` table.
- On commands that require a critical guard, `--yes` must be used.
