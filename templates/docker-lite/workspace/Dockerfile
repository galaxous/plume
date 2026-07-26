ARG COMPOSER_VERSION=2
FROM composer:${COMPOSER_VERSION}

ARG WORKSPACE_USER=plume
ARG WORKSPACE_PUID=1000
ARG WORKSPACE_PGID=1000
ARG WORKSPACE_TIMEZONE=UTC
ARG PLUME_PHP_DEFAULT_VERSION=8.3
ARG PLUME_PHP_INSTALLED_VERSIONS=8.1,8.2,8.3
ARG WORKSPACE_INSTALL_ZSH=false
ARG WORKSPACE_INSTALL_OH_MY_ZSH=false
ARG WORKSPACE_INSTALL_NODE=false
ARG WORKSPACE_NODE_VERSION=20
ARG WORKSPACE_NPM_REGISTRY=
ARG WORKSPACE_NVM_NODEJS_ORG_MIRROR=

ENV TZ=${WORKSPACE_TIMEZONE}
USER root

RUN set -eux; \
  apk add --no-cache bash curl git tzdata shadow sudo; \
  if ! getent group "${WORKSPACE_USER}" >/dev/null 2>&1; then \
    addgroup -S -g "${WORKSPACE_PGID}" "${WORKSPACE_USER}"; \
  fi; \
  if ! id -u "${WORKSPACE_USER}" >/dev/null 2>&1; then \
    adduser -S -u "${WORKSPACE_PUID}" -G "${WORKSPACE_USER}" -s /bin/bash "${WORKSPACE_USER}"; \
  fi; \
  mkdir -p /etc/sudoers.d; \
  printf '%s ALL=(ALL) NOPASSWD:ALL\n' "${WORKSPACE_USER}" > "/etc/sudoers.d/${WORKSPACE_USER}"; \
  chmod 0440 "/etc/sudoers.d/${WORKSPACE_USER}"; \
  cp "/usr/share/zoneinfo/${WORKSPACE_TIMEZONE}" /etc/localtime; \
  echo "${WORKSPACE_TIMEZONE}" > /etc/timezone; \
  if [ "${WORKSPACE_INSTALL_ZSH}" = "true" ]; then apk add --no-cache zsh; fi; \
  if [ "${WORKSPACE_INSTALL_NODE}" = "true" ]; then apk add --no-cache nodejs npm; fi

# Install requested PHP versions and expose helpers like php81/php82 + phpuse.
RUN set -eux; \
  normalize() { printf '%s' "$1" | tr -d '.'; }; \
  default_v="$(normalize "${PLUME_PHP_DEFAULT_VERSION}")"; \
  versions="$(printf '%s' "${PLUME_PHP_INSTALLED_VERSIONS}" | tr ',' ' ')"; \
  found_default="false"; \
  for raw in ${versions}; do \
    v="$(normalize "${raw}")"; \
    [ -n "${v}" ] || continue; \
    [ "${v}" = "${default_v}" ] && found_default="true" || true; \
    if apk add --no-cache "php${v}" >/dev/null 2>&1; then \
      ln -sf "/usr/bin/php${v}" "/usr/local/bin/php${v}"; \
    else \
      echo "[WARN] could not install php${v} from apk repositories"; \
    fi; \
  done; \
  if [ "${found_default}" != "true" ]; then \
    if apk add --no-cache "php${default_v}" >/dev/null 2>&1; then \
      ln -sf "/usr/bin/php${default_v}" "/usr/local/bin/php${default_v}"; \
    else \
      echo "[WARN] default php${default_v} was not installable"; \
    fi; \
  fi; \
  if [ -x "/usr/bin/php${default_v}" ]; then \
    ln -sf "/usr/bin/php${default_v}" /usr/local/bin/php; \
  fi; \
  cat > /usr/local/bin/phpuse <<'SH' && chmod +x /usr/local/bin/phpuse
#!/usr/bin/env sh
set -eu
if [ "${1:-}" = "" ]; then
  echo "usage: phpuse <8.1|8.2|8.3|81|82|83>" >&2
  exit 2
fi
v="$(printf '%s' "$1" | tr -d '.')"
if [ ! -x "/usr/bin/php${v}" ]; then
  echo "php${v} is not installed in workspace" >&2
  exit 2
fi
ln -sf "/usr/bin/php${v}" /usr/local/bin/php
echo "active php switched to php${v}"
SH

RUN if [ "${WORKSPACE_INSTALL_OH_MY_ZSH}" = "true" ]; then \
      if [ "${WORKSPACE_INSTALL_ZSH}" != "true" ]; then \
        echo "WORKSPACE_INSTALL_OH_MY_ZSH requires WORKSPACE_INSTALL_ZSH=true" >&2; \
        exit 1; \
      fi; \
      su "${WORKSPACE_USER}" -s /bin/sh -c 'RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'; \
      grep -q "plume-aliases.sh" "/home/${WORKSPACE_USER}/.zshrc" || \
        printf '\n[ -f /etc/profile.d/plume-aliases.sh ] && . /etc/profile.d/plume-aliases.sh\n' >> "/home/${WORKSPACE_USER}/.zshrc"; \
      chown -R "${WORKSPACE_USER}:${WORKSPACE_USER}" "/home/${WORKSPACE_USER}/.oh-my-zsh" "/home/${WORKSPACE_USER}/.zshrc"; \
    fi

COPY aliases.sh /etc/profile.d/plume-aliases.sh
RUN chmod 0644 /etc/profile.d/plume-aliases.sh && \
  mkdir -p "/home/${WORKSPACE_USER}" && \
  touch "/home/${WORKSPACE_USER}/.bashrc" && \
  grep -q "plume-aliases.sh" "/home/${WORKSPACE_USER}/.bashrc" || \
  printf '\n[ -f /etc/profile.d/plume-aliases.sh ] && . /etc/profile.d/plume-aliases.sh\n' >> "/home/${WORKSPACE_USER}/.bashrc" && \
  chown -R "${WORKSPACE_USER}:${WORKSPACE_USER}" "/home/${WORKSPACE_USER}"

RUN if [ -n "${WORKSPACE_NPM_REGISTRY}" ]; then \
      printf 'registry=%s\n' "${WORKSPACE_NPM_REGISTRY}" > "/home/${WORKSPACE_USER}/.npmrc"; \
      chown "${WORKSPACE_USER}:${WORKSPACE_USER}" "/home/${WORKSPACE_USER}/.npmrc"; \
    fi

USER ${WORKSPACE_USER}
WORKDIR /var/www/html
CMD ["sh", "-lc", "tail -f /dev/null"]
