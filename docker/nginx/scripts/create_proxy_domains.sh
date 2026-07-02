#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
DOMAIN_TEMPLATE="/conf/domain-template.conf"
DEFAULT_TEMPLATE="/conf/default-template.conf"
NGINX_CONFD_DIR="/etc/nginx/conf.d/"
DEFAULT_CONF_DEST="${NGINX_CONFD_DIR}default.conf"


echo
echo "Creating proxy domains script"
echo
echo "Checking domains template file: ${DOMAIN_TEMPLATE}"
if [ ! -f "${DOMAIN_TEMPLATE}" ]; then
  echo "OOPS! Template: ${DOMAIN_TEMPLATE} not found"
  echo "Exiting with error 1"
  exit 1
fi
echo "Template found!"
sleep 1


_create_domain() {
  entry=$1

  local domain container_name container_port
  IFS=':' read -r domain container_name container_port <<< "${entry}"

  local conf_filename="${domain//./_}.conf"
  local dest="${NGINX_CONFD_DIR}${conf_filename}"

  echo "Creating config for domain: ${domain} -> ${container_name}:${container_port}"
  sed -e "s|{MY_DOMAIN}|${domain}|g" \
      -e "s|{CONTAINER_URL}|${container_name}:${container_port}|g" \
      "${DOMAIN_TEMPLATE}" > "${dest}"
  echo "Created: ${dest}"

  if [ "${DEBUG_NGINX_TEMPLATE}" = "true" ]; then
    echo
    echo "================== cat ${dest} =============================================="
    cat ${dest}
    echo "================== end         =============================================="
    echo
  fi
  echo "Done!"
  sleep 1
}


echo
if [ -n "${PROXY_DOMAINS}" ]; then
  IFS=',' read -ra DOMAINS <<< "${PROXY_DOMAINS}"
  for entry in "${DOMAINS[@]}"; do
    entry="${entry//[[:space:]]/}"
    [ -z "${entry}" ] && continue
    _create_domain "${entry}"
  done
  echo "Done creating proxy domain configs."
else
  echo "Ooops!"
  echo "No domains to create"
  echo "Configuring a default server to show Nginx is working when no domains are specified."
  cp -rvf "${DEFAULT_TEMPLATE}" "${DEFAULT_CONF_DEST}"
  echo "Created: ${DEFAULT_CONF_DEST}"
fi


echo
echo "Adios muchachos...."
IFS=$'\n\t'

