# `services` mailpit (native)

## Purpose

Laravel local SMTP/UI: Mailpit HTTP + SMTP. No container hostname; host `127.0.0.1`.

Laravel `.env`: `MAIL_HOST=127.0.0.1` `MAIL_PORT=1025`.

## Usage

```bash
MAILPIT_ENABLED=true
plumectl services up mailpit --mode=native
plumectl services url mailpit --mode=native
plumectl services credentials mailpit --mode=native
```

## Parameters

- HTTP: `PLUME_MAILPIT_PORT` (default `8025`)
- SMTP: `PLUME_MAILPIT_SMTP_PORT` (default `1025`)
- Native install: **macOS Homebrew only**; on Linux WARN + docker-lite/manual

## Output / exit-code

- `url=http://127.0.0.1:8025`
- credentials: `host`, `http_port`, `smtp_port`, `url`
- Linux native up: exit `2` + Homebrew-only message

## Examples

```bash
plumectl services up @core --mode=native   # if mailpit enabled
```

## Error scenarios

- Linux native: provision not supported (existing WARN)
- Port conflict: HTTP port allocate
