#!/bin/bash

# OpsBay Cronicle Plugin - Job Broker Client
# Submits jobs to opsbay-cron-broker from within Cronicle
# Based on post.sh but modified for Cronicle plugin compatibility

set -euo pipefail

# Plugin metadata (used by Cronicle UI)
# This would be configured in the Cronicle Plugin definition

# Default configuration (can be overridden by plugin parameters)
DEFAULT_BROKER_URL="http://localhost:8080"
DEFAULT_POLL_INTERVAL=5
DEFAULT_MAX_WAIT=300

# Read job information from STDIN (Cronicle standard)
if ! read -r job_json; then
    echo '{"complete": 1, "code": 1, "description": "Failed to read job JSON from STDIN"}' >&1
    exit 1
fi

# Parse job JSON
job_id=$(echo "$job_json" | jq -r '.id // empty')
if [[ -z "$job_id" ]]; then
    echo '{"complete": 1, "code": 1, "description": "Missing job ID in input JSON"}' >&1
    exit 1
fi

# Extract plugin parameters (these come from Cronicle plugin configuration)
broker_url=$(echo "$job_json" | jq -r '.params.broker_url // empty')
target_node=$(echo "$job_json" | jq -r '.params.target_node // empty')
command=$(echo "$job_json" | jq -r '.params.command // empty')
timeout=$(echo "$job_json" | jq -r '.params.timeout // "60"')
secret=$(echo "$job_json" | jq -r '.params.secret // empty')
wait_for_completion=$(echo "$job_json" | jq -r '.params.wait_for_completion // "true"')
poll_interval=$(echo "$job_json" | jq -r '.params.poll_interval // "5"')
max_wait=$(echo "$job_json" | jq -r '.params.max_wait // "300"')

# Use environment variables as fallback (from Cronicle job environment)
broker_url=${broker_url:-${BROKER_URL:-$DEFAULT_BROKER_URL}}
secret=${secret:-${BROKER_SECRET:-}}
poll_interval=${poll_interval:-$DEFAULT_POLL_INTERVAL}
max_wait=${max_wait:-$DEFAULT_MAX_WAIT}

# Validate required parameters
if [[ -z "$broker_url" ]]; then
    echo '{"complete": 1, "code": 1, "description": "Missing broker_url parameter"}' >&1
    exit 1
fi

if [[ -z "$target_node" ]]; then
    echo '{"complete": 1, "code": 1, "description": "Missing target_node parameter"}' >&1
    exit 1
fi

if [[ -z "$command" ]]; then
    echo '{"complete": 1, "code": 1, "description": "Missing command parameter"}' >&1
    exit 1
fi

if [[ -z "$secret" ]]; then
    echo '{"complete": 1, "code": 1, "description": "Missing secret parameter or BROKER_SECRET environment variable"}' >&1
    exit 1
fi

# Log job start (goes to Cronicle job log)
echo "OpsBay Job Broker: Submitting job to $target_node"
echo "Command: $command"
echo "Timeout: ${timeout}s"

# HMAC signature function
hmac_sha256() {
    local key="$1"
    local data="$2"
    echo -n "$data" | openssl dgst -sha256 -hmac "$key" -binary | base64
}

# Submit job to broker
submit_job() {
    local timestamp=$(date +%s)
    local payload=$(jq -nc \
        --arg target "$target_node" \
        --arg command "$command" \
        --arg timeout "$timeout" \
        --arg time "$timestamp" \
        '{
            target: $target,
            command: $command,
            timeout: ($timeout | tonumber),
            __auth: {
                time: ($time | tonumber),
                sig: ""
            }
        }')
    
    # Calculate HMAC signature
    local auth_string="${timestamp}:${payload}"
    local signature=$(hmac_sha256 "$secret" "$auth_string")
    
    # Add signature to payload
    payload=$(echo "$payload" | jq --arg sig "$signature" '.["__auth"]["sig"] = $sig')
    
    # Submit job
    local response
    if ! response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$broker_url/queue" 2>&1); then
        echo '{"complete": 1, "code": 1, "description": "Failed to submit job to broker"}' >&1
        exit 1
    fi
    
    # Parse job ID from response
    local submitted_job_id
    if ! submitted_job_id=$(echo "$response" | jq -r '.id // empty'); then
        echo '{"complete": 1, "code": 1, "description": "Invalid response from broker"}' >&1
        exit 1
    fi
    
    if [[ -z "$submitted_job_id" ]]; then
        echo '{"complete": 1, "code": 1, "description": "No job ID returned from broker"}' >&1
        exit 1
    fi
    
    echo "$submitted_job_id"
}

# Check job result
check_result() {
    local job_id="$1"
    local timestamp=$(date +%s)
    local auth_string="${timestamp}:GET:/get-result:node=${target_node}&id=${job_id}"
    local signature=$(hmac_sha256 "$secret" "$auth_string")
    
    curl -s -G \
        -d "node=$target_node" \
        -d "id=$job_id" \
        -H "X-Auth-Time: $timestamp" \
        -H "X-Auth-Signature: $signature" \
        "$broker_url/get-result"
}

# Submit the job
echo '{"progress": 0.1}' >&1
submitted_job_id=$(submit_job)

if [[ -z "$submitted_job_id" ]]; then
    echo '{"complete": 1, "code": 1, "description": "Failed to get job ID from submission"}' >&1
    exit 1
fi

echo "Job submitted with ID: $submitted_job_id"
echo '{"progress": 0.2}' >&1

# If not waiting for completion, finish here
if [[ "$wait_for_completion" != "true" ]]; then
    echo "Job submitted successfully (not waiting for completion)"
    echo '{"complete": 1, "code": 0, "description": "Job submitted to broker"}' >&1
    exit 0
fi

# Wait for completion
echo "Waiting for job completion (max ${max_wait}s)..."
start_time=$(date +%s)
last_progress=0.2

while true; do
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    
    # Check for timeout
    if [[ $elapsed -gt $max_wait ]]; then
        echo "Timeout waiting for job completion"
        echo '{"complete": 1, "code": 1, "description": "Timeout waiting for job completion"}' >&1
        exit 1
    fi
    
    # Update progress based on elapsed time
    progress=$(echo "scale=2; $last_progress + (0.7 * $elapsed / $max_wait)" | bc -l 2>/dev/null || echo "$last_progress")
    if (( $(echo "$progress > 0.9" | bc -l 2>/dev/null || echo "0") )); then
        progress="0.9"
    fi
    echo "{\"progress\": $progress}" >&1
    
    # Check for result
    result=$(check_result "$submitted_job_id")
    
    if [[ -n "$result" ]] && [[ "$result" != "null" ]]; then
        # Parse result
        exit_code=$(echo "$result" | jq -r '.exit_code // 1')
        output=$(echo "$result" | jq -r '.output // ""')
        
        echo "Job completed with exit code: $exit_code"
        if [[ -n "$output" ]]; then
            echo "Job output:"
            echo "$output"
        fi
        
        # Report completion to Cronicle
        echo '{"progress": 1.0}' >&1
        
        if [[ "$exit_code" == "0" ]]; then
            echo '{"complete": 1, "code": 0, "description": "Job completed successfully"}' >&1
        else
            description="Job failed with exit code $exit_code"
            if [[ -n "$output" ]]; then
                description="$description: $output"
            fi
            echo "{\"complete\": 1, \"code\": $exit_code, \"description\": \"$description\"}" >&1
        fi
        
        exit "$exit_code"
    fi
    
    sleep "$poll_interval"
done