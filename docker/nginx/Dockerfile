ARG VERSION=1.31.2
FROM nginx:${VERSION}-alpine AS nginx

LABEL maintainer="Ngatia Frankline <fngatia@gmail.com>"

COPY scripts /scripts
COPY conf /conf

RUN set -ex \
    && apk add --no-cache bash \
    && apk add --no-cache dcron \
    && rm -rf /var/cache/apk/*

RUN set -ex \
    && chmod +x /scripts/*.sh

ENTRYPOINT ["/scripts/entrypoint.sh"]
EXPOSE 80 443
