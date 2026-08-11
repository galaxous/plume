# Native pgAdmin (PostgreSQL UI)

## Amac

Laradock `pgadmin` parity: native modda PostgreSQL icin web UI. Plume state altinda Python venv + `pip install pgadmin4`, HTTP `127.0.0.1:5050`.

## Kullanim

```bash
# ~/.config/plume/.env
POSTGRES_ENABLED=true
PGADMIN_ENABLED=true
PGADMIN_PORT=5050
PGADMIN_DEFAULT_EMAIL=pgadmin4@pgadmin.org
PGADMIN_DEFAULT_PASSWORD=admin

./plume.sh services install postgres --mode=native
./plume.sh services install pgadmin --mode=native
./plume.sh services up postgres pgadmin --mode=native
# veya enabled filtreli:
./plume.sh services up @db --mode=native

open http://127.0.0.1:5050
# Login: PGADMIN_DEFAULT_EMAIL / PGADMIN_DEFAULT_PASSWORD
# Register server: Host=127.0.0.1 Port=5432 User/Password=POSTGRES_*
```

`pgadmin` icin `postgres` enabled olmalidir (dependency).

## Parametreler

| Degisken | Aciklama | Varsayilan |
|----------|----------|------------|
| `PGADMIN_ENABLED` / `PLUME_PGADMIN_ENABLED` | Servis toggle | `false` |
| `PGADMIN_PORT` / `PLUME_PGADMIN_PORT` | HTTP port | `5050` |
| `PGADMIN_DEFAULT_EMAIL` | UI login email | `pgadmin4@pgadmin.org` |
| `PGADMIN_DEFAULT_PASSWORD` | UI login sifre | `admin` |
| `PLUME_PGADMIN_VERSION` | Manifest version etiketi | `latest` |

State:

- `state/native/pgadmin/venv/` — Python venv + pgadmin4
- `state/native/pgadmin/data/` — pgAdmin DATA_DIR
- `state/native/pgadmin/venv/.../config_local.py` — port/DATA_DIR

## Cikti / exit-code

- `services url pgadmin`: `url=http://127.0.0.1:5050`
- `services credentials pgadmin`: `email=`, `password=`, `http_port=`, `db_host=`, `db_port=`, …
- `0`: basarili
- `2`: postgres disabled, python3 yok, veya kurulum/start hatasi

## Ornekler

```bash
./plume.sh services credentials pgadmin --mode=native
./plume.sh services restart pgadmin --mode=native
./plume.sh services down pgadmin --mode=native
```

## Hata senaryolari

- **pgadmin requires postgres to be enabled**: `.env` icinde `POSTGRES_ENABLED=true` yap.
- **python3 required**: host'ta Python 3 yok; kur veya docker-lite/laradock-bridge kullan.
- **5050 connection refused**: `services up pgadmin` calismamis veya PID olmus; log: `logs/services/native/pgadmin.log`.
- **Failed to create /var/lib/pgadmin**: eski install `config_local.py` yazamadi; `services install pgadmin` + `services restart pgadmin` (D-139).
- **running=false / health=stopped**: genelde yukaridaki config/path hatasi veya ilk pip kurulumu yarim kaldi.
OS matrisi: [native-stack-os-matrix.md](../operations/native-stack-os-matrix.md).
