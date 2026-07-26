#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TEMPLATE="templates/docker-lite/docker-compose.template.yml"
NGINX_CONF="templates/docker-lite/conf/nginx.conf"
APACHE_CONF="templates/docker-lite/conf/apache2.conf"
CADDYFILE="templates/docker-lite/conf/Caddyfile"
CTX_MARIADB="templates/docker-lite/mariadb/README.md"
CTX_MYSQL="templates/docker-lite/mysql/README.md"
CTX_PMA="templates/docker-lite/phpmyadmin/README.md"
DF_WORKSPACE="templates/docker-lite/workspace/Dockerfile"
DF_PHP_FPM="templates/docker-lite/php-fpm/Dockerfile"
DF_NGINX="templates/docker-lite/nginx/Dockerfile"
DF_APACHE="templates/docker-lite/apache2/Dockerfile"
DF_CADDY="templates/docker-lite/caddy/Dockerfile"
DF_POSTGRES="templates/docker-lite/postgres/Dockerfile"
DF_REDIS="templates/docker-lite/redis/Dockerfile"
DF_HORIZON="templates/docker-lite/laravel-horizon/Dockerfile"
WORKSPACE_ALIASES="templates/docker-lite/workspace/aliases.sh"

for f in "${TEMPLATE}" "${NGINX_CONF}" "${APACHE_CONF}" "${CADDYFILE}" \
  "${CTX_MARIADB}" "${CTX_MYSQL}" "${CTX_PMA}" \
  "${DF_WORKSPACE}" "${DF_PHP_FPM}" "${DF_NGINX}" "${DF_APACHE}" "${DF_CADDY}" "${DF_POSTGRES}" "${DF_REDIS}" "${DF_HORIZON}" "${WORKSPACE_ALIASES}"; do
  if [[ ! -f "${f}" ]]; then
    echo "[FAIL] missing template file: ${f}" >&2
    exit 1
  fi
done

grep -q "php-fpm" "${TEMPLATE}" || { echo "[FAIL] php-fpm missing in template" >&2; exit 1; }
grep -q "services:" "${TEMPLATE}" || { echo "[FAIL] services section missing in template" >&2; exit 1; }
grep -q "profiles:" "${TEMPLATE}" || { echo "[FAIL] profiles missing in template" >&2; exit 1; }
grep -q "phpmyadmin" "${TEMPLATE}" || { echo "[FAIL] phpmyadmin missing in template" >&2; exit 1; }
grep -q "PMA_DB_ENGINE" "${TEMPLATE}" || { echo "[FAIL] PMA_DB_ENGINE missing in template" >&2; exit 1; }
grep -q "WORKSPACE_INSTALL_NODE" "${TEMPLATE}" || { echo "[FAIL] workspace node arg missing in template" >&2; exit 1; }
grep -q "WORKSPACE_INSTALL_ZSH" "${TEMPLATE}" || { echo "[FAIL] workspace zsh arg missing in template" >&2; exit 1; }
grep -q "WORKSPACE_INSTALL_OH_MY_ZSH" "${TEMPLATE}" || { echo "[FAIL] workspace oh-my-zsh arg missing in template" >&2; exit 1; }
grep -q "PLUME_PHP_DEFAULT_VERSION" "${TEMPLATE}" || { echo "[FAIL] workspace php default arg missing in template" >&2; exit 1; }
grep -q "PLUME_PHP_INSTALLED_VERSIONS" "${TEMPLATE}" || { echo "[FAIL] workspace php installed versions arg missing in template" >&2; exit 1; }
grep -q "WORKSPACE_INSTALL_OH_MY_ZSH" "${DF_WORKSPACE}" || { echo "[FAIL] workspace oh-my-zsh arg missing in Dockerfile" >&2; exit 1; }
grep -q "phpuse" "${DF_WORKSPACE}" || { echo "[FAIL] workspace phpuse helper missing in Dockerfile" >&2; exit 1; }
grep -q "alias usephp='phpuse'" "${WORKSPACE_ALIASES}" || { echo "[FAIL] workspace phpuse alias missing" >&2; exit 1; }
grep -q "context: ./php-fpm" "${TEMPLATE}" || { echo "[FAIL] shared php-fpm context missing in template" >&2; exit 1; }
grep -q "PHP_VERSION: " "${TEMPLATE}" || { echo "[FAIL] php build arg missing in template" >&2; exit 1; }
grep -q "php_fastcgi php-fpm:9000" "${CADDYFILE}" || { echo "[FAIL] caddy php upstream missing" >&2; exit 1; }
grep -q "fastcgi_pass php-fpm:9000" "${NGINX_CONF}" || { echo "[FAIL] nginx php upstream missing" >&2; exit 1; }

echo "phase7-docker-lite-template-smoke:ok"
