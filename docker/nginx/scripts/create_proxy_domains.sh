#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
DOMAIN_TEMPLATE="/conf/domain-template.conf"
HTTP_ONLY_TEMPLATE="/conf/http-only-template.conf"
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


_validate_domain_entry() {
  local entry=$1
  local domain container_name container_port
  IFS=':' read -r domain container_name container_port <<< "${entry}"

  if [ -z "${domain}" ] || [ -z "${container_name}" ] || [ -z "${container_port}" ]; then
    echo "Invalid PROXY_DOMAINS entry: ${entry}"
    return 1
  fi

  if [[ ! "${domain}" =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    echo "Invalid hostname in PROXY_DOMAINS entry: ${domain}"
    return 1
  fi

  if [[ ! "${container_port}" =~ ^[0-9]+$ ]] || (( container_port < 1 || container_port > 65535 )); then
    echo "Invalid target port in PROXY_DOMAINS entry: ${container_port}"
    return 1
  fi

  return 0
}

_create_domain() {
  entry=$1
  _validate_domain_entry "${entry}" || return 1

  local domain container_name container_port
  IFS=':' read -r domain container_name container_port <<< "${entry}"

  local conf_filename="${domain//./_}.conf"
  local dest="${NGINX_CONFD_DIR}${conf_filename}"

  # Use HTTP-only config if the SSL certificate doesn't exist yet.
  # Certbot needs nginx on port 80 to complete the ACME challenge; once the
  # cert is created the cert-watcher will regenerate the config and reload nginx.
  local cert_file="/etc/letsencrypt/live/${domain}/fullchain.pem"
  local template="${DOMAIN_TEMPLATE}"
  if [ ! -f "${cert_file}" ]; then
    echo "No cert found for ${domain}, using HTTP-only template"
    template="${HTTP_ONLY_TEMPLATE}"
  fi

  echo "Creating config for domain: ${domain} -> ${container_name}:${container_port}"
  sed -e "s|{MY_DOMAIN}|${domain}|g" \
      -e "s|{CONTAINER_URL}|${container_name}:${container_port}|g" \
      "${template}" > "${dest}"
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

