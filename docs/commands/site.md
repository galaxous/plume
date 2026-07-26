# `site` Komutu

## Amac

`plumectl site` ailesi, bir Laravel projesini hızlıca sisteme ekler ve web server için merkezi bir registry içine kaydeder.

## Komutlar

```bash
plumectl site add --path=/abs/path --domain=myapp.test[,www.myapp.test] --server=nginx|apache2|caddy
plumectl site add --path=/abs/path --domain=myapp.test --server=nginx --php=8.2 --publish
plumectl site add --path=/abs/path --domain=myapp.test --server=nginx --cert-id=cert-myapp --https-port=443 --publish
plumectl site update <site-id> --clear-cert --publish --reload
plumectl site update <site-id> --domain=myapp.test --server-config=/path/custom.conf --publish --reload
plumectl site publish <site-id> --reload
plumectl site publish <site-id> --dry-run
plumectl site list
plumectl site modes
plumectl site check <site-id>
plumectl site remove <site-id>
```

`site` komutu yalnızca site seviyesinde çalışır. Site ayrıntısı için `plumectl site check <id>` kullanılır. Etkileşimli eklenti için `plumectl site add` çalıştırıldığında TTY'da `--path` ve `--domain` için prompt gösterilir.

## Add Opisyonlari

- `--path=<project_abs_path>`
- `--domain=<domain1,domain2>`
- `--server=nginx|apache2|caddy` (varsayılan: `nginx`)
- `--php=<8.1|8.2|8.3|8.4|default>` (varsayılan: `PLUME_PHP_DEFAULT_VERSION`)
- `--php-upstream=<host:port|unix:/sock>` (opsiyonel; site bazlı upstream override)
- `--mode=native|docker-lite|laradock-bridge` (varsayılan: aktif mod)
  - `site update` komutunda verilirse kayıt mode'unu override eder
- `--port=<port>` (varsayılan: `80`)
- `--https-port=<port>` (varsayılan: `443`; cert bağlıysa kullanılır)
- `--cert-id=<cert-id>` (`security cert issue` ile üretilmiş cert kimliği)
- `--clear-cert` (yalnızca `site update`: site kaydından `cert_id`/`https_port` kaldırır; snippet HTTP-only olur, HTTP→HTTPS redirect yazılmaz; sertifika dosyaları state'te kalır)
- `--tls=false` (`--clear-cert` ile aynı; yalnızca `site update`)
- `--document-root=<dir>` (varsayılan: `public`)
- `--publish` (web server snippet yazılır)
- `--server-config=<abs_path>` (opsiyonel; path'in mevcut ve okunabilir olması gerekir)
- `--reload` (`site publish` ile birlikte: `nginx|apache2|caddy` serverini yeniden yükler)
- `--dry-run` (değişiklik uygulamaz; planı yazdırır)
- `--force` (domain/path çakışmalarını geçersiz kılar)

Not:

- `--mode` verilmezse, önce proje klasöründeki `plume.yml` içinde `project.mode` veya `mode` aranır.
- Bulunamazsa aktif mod (`plume mode current`) kullanılır.
- Site kaydında `mode` varsa `site update/publish/remove` bu mod öncelikli olarak kullanılacaktır.
- `PLUME_SITE_RELOAD_REQUIRED=true` ise `--reload` başarısız olursa komut `exit 2` döner.
- `PLUME_SITE_AUTO_PROVISION_WEB=true` (varsayılan): native modda `--reload` sırasında nginx/apache2 yüklü değilse `brew`/`apt` ile otomatik kurulum ve servis başlatma denenir (`PLUME_NATIVE_HOST_PROVISION` gerekmez; publish akışı geçici olarak host provision açar).
- `PLUME_SITE_AUTO_PROVISION_WEB=false` ise web sunucusunu elle kurmanız gerekir: `PLUME_NATIVE_HOST_PROVISION=true plumectl services install web && services up web`.
- `PLUME_SITE_NGINX_STRICT_ON_RELOAD=true` (varsayılan): native `site publish --reload` snippet'i Homebrew `/opt/homebrew/etc/nginx/servers/` (veya `PLUME_NGINX_INCLUDE_DIR`) altına yazar; aksi halde config yalnızca `~/.config/plume/sites/nginx/` cache'inde kalır ve nginx görmez.
- macOS Homebrew nginx çoğu kurulumda **8080** dinler (formül bilinçli olarak 80→8080 yapar; root gerektirmez). Site kaydı `port: 80` olsa bile render sırasında ana config’teki listen okunur; 8080 ise snippet de 8080 olur (`PLUME_NATIVE_HOMEBREW_HTTP_PORT=8080` ile zorlanabilir).
- Port **80** (portsuz `http://myapp.test`) için: `PLUME_NATIVE_NGINX_MANAGE_MAIN_CONFIG=true` + `services web sync-config --reload` (macOS’ta genelde `sudo brew services restart nginx`), ardından `site publish --reload`. Ayrıntı: [services-web.md](services-web.md).
- `PLUME_SITE_RELOAD_VALIDATE=true` (default) ise native modda reload öncesi config test zorunludur:
  - nginx: `nginx -t`
  - apache2: `apachectl -t` veya `httpd -t`
  - caddy: `caddy validate`
  - macOS'ta `nginx` PATH'te yoksa Homebrew prefix altındaki `bin/nginx` veya `sbin/nginx` otomatik denenir
- `PLUME_SITE_NGINX_STRICT=true` ise native `server=nginx` publish sırasında:
  - snippet, gerçek include dizinine de yazılır (`PLUME_NGINX_INCLUDE_DIR` veya auto-detect),
  - `nginx -t` lint zorunlu çalışır,
  - reload zorunlu çalışır,
  - lint/reload fail olursa hedef include rollback edilir ve publish fail olur.
- `PLUME_SITE_APACHE2_STRICT=true` ise native `server=apache2` publish sırasında:
  - snippet, gerçek include dizinine de yazılır (`PLUME_APACHE2_INCLUDE_DIR` veya auto-detect),
  - `apachectl -t`/`httpd -t` lint zorunlu çalışır,
  - reload zorunlu çalışır,
  - lint/reload fail olursa hedef include rollback edilir ve publish fail olur.
- `PLUME_SITE_CADDY_STRICT=true` ise native `server=caddy` publish sırasında:
  - snippet, gerçek include dizinine de yazılır (`PLUME_CADDY_INCLUDE_DIR` veya auto-detect),
  - `caddy validate` lint zorunlu çalışır,
  - reload zorunlu çalışır,
  - lint/reload fail olursa hedef include rollback edilir ve publish fail olur.
- `PLUME_SITE_PORT_CONFLICT_CHECK=true` ise aynı HTTP portunu kullanan ikinci site add/update engellenir (default: `false`).
- `PLUME_DOCKER_LITE_COMPOSE_REQUIRED=true` ise docker-lite publish/reload için compose dosyası zorunlu olur.
- `PLUME_LARADOCK_STRICT=true` ise laradock path/compose/container preflight başarısızsa publish/reload durdurulur.
- `site update` ile mode degisirse eski mode’a ait cache/snippet artefact’lari temizlenir.
- Site kaydındaki `php_version` alanı snippet üretiminde upstream PHP-FPM servisini belirler:
  - default PHP: `php-fpm`
  - diğer sürümler: `php81-fpm`, `php82-fpm`, `php83-fpm`, `php84-fpm`
  - `php_upstream` site alanı doluysa resolver yerine doğrudan bu değer kullanılır.
  - native mode'da per-version upstream override da verilebilir:
    - `PLUME_NATIVE_PHP_FPM_UPSTREAM` (default php)
    - `PLUME_NATIVE_PHP_FPM_UPSTREAM_81`, `..._82`, `..._84`
  - override verilmezse plume native socket discovery dener (`unix:/run/php/php8.2-fpm.sock`, `unix:/opt/homebrew/var/run/php@8.2-fpm.sock` vb.)
  - socket yoksa ve Homebrew `php@X.Y` kuruluysa, default dışı sürümler paylaşılan `127.0.0.1:9000` havuzuna düşmez; canonical unix yolu (`php@8.2-fpm.sock`) kullanılır. Default PHP sürümü için Homebrew pool `listen = 127.0.0.1:9000` ise bu TCP upstream kullanılır.
  - **Homebrew FPM socket:** nginx snippet canonical `unix:/opt/homebrew/var/run/php@8.2-fpm.sock` kullanır; FPM pool'unun aynı yolu dinlemesi gerekir. `./plume.sh services up php82` (native) `www.conf` `listen` satirini buna hizalar (D-107). Manuel kontrol: `grep listen /opt/homebrew/etc/php/8.2/php-fpm.d/www.conf` ve `ls -l /opt/homebrew/var/run/php@8.2-fpm.sock`.
  - `site update --php=... --publish` snippet’i (header + `fastcgi_pass`) yeniden üretir; yalnızca yml kaydı güncellenip publish edilmezse cache/nginx hedefi eski kalır.
- `cert_id` verildiğinde snippet üretimi HTTPS bloklarını ekler:
  - nginx: `listen <https-port> ssl` + `ssl_certificate`
  - apache2: SSL VirtualHost + redirect
  - caddy: `tls <crt> <key>`
- `cert_id` yoksa (veya `--clear-cert` sonrası) yalnızca HTTP listener üretilir; nginx/apache2 HTTP→HTTPS redirect bloğu yazılmaz.

## Çıkış / Durum Kodları

- `0`: işlem başarılı
- `2`: doğrulama ve input hatası

## Kayıt Konumu

- Site kayıtları: `~/.config/plume/sites/<site-id>.yml`
- Site dizini index'i: `~/.config/plume/sites/index.yml`
- Yayınlanmış snippet:
  - native: `~/.config/plume/sites/<server>/<site-id>.conf` (veya `PLUME_SITE_REGISTRY_DIR` override edilirse `<PLUME_SITE_REGISTRY_DIR>/<server>/<site-id>.conf`)
  - docker-lite: `~/.config/plume/docker-lite/sites/<server>/<site-id>.conf`
  - laradock-bridge: `~/.config/plume/laradock-bridge/sites/<server>/<site-id>.conf`
- Hosts sync hedef dosyası: `PLUME_HOSTS_FILE` (default `/etc/hosts`)
- Konfigürasyon başarısız olsa bile (izin yoksa), `PLUME_SITE_HOSTS_REQUIRED=true` ile publish durdurulabilir.

`--server-config` ile verilen dosya doğrudan snippet dosyasına kopyalanır.
`plumectl site publish <site-id> --reload` komutu ile güncel snippet tekrar yazdırılıp
aktif web server (`nginx|apache2|caddy`) reload edilmeye çalışılır.
`PLUME_SITE_NGINX_STRICT=true`, `PLUME_SITE_APACHE2_STRICT=true` veya `PLUME_SITE_CADDY_STRICT=true` iken native publish, `--reload` verilmemiş olsa bile strict pipeline gereği lint+reload uygular.
Bu durumda `site publish --reload` ikinci bir reload tetiklemez; strict pipeline'daki reload tekrar kullanılir.

`site check` çıktısında strict görünürlük alanları:

- `mode`
- `strict_enabled`
- `strict_include_dir`
- `strict_include_target`

Tarayıcı erişimi (native, özellikle macOS Homebrew nginx):

- `port`: registry’deki mantıksal HTTP portu (genelde `80`)
- `effective_http_port`: snippet’te gerçekten dinlenen port (Homebrew nginx çoğu kurulumda `8080`)
- `url_http`: açılabilir HTTP URL (ör. `http://myapp.test:8080`)
- `url_https`: `cert_id` varsa HTTPS URL (ör. `https://myapp.test`)
- `access_hint`: registry `80` iken nginx yalnızca `8080` dinliyorsa; `http://myapp.test` (port 80) bağlantı reddeder — `url_http` veya `url_https` kullanın

### macOS: proje `Desktop` / `Documents` / `Downloads` altında (TCC)

Homebrew **nginx** ve **php-fpm** genelde sizin kullanıcı oturumunuzdan farklı bir sistem kullanıcısıyla çalışır. macOS **Transparency, Consent, and Control (TCC)**, `~/Desktop`, `~/Documents` ve `~/Downloads` altındaki dosyalara erişimi kısıtlayabilir.

Belirti:

- Tarayıcı veya `curl`: `No input file specified.` (HTTP 404)
- Nginx error log: `Unable to open primary script: .../public/index.php (Operation not permitted)` veya stat/open `Operation not permitted`

Çözüm (birini uygulayın):

1. **Projeyi taşıyın** — örn. `~/Sites/...` veya `~/Code/...` (Desktop/Documents/Downloads dışı), ardından `plumectl site update <id> --path=... --publish --reload`
2. **Full Disk Access** — `./plume.sh init permissions --interactive` veya `--open --reveal`; System Settings → Privacy & Security → Full Disk Access: Homebrew **nginx** ve **php-fpm** binary’lerini ekleyin; servisleri yeniden başlatın
3. **Teşhis** — `plumectl doctor web --mode=native` satırı `macos-site-tcc`; `plumectl doctor php` satırı `MACOS_TCC` (çıktı `init permissions --interactive` önerir)

`site check --json` `warnings` içinde Desktop/Documents yolu için TCC ipucu eklenir (registry path TCC-duyarlıysa).

`site check --json` `data` içinde aynı alanları döner; `access_hint` doluysa `warnings` dizisine de eklenir.

`site list` text tablosu sabit kolon sırasını korur:

- `ID`
- `SERVER`
- `PHP`
- `PORT`
- `HTTPS`
- `CERT`
- `STATUS`
- `DOMAINS`
- `PATH`

Not:

- `PATH` her zaman en sonda yer alır.
- Header ve satır genişlikleri aynı renderer'dan üretildiği için hizalama sabit kalır.

`site modes` text tablosu ise mode bazlı registry görünümü sağlar:

- `ID`
- `MODE`
- `SERVER`
- `PHP`
- `STATUS`
- `PATH`

Bu komut, bir sitenin hangi mode üzerinde tutulduğunu topluca denetlemek için kullanılır.

## Yerel geliştirmede HTTPS kapatma (site bazlı)

Site kaydında `cert_id` varken nginx snippet’i HTTP isteklerini HTTPS’e yönlendirir (`return 301`). Yerelde yalnızca HTTP kullanmak için cert bağını kaldırıp snippet’i yeniden yazın (sertifika dosyaları silinmez):

```bash
plumectl site update site-1775207595-23239 --clear-cert --publish --reload
plumectl site check site-1775207595-23239
```

Sonrasında tarayıcıda `site check` çıktısındaki `url_http` değerini kullanın (Homebrew nginx’te çoğu kurulumda `http://myapp.test:8080`). HTTPS’i tekrar açmak için önce `plumectl security cert issue --domains=myapp.test` (veya mevcut cert id), ardından `plumectl site update <id> --cert-id=<cert-id> --publish --reload`.

## Örnekler

```bash
plumectl site add --path=/Users/oguzhan/Code/myshop --domain=myshop.test --server=nginx --publish --server-config=/tmp/myshop.nginx.conf
plumectl site add --path=/Users/oguzhan/Code/myshop --domain=myshop.test --server=nginx --php=8.2 --php-upstream=unix:/tmp/php82-fpm.sock --publish
plumectl site add --path=/Users/oguzhan/Code/myapi --domain=myapi.test --server=caddy --publish
plumectl site add --path=/Users/oguzhan/Code/mytls --domain=mytls.test --server=nginx --cert-id=cert-mytls --https-port=4443 --publish
plumectl site list
plumectl site update site-1712345678-12345 --clear-cert --publish --reload
plumectl site check site-1712345678-12345
plumectl site remove site-1712345678-12345 --dry-run
plumectl site modes
```
