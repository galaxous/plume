# Security Ops Baseline

## Guard Policy

`--yes` is required for the following critical commands:

- `mode use --force`
- `mode path set|clear --force`
- `services workspace reinit`
- `services update`
- `backup restore`

## Audit Trail

Runtime events are written to the SQLite `runtime_events` table:

- `ops.*` (status/health/logs/monitor)
- `critical.*.(blocked|approved)` (guard decisions)
- `backup.*` (create/restore)

## Incident Hygiene

- `plumectl doctor check --deep`
- `plumectl monitor summary --strict`
- `plumectl monitor events --limit=50`
- `plumectl security check`

## Secret Baseline

- `plumectl security secrets set <KEY> <VALUE>`
- `plumectl security secrets get <KEY>`
- `plumectl security secrets list`
- `plumectl security secrets generate <KEY> --length=40`

## TLS Baseline (Local)

- `plumectl security cert issue --domains=app.test,www.app.test --days=30`
- `plumectl security cert list`
- `plumectl security cert show <cert-id>`
- `plumectl security cert renew <cert-id> --days=30`

Run these commands as part of the incident snapshot chain.
