#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
END='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'

echo
echo "Starting certbot...."

# Issue certificates for all domains on startup
source /scripts/create_certs.sh


echo
echo "Starting crond to renew certs every day at 2am"
# add cron to renew certificates at 2am every day
# Send logs every job execution to stderr if you are using: crond -f
#echo "0 2 * * * certbot renew --webroot -w /var/www/certbot 2>&1 | tee -a /var/log/certbot-renew.log" | crontab -

# Add -d 8 for debug/verbose logging to stderr (visible in docker logs):
echo "0 2 * * * certbot renew --webroot -w /var/www/certbot --quiet" | crontab -
crond -f -d 8

