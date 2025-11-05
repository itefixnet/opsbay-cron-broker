#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

if [ -f .env ]; then
  set -a
  source .env
  set +a
else
  echo "WARNING: .env not found. Using defaults from config.example.env or env."
fi

source ./auth.sh

: "${JOB_DIR:?JOB_DIR missing}"
: "${RESULT_DIR:?RESULT_DIR missing}"

clean="$(verify_post || true)" || true
if [[ "$(jq -r '.error? // empty' <<<"$clean")" != "" ]]; then
  printf '%s\n' "$clean"
  exit 0
fi

node="$(jq -r '.node // empty' <<<"$clean")"
id="$(jq -r '.id // empty' <<<"$clean")"

if [[ -z "$node" || -z "$id" ]]; then
  echo '{"error":"missing node or id"}'
  exit 0
fi

if ! is_allowed_node "$node"; then
  echo '{"error":"node not allowed"}'
  exit 0
fi

printf '%s' "$clean" > "$RESULT_DIR/${node}-${id}.json"
rm -f "$JOB_DIR/${node}-${id}.running" 2>/dev/null || true

echo '{"status":"stored"}'
