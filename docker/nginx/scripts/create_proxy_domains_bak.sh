#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
DOMAIN_TEMPLATE="/conf/domain-template.conf"
NGINX_CONFD_DIR="/etc/nginx/conf.d/"


echo
echo "Creating proxy domains script"
echo "Checking env variables"
[ -z "${PROXY_DOMAINS}" ] && echo "PROXY_DOMAINS cannot be empty" && exit 1
echo "All env data set, proceeding..."
sleep 1


echo "Checking domains template file: ${DOMAIN_TEMPLATE}"
if [ ! -f "${DOMAIN_TEMPLATE}" ]; then
  echo "OOPS! Template: ${DOMAIN_TEMPLATE} not found"
  echo "Exiting with error 1"
  exit 1
fi
echo "Template found!"
sleep 1

# THE LOGIC
# make the string PROXY_DOMAINS by separing by comma, each item value array has format like: example.com:container_name:port
# which represents the domain, container_name and container_port
# loop and create a conf file using DOMAIN_TEMPLATE and place it in NGINX_CONFD_DIR,
# rename the newly created template with domain name as text i.e. example_com.conf
# in the template replace placehold {MY_DOMAIN} with the domain,
# and placeholder {CONTAINER_URL} with values: container_name and container_port construct as container_name:container_port
# from the values in loop item values
