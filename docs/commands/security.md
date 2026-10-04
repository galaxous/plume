# `security`

## Purpose

OS/firewall preflight check, local secret management, and multi-domain local cert generation.

## Usage

```bash
plumectl security check --mode=native
plumectl security check --mode=native --skip-prereq
plumectl security secrets set APP_KEY base64:xxxx
plumectl security secrets get APP_KEY
plumectl security secrets list
plumectl security secrets unset APP_KEY
plumectl security secrets generate APP_SECRET --length=40
plumectl security cert issue --domains=app.test,www.app.test --days=30
plumectl security cert list
plumectl security cert show <cert-id>
plumectl security cert renew <cert-id> --days=30
```

## Parameters

- `check`
  - `--mode=<native|docker-lite|laradock-bridge>`
  - `--skip-prereq`
- `secrets`
  - `list`
  - `get <KEY>`
  - `set <KEY> <VALUE>`
  - `unset <KEY>`
  - `generate <KEY> [--length=32]`
- `cert`
  - `issue --domains=d1,d2 [--days=30] [--name=custom-id]`
  - `list`
  - `show <id>`
  - `renew <id> [--days=30]`

Certificate storage (state):

- Directory: `$(plume state dir)/certs/<cert-id>/` (default: `~/.config/plume/certs/<cert-id>/`, override with `PLUME_STATE_DIR`)
- Files: `cert.crt`, `cert.key`, `san.ext`, `meta.env` (id and domain list)
- Site binding: `plumectl site add|update ... --cert-id=<cert-id> [--https-port=443] --publish`
- Disable site TLS (remove redirect): `plumectl site update <id> --clear-cert --publish` (`docs/commands/site.md`)

## Output / Exit Codes

- `0`: success
- `1`: general error
- `2`: prereq/parameter error

## Examples

```bash
plumectl security check --mode=laradock-bridge
plumectl security secrets set DB_PASSWORD super-secret
plumectl security secrets get DB_PASSWORD
plumectl security cert issue --domains=api.test,admin.api.test --days=15
plumectl site add --path=/var/www/myapp --domain=myapp.test --server=nginx --cert-id=<cert-id> --https-port=443 --publish
```

## Error scenarios

- Invalid key format (outside `[A-Z0-9_]`)
- Secret not found
- Security prereq profile fail
- Without `openssl`, cert issue/renew will not run
