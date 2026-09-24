#!/bin/bash
set -euo pipefail
IFS=$'\n\t'


echo
echo "Creating certificates script"
echo "Checking env variables"
[ -z "${SKIP_CERTBOT}" ] && echo "SKIP_CERTBOT cannot be empty" && exit 1
[ -z "${CERTBOT_EMAIL}" ] && echo "CERTBOT_EMAIL cannot be empty" && exit 1
[ -z "${CERTBOT_STAGING}" ] && echo "CERTBOT_STAGING cannot be empty" && exit 1
echo "All env data set, proceeding..."
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

_create_cert() {
  local entry=$1
  _validate_domain_entry "${entry}" || return 1

  local domain container_name container_port
  IFS=':' read -r domain container_name container_port <<< "${entry}"

  if [ -f "/etc/letsencrypt/live/${domain}/fullchain.pem" ]; then
    echo "Ooops!"
    echo "Certificate for ${domain} already exists"
    echo "Skipping..."
  else
    echo "Requesting certificate for: ${domain}"
    STAGING_FLAG=""
    if [ "${CERTBOT_STAGING}" = "true" ]; then
      STAGING_FLAG="--staging"
    fi
    certbot certonly \
      --webroot \
      -w /var/www/certbot \
      --email "${CERTBOT_EMAIL}" \
      --agree-tos \
      --no-eff-email \
      --non-interactive \
      --cert-name "${domain}" \
      ${STAGING_FLAG} \
      -d "${domain}"

    echo "Certificate created for: ${domain}"
  fi
}


echo
if [ "${SKIP_CERTBOT}" = "true" ]; then
  echo "Ooops! SKIP_CERTBOT set to: ${SKIP_CERTBOT}"
  echo "Domains certificates will not be configured"
  echo "Skipping...."
else
  if [ -n "${PROXY_DOMAINS}" ]; then
    echo "Configuring domains certificate"
      IFS=',' read -ra DOMAINS <<< "${PROXY_DOMAINS}"
      for entry in "${DOMAINS[@]}"; do
        entry="${entry//[[:space:]]/}"
        [ -z "${entry}" ] && continue
        _create_cert "${entry}"
      done
      echo "Done creating certificates."
  else
    echo "Ooops!"
    echo "No certificates to create."
  fi
fi
sleep 1


echo
echo "Adios muchachos..."
IFS=$'\n\t'

