#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
DEFAULT_ENTRYPOINT="/docker-entrypoint.sh"
NGINX_CONFD_DIR="/etc/nginx/conf.d/"
HEALTHZ_CONF="/conf/healthcheck.conf"


echo
echo "Nginx proxy starting...."


echo
echo "Removing the previous domains configurations"
#ls -al "${NGINX_CONFD_DIR}"
rm -rvf "${NGINX_CONFD_DIR:-?}"*
echo "Done!"
sleep 1


echo
echo "Creating healthz check server..."
if [ -f "${HEALTHZ_CONF}" ]; then
  cp -rvf "${HEALTHZ_CONF}" "${NGINX_CONFD_DIR}"
else
  echo "OOPS! Healthcheck conf: ${HEALTHZ_CONF} not found"
  echo "Exiting with error 1"
  exit 1
fi


echo
source /scripts/create_proxy_domains.sh
echo "Listing dir: ${NGINX_CONFD_DIR}"
ls -al "${NGINX_CONFD_DIR}"
echo "Done!"


echo
echo "Add cron to reload nginx at 2am to pick up expired certificates"
echo "0 2 * * * nginx -s reload" | crontab -
crond -b
echo "Done!"
sleep 1


echo
echo "Executing container default entrypoint"
exec "${DEFAULT_ENTRYPOINT}" "$@"
