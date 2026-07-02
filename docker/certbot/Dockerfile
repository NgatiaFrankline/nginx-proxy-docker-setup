ARG VERSION=v5.6.0
FROM certbot/certbot:${VERSION} AS certbot

LABEL maintainer="Ngatia Frankline <fngatia@gmail.com>"

RUN set -ex \
    && apk add --no-cache bash \
    && apk add --no-cache dcron \
    && rm -rf /var/cache/apk/*

COPY scripts /scripts

RUN set -ex \
    && chown -R nobody:nogroup /scripts \
    && chmod +x /scripts/*.sh

ENTRYPOINT ["/scripts/entrypoint.sh"]
