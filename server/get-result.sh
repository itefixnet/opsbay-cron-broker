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

# Parse URL path to extract node and id
# Expected format: /get-result/node/id or /get-result?node=xxx&id=yyy
if [[ -n "${REQUEST_URI:-}" ]]; then
  # Extract from path: /get-result/node/id
  if [[ "$REQUEST_URI" =~ ^/get-result/([^/]+)/([^/?]+) ]]; then
    node="${BASH_REMATCH[1]}"
    id="${BASH_REMATCH[2]}"
  else
    # Extract from query string
    node=""
    id=""
    if [[ -n "${QUERY_STRING:-}" ]]; then
      # Parse query string for node and id parameters
      for param in $(echo "$QUERY_STRING" | tr '&' ' '); do
        key="${param%=*}"
        value="${param#*=}"
        case "$key" in
          node) node="$value" ;;
          id) id="$value" ;;
        esac
      done
    fi
  fi
else
  # Fallback: try to extract from query string environment
  node=""
  id=""
  if [[ -n "${QUERY_STRING:-}" ]]; then
    for param in $(echo "$QUERY_STRING" | tr '&' ' '); do
      key="${param%=*}"
      value="${param#*=}"
      case "$key" in
        node) node="$value" ;;
        id) id="$value" ;;
      esac
    done
  fi
fi

# Basic authentication check (GET request with headers)
if ! verify_fetch; then
  exit 0
fi

if [[ -z "$node" || -z "$id" ]]; then
  echo '{"error":"missing node or id parameters"}'
  exit 0
fi

if ! is_allowed_node "$node"; then
  echo '{"error":"node not allowed"}'
  exit 0
fi

result_file="$RESULT_DIR/${node}-${id}.json"
if [[ -f "$result_file" ]]; then
  cat "$result_file"
else
  echo '{"error":"result not found"}'
fi