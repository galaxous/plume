# `services supervisor`

## Amac

Sistem birincil native supervisor (brew services / systemd): paket upgrade + config migrasyonu ve template tabanli program conf ekleme (D-149).

## Kullanim

```bash
./plume.sh doctor supervisor
./plume.sh services supervisor upgrade --force --yes
./plume.sh services supervisor upgrade --force --yes --dry-run
./plume.sh services supervisor program add
./plume.sh services supervisor program add --template=horizon --non-interactive
./plume.sh services up supervisor
./plume.sh services up horizon
./plume.sh services up horizon --site=<site-id>
```

Horizon icin tercih edilen yol: `site update <id> --horizon` + `services up horizon` (D-150, site basina `plume-horizon-<site-id>`). Manuel `program add --template=horizon` ozel worker icin.

Teşhis ve log: `plumectl doctor supervisor`, `plumectl services logs horizon` — `supervisorctl` yazmaniz gerekmez (D-152).

## Parametreler

### `upgrade`

- `--force` (zorunlu): paket upgrade + legacy Plume supervisord migrasyonu
- `--yes` (zorunlu): kritik islem onayi
- `--dry-run`: plan yaz, uygulama yok

### `program add`

- `--template=generic|horizon`
- `--name=plume-worker` — program adi (`[program:name]`)
- `--non-interactive`: template default'lari kullan (smoke/CI)

Interaktif modda her template placeholder icin soru sorulur; onizleme sonrasi onay istenir.

Program conf hedefi OS'e gore:

- macOS Homebrew: `$(brew --prefix)/etc/supervisor.d/plume-*.ini` (Homebrew include `*.ini`; D-153)
- Debian/Ubuntu: `/etc/supervisor/conf.d/` (sudo gerekebilir)
- RHEL/Fedora: `/etc/supervisord.d/` veya `/etc/supervisor/conf.d/`

Plume drop-in dizini/uzantisini `supervisord.conf` `[include] files=` satirindan okur; yanlis `opt/supervisor/etc` cache'i yok sayilir.
Registry: `$(plume_state_dir)/native/supervisor/programs-registry.env`

## Cikti / exit-code

- `0`: basarili
- `2`: `--force`/`--yes` eksik, yazma hatasi, supervisor down

## Ornekler

```bash
# Legacy D-147 -> system-primary migrasyon
./plume.sh services supervisor upgrade --force --yes

# Horizon worker (tunnelion)
PLUME_HORIZON_PATH=/path/to/laravel
./plume.sh services supervisor program add --template=horizon --non-interactive

# Generic queue worker
./plume.sh services supervisor program add --template=generic
```

## Hata senaryolari

- `upgrade requires --force` — bilincli migrasyon icin `--force --yes`
- `cannot write supervisor program conf` — Linux'ta sudo veya yazilabilir conf.d
- Horizon icin artisan yok — `PLUME_HORIZON_PATH` veya site kaydi

Iliskili: [doctor-supervisor.md](./doctor-supervisor.md), [services-horizon.md](./services-horizon.md).
