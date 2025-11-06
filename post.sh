#!/usr/bin/env bash
set -euo pipefail

SECRET=""
TARGET=""
COMMAND=""
TIMEOUT=""
URL=""
CHECK_RESULT=""
POLL_INTERVAL="2"
MAX_WAIT="60"
NODE_ID=""
JOB_ID=""

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Submit a job or check results in opsbay-cron-broker

OPTIONS:
    --secret SECRET       Shared secret for HMAC authentication (required)
    --url URL            Base URL of the broker (e.g. http://server:8080)
    --target TARGET      Target node for job execution (required for submit)
    --command COMMAND    Command to execute (required for submit)
    --timeout TIMEOUT    Timeout in seconds (required for submit)
    
    --check-result       Check result instead of submitting job
    --node NODE          Node ID for result checking (required with --check-result)
    --job-id ID          Job ID for result checking (required with --check-result)
    
    --wait               Wait for job completion and fetch result
    --poll-interval N    Polling interval in seconds (default: 2)
    --max-wait N         Maximum time to wait in seconds (default: 60)

EXAMPLES:
    # Submit a job
    $0 --secret mysecret --url http://server:8080 \\
       --target node1 --command "echo hello" --timeout 30
    
    # Submit and wait for result
    $0 --secret mysecret --url http://server:8080 \\
       --target node1 --command "echo hello" --timeout 30 --wait
    
    # Check specific result
    $0 --secret mysecret --url http://server:8080 \\
       --check-result --node node1 --job-id 1234567890
    
    # List all results
    $0 --secret mysecret --url http://server:8080 --list-results
EOF
}

# Function to generate HMAC signature
hmac_sign() {
    local data="$1"
    printf '%s' "$data" | openssl dgst -sha256 -hmac "$SECRET" -binary | base64
}

# Function to make authenticated GET request
auth_get() {
    local endpoint="$1"
    local node_for_auth="${2:-${NODE_ID:-${TARGET:-node1}}}"
    local ts sig
    
    ts="$(date +%s)"
    sig="$(hmac_sign "${ts}${node_for_auth}")"
    
    curl -s \
        -H "X-Time: $ts" \
        -H "X-Auth: $sig" \
        "${URL}${endpoint}"
}

# Function to submit a job
submit_job() {
    # ---- Validation ----
    : "${SECRET:?--secret is required}"
    : "${URL:?--url is required (e.g. http://server:8080)}"
    : "${TARGET:?--target is required}"
    : "${COMMAND:?--command is required}"
    : "${TIMEOUT:?--timeout is required}"

    # ---- Build clean JSON (without __auth) ----
    local clean_body
    clean_body=$(jq -n \
      --arg target "$TARGET" \
      --arg cmd "$COMMAND" \
      --argjson timeout "$TIMEOUT" \
      '{target:$target, command:$cmd, timeout:$timeout}')

    # ---- Signing ----
    local ts sig signed_json
    ts=$(date +%s)
    sig=$(hmac_sign "${ts}${clean_body}")

    # ---- Build final signed JSON ----
    signed_json=$(jq -n \
      --arg ts "$ts" \
      --arg sig "$sig" \
      --argjson body "$clean_body" \
      '$body + { "__auth": {time:$ts, sig:$sig} }')

    # ---- POST to API ----
    local response
    response=$(curl -s -X POST "${URL}/queue" \
      -H "Content-Type: application/json" \
      -d "$signed_json")
    
    echo "$response"
    
    # Extract job ID for potential waiting
    JOB_ID=$(echo "$response" | jq -r '.id // empty')
    NODE_ID="$TARGET"
}

# Function to check a specific result
check_result() {
    : "${SECRET:?--secret is required}"
    : "${URL:?--url is required}"
    : "${NODE_ID:?--node is required for result checking}"
    : "${JOB_ID:?--job-id is required for result checking}"
    
    auth_get "/get-result?node=${NODE_ID}&id=${JOB_ID}"
}

# Function to list all results
list_results() {
    : "${SECRET:?--secret is required}"
    : "${URL:?--url is required}"
    
    # For list-results, we need to provide a node for authentication
    # Use the first allowed node or a default
    local auth_node="${NODE_ID:-${TARGET:-node1}}"
    
    auth_get "/list-results" "$auth_node"
}

# Function to wait for job completion
wait_for_result() {
    local start_time elapsed
    start_time="$(date +%s)"
    
    echo "Waiting for job completion (max ${MAX_WAIT}s, polling every ${POLL_INTERVAL}s)..." >&2
    
    while true; do
        elapsed=$(($(date +%s) - start_time))
        
        if (( elapsed >= MAX_WAIT )); then
            echo '{"error":"timeout waiting for result"}' >&2
            return 1
        fi
        
        local result
        result=$(auth_get "/get-result?node=${NODE_ID}&id=${JOB_ID}")
        
        if [[ "$(echo "$result" | jq -r '.error // empty')" != "result not found" ]]; then
            echo "$result"
            return 0
        fi
        
        sleep "$POLL_INTERVAL"
    done
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --secret)
            SECRET="$2"
            shift 2
            ;;
        --url)
            URL="$2"
            shift 2
            ;;
        --target)
            TARGET="$2"
            shift 2
            ;;
        --command)
            COMMAND="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --check-result)
            CHECK_RESULT="true"
            shift
            ;;
        --node)
            NODE_ID="$2"
            shift 2
            ;;
        --job-id)
            JOB_ID="$2"
            shift 2
            ;;
        --list-results)
            LIST_RESULTS="true"
            shift
            ;;
        --wait)
            WAIT_FOR_RESULT="true"
            shift
            ;;
        --poll-interval)
            POLL_INTERVAL="$2"
            shift 2
            ;;
        --max-wait)
            MAX_WAIT="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

# Main logic
if [[ "${LIST_RESULTS:-}" == "true" ]]; then
    list_results
elif [[ "${CHECK_RESULT:-}" == "true" ]]; then
    check_result
else
    # Submit job
    submit_response=$(submit_job)
    echo "$submit_response"
    
    # Check if we should wait for the result
    if [[ "${WAIT_FOR_RESULT:-}" == "true" && -n "$JOB_ID" ]]; then
        echo "" >&2  # Add a blank line for readability
        wait_for_result
    fi
fi
