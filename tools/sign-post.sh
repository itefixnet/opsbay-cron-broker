#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   cat job.json | SECRET="xxx" ./sign-post.sh
#
# Output:
#   Signed JSON with __auth block added.

SECRET="${SECRET:-}"
if [[ -z "$SECRET" ]]; then
    echo "ERROR: SECRET environment variable not set" >&2
    exit 1
fi

# Read raw JSON
raw="$(cat)"

# Remove any preexisting __auth block
clean="$(printf '%s' "$raw" | jq 'del(.__auth)')"

# Timestamp
ts="$(date +%s)"

# Compute HMAC
sig="$(printf '%s%s' "$ts" "$clean" \
    | openssl dgst -sha256 -hmac "$SECRET" -binary \
    | base64)"

# Produce final JSON with __auth inserted
jq -n \
  --arg ts "$ts" \
  --arg sig "$sig" \
  --argjson body "$clean" \
  '
  $body + {
    "__auth": {
      "time": $ts,
      "sig": $sig
    }
  }
  '
