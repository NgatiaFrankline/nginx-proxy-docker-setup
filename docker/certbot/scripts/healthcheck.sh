#!/bin/bash
set -euo pipefail
IFS=$'\n\t'


# Check if certbot binary is functional
if ! certbot --help > /dev/null 2>&1; then
  echo "Certbot binary is not working"
  exit 1
fi

# Check if certbot can read certificates directory
if ! certbot certificates > /dev/null 2>&1; then
  echo "Certbot cannot read certificates directory"
  exit 1
fi

echo "Its all good"
exit 0