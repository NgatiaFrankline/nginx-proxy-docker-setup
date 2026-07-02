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
echo "Starting cert-watcher (upgrades HTTP-only configs to HTTPS once Certbot issues certs)..."
(
  while true; do
    sleep 30
    NEEDS_RELOAD=false
    if [ -n "${PROXY_DOMAINS:-}" ]; then
      IFS=',' read -ra _DOMAINS <<< "${PROXY_DOMAINS}"
      for _entry in "${_DOMAINS[@]}"; do
        _entry="${_entry//[[:space:]]/}"
        [ -z "${_entry}" ] && continue
        IFS=':' read -r _domain _ _ <<< "${_entry}"
        _conf="${NGINX_CONFD_DIR}${_domain//./_}.conf"
        _cert="/etc/letsencrypt/live/${_domain}/fullchain.pem"
        # If the cert now exists but the config still only has port 80 (no 443), upgrade it
        if [ -f "${_cert}" ] && [ -f "${_conf}" ] && ! grep -q "listen 443" "${_conf}"; then
          echo "cert-watcher: cert found for ${_domain}, upgrading config to HTTPS"
          NEEDS_RELOAD=true
        fi
      done
    fi
    if [ "${NEEDS_RELOAD}" = "true" ]; then
      source /scripts/create_proxy_domains.sh
      nginx -s reload
      echo "cert-watcher: nginx reloaded with HTTPS configs"
    fi
  done
) &
echo "Done!"


echo
echo "Executing container default entrypoint"
exec "${DEFAULT_ENTRYPOINT}" "$@"
