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

if ! verify_fetch; then
  exit 0
fi

node="$FETCH_NODE"

# Fetch first queued job for this node
job="$(ls "$JOB_DIR"/"${node}"-*.json 2>/dev/null | head -n 1 || true)"
if [[ -z "$job" ]]; then
  # 204-like empty body
  exit 0
fi

content="$(cat "$job")"
id="$(basename "$job" .json | cut -d'-' -f2-)"

mv "$job" "$JOB_DIR/${node}-${id}.running"

printf '{"id":"%s","node":"%s","payload":%s}\n' "$id" "$node" "$content"
