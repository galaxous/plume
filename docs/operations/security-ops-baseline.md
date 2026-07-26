# Security Ops Baseline

## Guard Policy

Asagidaki kritik komutlar icin `--yes` zorunludur:

- `mode use --force`
- `mode path set|clear --force`
- `services workspace reinit`
- `services update`
- `backup restore`

## Audit Trail

Runtime olaylari SQLite `runtime_events` tablosuna yazilir:

- `ops.*` (status/health/logs/monitor)
- `critical.*.(blocked|approved)` (guard kararlari)
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

Bu komutlari incident snapshot zincirinin parcasi olarak calistirin.
