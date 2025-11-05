#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
source ./auth.sh

: "${JOB_DIR:?JOB_DIR missing}"

# Auth (POST with body)
clean="$(verify_post || true)" || true
if [[ "$(jq -r '.error? // empty' <<<"$clean")" != "" ]]; then
  printf '%s\n' "$clean"
  exit 0
fi

# Must include "target"
target="$(jq -r '.target // empty' <<<"$clean")"
if [[ -z "$target" ]]; then
  echo '{"error":"missing target"}'
  exit 0
fi

# (Optional) If you want to prevent queuing for non-allowed nodes:
if ! is_allowed_node "$target"; then
  echo '{"error":"target node not allowed"}'
  exit 0
fi

id="$(date +%s%N)"
file="$JOB_DIR/${target}-${id}.json"
printf '%s' "$clean" > "$file"

printf '{"status":"queued","id":"%s","target":"%s"}\n' "$id" "$target"
