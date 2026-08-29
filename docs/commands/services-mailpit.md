# `services` mailpit (native)

## Amac

Laravel yerel SMTP/UI: Mailpit HTTP + SMTP. Container hostname yok; host `127.0.0.1`.

Laravel `.env`: `MAIL_HOST=127.0.0.1` `MAIL_PORT=1025`.

## Kullanim

```bash
MAILPIT_ENABLED=true
./plume.sh services up mailpit --mode=native
./plume.sh services url mailpit --mode=native
./plume.sh services credentials mailpit --mode=native
```

## Parametreler

- HTTP: `PLUME_MAILPIT_PORT` (varsayilan `8025`)
- SMTP: `PLUME_MAILPIT_SMTP_PORT` (varsayilan `1025`)
- Native kurulum: **macOS Homebrew only**; Linux’ta WARN + docker-lite/manuel

## Cikti / exit-code

- `url=http://127.0.0.1:8025`
- credentials: `host`, `http_port`, `smtp_port`, `url`
- Linux native up: exit `2` + Homebrew-only mesaji

## Ornekler

```bash
./plume.sh services up @core --mode=native   # mailpit enabled ise
```

## Hata senaryolari

- Linux native: provision desteklenmez (mevcut WARN)
- Port cakismasi: HTTP port allocate
