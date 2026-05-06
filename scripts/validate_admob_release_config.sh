#!/usr/bin/env bash
set -euo pipefail

SECRETS_FILE="${1:-WanCare/Config/AdMob.Secrets.local.xcconfig}"

if [[ ! -f "$SECRETS_FILE" ]]; then
  echo "error: secrets file not found: $SECRETS_FILE"
  exit 1
fi

if grep -q "3940256099942544" "$SECRETS_FILE"; then
  echo "error: Google test ID is present in release secrets."
  exit 1
fi

if grep -q "xxxxxxxx" "$SECRETS_FILE"; then
  echo "error: placeholder value is still present in release secrets."
  exit 1
fi

echo "ok: release AdMob config looks valid"
