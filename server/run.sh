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

: "${PORT:=8080}"
: "${JOB_DIR:=/tmp/opsbay_jobs}"
: "${RESULT_DIR:=/tmp/opsbay_results}"
: "${LOG_DIR:=/tmp/opsbay_logs}"
: "${SECRET:?SECRET is required}"
: "${ALLOWED_NODES:?ALLOWED_NODES is required}"
: "${MAX_SKEW:=300}"

mkdir -p "$JOB_DIR" "$RESULT_DIR" "$LOG_DIR"

echo "[opsbay-cron-broker] starting on :$PORT"
echo "JOB_DIR=$JOB_DIR, RESULT_DIR=$RESULT_DIR, LOG_DIR=$LOG_DIR"
echo "ALLOWED_NODES=$ALLOWED_NODES"

# shell2http must be installed and in PATH
exec shell2http \
  -cgi \
  -port "$PORT" \
  /queue   ./queue.sh \
  /fetch   ./fetch.sh \
  /result  ./result.sh
