#!/usr/bin/env bash
set -euo pipefail
domains=(com org net)
threshold_days=30
rc=0
for tld in "${domains[@]}"; do
  cert="/etc/letsencrypt/live/wildcard.frededison.${tld}/fullchain.pem"
  if [[ ! -f "$cert" ]]; then
    echo "[WARN] missing: $cert"
    rc=1
    continue
  end
  endts=$(date -ud "$(openssl x509 -in "$cert" -noout -enddate | cut -d= -f2)" +%s)
  now=$(date -u +%s)
  days=$(( (endts - now) / 86400 ))
  echo "[INFO] wildcard.frededison.${tld} → ${days} days left"
  if (( days <= threshold_days )); then
    echo "[ALERT] wildcard.frededison.${tld} ≤ ${threshold_days} days — renew soon"
    rc=2
  fi
done
exit $rc
