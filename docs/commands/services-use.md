# `services use`

## Amac

Native modda tek veritabani engine secmek (Laradock’ta bir compose servisini acip digerini kapatmak gibi). XOR: `mariadb` | `mysql` | `postgres`. Eslesen UI: phpMyAdmin (mysql-family) veya pgAdmin (postgres).

## Kullanim

```bash
./plume.sh services use mariadb --mode=native
./plume.sh services use mysql --mode=native
./plume.sh services use postgres --mode=native
```

Sonra:

```bash
./plume.sh services up @db --mode=native
# veya
./plume.sh services up @core --mode=native
```

## Parametreler

- `<engine>`: `mariadb` | `mysql` | `postgres`
- `--mode=native` (zorunlu)

Davranis:

- Secilen engine `ENABLED=true`; diger iki engine `false`
- `mariadb`/`mysql`: `services.yml` `database.engine` guncellenir (varsa)
- `mariadb`/`mysql`: `PHPMYADMIN_ENABLED=true`, `PGADMIN_ENABLED=false`
- `postgres`: `PGADMIN_ENABLED=true`, `PHPMYADMIN_ENABLED=false`
- Degerler global `~/.config/plume/.env` icine yazilir (kisa + `PLUME_*` adlar)

## Cikti / exit-code

- `engine=<name>` ve `enabled_*=true|false` satirlari
- `0`: basarili
- `2`: native olmayan mode veya gecersiz engine

## Ornekler

```bash
./plume.sh services use mariadb --mode=native
./plume.sh services up mariadb phpmyadmin --mode=native
./plume.sh services credentials mariadb --mode=native
```

## Hata senaryolari

- `services use mysql` native brew’de mariadb formula ile cakisir; once `services down mariadb`
- phpMyAdmin `postgres` ile calismaz (D-127); `use postgres` phpmyadmin’i kapatir
