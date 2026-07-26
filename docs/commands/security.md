# `security`

## Amac

OS/firewall preflight kontrolu, lokal secret yonetimi ve multi-domain local cert uretimi.

## Kullanim

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

## Parametreler

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

Sertifika depolama (state):

- Dizin: `$(plume state dir)/certs/<cert-id>/` (varsayılan: `~/.config/plume/certs/<cert-id>/`, `PLUME_STATE_DIR` ile override)
- Dosyalar: `cert.crt`, `cert.key`, `san.ext`, `meta.env` (id ve domain listesi)
- Site bağlama: `plumectl site add|update ... --cert-id=<cert-id> [--https-port=443] --publish`
- Site TLS kapatma (redirect kaldırma): `plumectl site update <id> --clear-cert --publish` (`docs/commands/site.md`)

## Cikti / Exit Codes

- `0`: basarili
- `1`: genel hata
- `2`: prereq/parametre hatasi

## Ornekler

```bash
plumectl security check --mode=laradock-bridge
plumectl security secrets set DB_PASSWORD super-secret
plumectl security secrets get DB_PASSWORD
plumectl security cert issue --domains=api.test,admin.api.test --days=15
plumectl site add --path=/var/www/myapp --domain=myapp.test --server=nginx --cert-id=<cert-id> --https-port=443 --publish
```

## Hata Senaryolari

- Geçersiz key formati (`[A-Z0-9_]` disi)
- Secret bulunamiyor
- Security prereq profile fail
- `openssl` yoksa cert issue/renew calismaz
