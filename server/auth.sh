#!/usr/bin/env bash
# Utilities for HMAC auth + replay protection + allowed node checks.
# Usage:
#   For POST (queue/result): read full body from stdin, outputs CLEAN_BODY to stdout if valid.
#   For GET fetch: helpers read headers from shell2http variables.
#
# Requires env: SECRET, MAX_SKEW, ALLOWED_NODES

set -euo pipefail

: "${SECRET:?SECRET missing}"
: "${MAX_SKEW:=300}"
: "${ALLOWED_NODES:?ALLOWED_NODES missing}"

# is_allowed_node <node>
is_allowed_node() {
  local n="$1"
  IFS=',' read -r -a arr <<< "$ALLOWED_NODES"
  for x in "${arr[@]}"; do
    [[ "$x" == "$n" ]] && return 0
  done
  return 1
}

# now (epoch seconds)
now() { date +%s; }

# hmac_b64 <data>
hmac_b64() {
  printf '%s' "$1" | openssl dgst -sha256 -hmac "$SECRET" -binary | base64
}

# verify_post: stdin is full JSON body
# Expects: {"__auth":{"time":"<ts>","sig":"<b64>"} ...}
# Outputs clean JSON (without __auth) to stdout if valid.
verify_post() {
  local raw body ts sig exp skew
  raw="$(cat)"
  ts="$(printf '%s' "$raw" | jq -r '.__auth.time')"
  sig="$(printf '%s' "$raw" | jq -r '.__auth.sig')"
  body="$(printf '%s' "$raw" | jq 'del(.__auth)')"

  if [[ -z "$ts" || -z "$sig" || "$ts" == "null" || "$sig" == "null" ]]; then
    echo '{"error":"missing auth"}'
    return 1
  fi

  # replay protection
  local now_ts
  now_ts="$(now)"
  skew=$(( now_ts - ts ))
  if (( skew < 0 )); then skew=$(( -skew )); fi
  if (( skew > MAX_SKEW )); then
    echo '{"error":"timestamp skew too large"}'
    return 1
  fi

  exp="$(hmac_b64 "${ts}${body}")"
  if [[ "$exp" != "$sig" ]]; then
    echo '{"error":"bad signature"}'
    return 1
  fi

  printf '%s' "$body"
}

# verify_fetch populates $FETCH_NODE and returns 0 if valid
verify_fetch() {
  # shell2http maps headers to HTTP_X_*, query to HTTP_QUERY_*
  local ts="${HTTP_X_TIME:-}"
  local sig="${HTTP_X_AUTH:-}"
  local node="${HTTP_QUERY_NODE:-${HTTP_X_NODE:-}}"

    echo "DEBUG: ts=$ts sig=$sig node=$node"
    
  if [[ -z "$ts" || -z "$sig" || -z "$node" ]]; then
    echo '{"error":"missing fetch auth or node"}'
    return 1
  fi

  if ! is_allowed_node "$node"; then
    echo '{"error":"node not allowed"}'
    return 1
  fi

  # replay protection
  local now_ts skew
  now_ts="$(now)"
  skew=$(( now_ts - ts ))
  if (( skew < 0 )); then skew=$(( -skew )); fi
  if (( skew > MAX_SKEW )); then
    echo '{"error":"timestamp skew too large"}'
    return 1
  fi

  local exp
  exp="$(hmac_b64 "${ts}${node}")"
  if [[ "$exp" != "$sig" ]]; then
    echo '{"error":"bad signature"}'
    return 1
  fi

  FETCH_NODE="$node"
  return 0
}
