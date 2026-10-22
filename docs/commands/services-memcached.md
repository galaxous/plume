# `services` memcached (native)

## Purpose

Native cache like the Laradock `memcached` container: enable → up → credentials. Laravel `.env`: `MEMCACHED_HOST=127.0.0.1`.

## Usage

```bash
MEMCACHED_ENABLED=true
plumectl services up memcached --mode=native
plumectl services credentials memcached --mode=native
plumectl services status memcached --mode=native
```

## Parameters

- `--mode=native`
- Port: `PLUME_MEMCACHED_PORT` / `MEMCACHED_PORT` (default `11211`)
- OS: brew `memcached`; apt/dnf `memcached` + systemd

## Output / exit-code

- credentials: `host=127.0.0.1` `port=11211`
- `0` success; `2` non-native mode or install error

## Examples

```bash
plumectl services up @cache --mode=native
plumectl services env show memcached --mode=native
```

## Error scenarios

- Port in use: allocate `+1..+50` (registry port contract)
- Linux: start fails without systemd
