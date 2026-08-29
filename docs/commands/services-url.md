# `services url` / `services credentials`

## Amac

Native modda web UI ve veritabani servisleri icin HTTP URL ve baglanti bilgisi (adapter-friendly key=value).

## Kullanim

```bash
plumectl services url phpmyadmin --mode=native
plumectl services url pgadmin --mode=native
plumectl services url mongo_webui --mode=native
plumectl services url redis_webui --mode=native
plumectl services credentials postgres --mode=native
plumectl services credentials mariadb --mode=native
plumectl services credentials mailpit --mode=native
plumectl services credentials memcached --mode=native
```

## Parametreler

- `--mode=native` (zorunlu; Phase 17 MVP native-only)
- `<service>`: url icin `phpmyadmin`, `pgadmin`, `mongo_webui`, `redis_webui`, `rabbitmq`, `mailpit`; credentials icin `postgres`, `mariadb`, `mysql`, `mongodb`, `redis`, `rabbitmq`, `memcached`, `mongo_webui`, `redis_webui`, `phpmyadmin`, `pgadmin`, `mailpit`

## Cikti / exit-code

- `services url`: `url=http://127.0.0.1:<port>`
- `services credentials`: `host=`, `port=`, `user=`, `password=`, `database=` satirlari (servise gore)
- `0`: basarili
- `2`: desteklenmeyen servis/mode veya veri yok

## Ornekler

```bash
./plume.sh services url redis_webui --mode=native
# url=http://127.0.0.1:8083

./plume.sh services credentials postgres --mode=native
```

## Hata senaryolari

- docker-lite/laradock-bridge modunda native-only komut
- Servis hic kurulmadi (`services install` oncesi credentials bos)

OS matrisi: [native-stack-os-matrix.md](../operations/native-stack-os-matrix.md).
