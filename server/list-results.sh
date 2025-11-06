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

: "${RESULT_DIR:?RESULT_DIR missing}"

# Basic authentication check (GET request with headers)
if ! verify_get_auth; then
  exit 0
fi

# List all result files and build JSON response
results="[]"
if ls "$RESULT_DIR"/*.json >/dev/null 2>&1; then
  for result_file in "$RESULT_DIR"/*.json; do
    if [[ -f "$result_file" ]]; then
      filename="$(basename "$result_file" .json)"
      # Extract node and id from filename format: node-id.json
      if [[ "$filename" =~ ^(.+)-([^-]+)$ ]]; then
        node="${BASH_REMATCH[1]}"
        id="${BASH_REMATCH[2]}"
        
        # Get file modification time and size
        mod_time="$(stat -c %Y "$result_file" 2>/dev/null || echo "0")"
        file_size="$(stat -c %s "$result_file" 2>/dev/null || echo "0")"
        
        # Try to extract status from the result file
        status="$(jq -r '.status // "unknown"' "$result_file" 2>/dev/null || echo "unknown")"
        finished="$(jq -r '.finished // 0' "$result_file" 2>/dev/null || echo "0")"
        
        # Add to results array
        results="$(jq -n \
          --argjson existing "$results" \
          --arg node "$node" \
          --arg id "$id" \
          --arg status "$status" \
          --argjson finished "$finished" \
          --argjson mod_time "$mod_time" \
          --argjson size "$file_size" \
          '$existing + [{
            node: $node,
            id: $id,
            status: ($status | tonumber? // $status),
            finished: $finished,
            modified: $mod_time,
            size: $size
          }]')"
      fi
    fi
  done
fi

# Sort results by finished time (newest first)
jq -n \
  --argjson results "$results" \
  '{
    count: ($results | length),
    results: ($results | sort_by(.finished) | reverse)
  }'