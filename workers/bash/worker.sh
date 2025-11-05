#!/usr/bin/env bash
set -euo pipefail

# ===== CONFIG =====
API="${API:-http://SERVER:8080}"
NODE_ID="${NODE_ID:-node1}"
SECRET="${SECRET:-CHANGE_ME}"
POLL_INTERVAL="${POLL_INTERVAL:-5}"  # seconds
# ==================

# ===== NODE INFO =====
# Gather system information for headers
NODE_HOSTNAME="$(hostname 2>/dev/null || echo 'unknown')"
NODE_OS="$(uname -s 2>/dev/null || echo 'unknown')"
NODE_ARCH="$(uname -m 2>/dev/null || echo 'unknown')"
NODE_KERNEL="$(uname -r 2>/dev/null || echo 'unknown')"
NODE_UPTIME="$(uptime -s 2>/dev/null || echo 'unknown')"
# ======================

hmac_b64() {
  printf '%s' "$1" | openssl dgst -sha256 -hmac "$SECRET" -binary | base64
}

while true; do
  ts="$(date +%s)"
  sig="$(hmac_b64 "${ts}${NODE_ID}")"

  job="$(curl -s \
      -H "X-Time: $ts" \
      -H "X-Auth: $sig" \
      -H "X-Node-Hostname: $NODE_HOSTNAME" \
      -H "X-Node-OS: $NODE_OS" \
      -H "X-Node-Arch: $NODE_ARCH" \
      -H "X-Node-Kernel: $NODE_KERNEL" \
      -H "X-Node-Uptime: $NODE_UPTIME" \
      "$API/fetch?node=$NODE_ID" || true)"

  if [[ -z "$job" || "$job" == "null" ]]; then
    sleep "$POLL_INTERVAL"
    continue
  fi

  id="$(jq -r '.id' <<<"$job")"
  cmd="$(jq -r '.payload.command // empty' <<<"$job")"
  timeout_sec="$(jq -r '.payload.timeout // 0' <<<"$job")"

  if [[ -z "$cmd" ]]; then
    # post back error
    out="no command provided"
    status=1
  else
    if (( timeout_sec > 0 )); then
      if command -v timeout >/dev/null 2>&1; then
        out="$(bash -c "$cmd" 2>&1 | sed 's/\r$//')"
        status=$?
        # NOTE: for true timeout use: out="$(timeout "$timeout_sec" bash -c "$cmd" 2>&1)"; status=$?
      else
        out="$(bash -c "$cmd" 2>&1 | sed 's/\r$//')"
        status=$?
      fi
    else
      out="$(bash -c "$cmd" 2>&1 | sed 's/\r$//')"
      status=$?
    fi
  fi

  body="$(jq -n --arg id "$id" --arg node "$NODE_ID" --arg out "$out" --argjson status "$status" \
      '{id:$id,node:$node,status:$status,output:$out,finished: (now|floor)}')"

  ts="$(date +%s)"
  sig="$(hmac_b64 "${ts}${body}")"

  curl -s -X POST "$API/result" \
    -H "Content-Type: application/json" \
    -H "X-Node-Hostname: $NODE_HOSTNAME" \
    -H "X-Node-OS: $NODE_OS" \
    -H "X-Node-Arch: $NODE_ARCH" \
    -H "X-Node-Kernel: $NODE_KERNEL" \
    -H "X-Node-Uptime: $NODE_UPTIME" \
    -d "$(jq -n --arg ts "$ts" --arg sig "$sig" --argjson payload "$body" \
          '$payload + {__auth: {time: $ts, sig: $sig}}')" >/dev/null 2>&1

  sleep "$POLL_INTERVAL"
done
