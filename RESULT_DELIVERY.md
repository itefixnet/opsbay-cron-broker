# Result Delivery and Retrieval

The opsbay-cron-broker now includes comprehensive **result delivery and retrieval** functionality, allowing clients to fetch job results and monitor job completion status.

## New Server Endpoints

### GET /get-result
Retrieve a specific job result by node and job ID.

**Parameters:**
- `node` - The target node that executed the job
- `job-id` - The unique job identifier

**Authentication:** Requires HMAC authentication headers (`X-Time`, `X-Auth`)

**Example:**
```bash
curl -H "X-Time: 1762404276" -H "X-Auth: <signature>" \
  "http://server:8080/get-result?node=node1&id=1234567890"
```

**Response:**
```json
{
  "id": "1234567890",
  "node": "node1", 
  "status": 0,
  "output": "Job completed successfully\nFri Nov  6 05:44:45 CET 2025",
  "finished": 1762404285
}
```

### GET /list-results
List all available job results with metadata.

**Authentication:** Requires HMAC authentication headers

**Example:**
```bash
curl -H "X-Time: 1762404276" -H "X-Auth: <signature>" \
  "http://server:8080/list-results"
```

**Response:**
```json
{
  "count": 3,
  "results": [
    {
      "node": "node1",
      "id": "1234567890", 
      "status": 0,
      "finished": 1762404285,
      "modified": 1762404285,
      "size": 171
    },
    {
      "node": "node2",
      "id": "1234567891",
      "status": 1,
      "finished": 1762404200,
      "modified": 1762404200, 
      "size": 145
    }
  ]
}
```

## Enhanced post.sh Client

The `post.sh` client tool is a core component of opsbay-cron-broker that provides comprehensive job management capabilities:

### Submit a Job (Original Functionality)
```bash
./post.sh --secret "mysecret" --url "http://server:8080" \
  --target "node1" --command "echo hello" --timeout 30
```

### Check a Specific Result
```bash
./post.sh --secret "mysecret" --url "http://server:8080" \
  --check-result --node "node1" --job-id "1234567890"
```

### List All Results
```bash
./post.sh --secret "mysecret" --url "http://server:8080" --list-results
```

### Submit Job and Wait for Completion
```bash
./post.sh --secret "mysecret" --url "http://server:8080" \
  --target "node1" --command "echo hello" --timeout 30 --wait
```

### Advanced Wait Options
```bash
./post.sh --secret "mysecret" --url "http://server:8080" \
  --target "node1" --command "long-running-task" --timeout 300 --wait \
  --poll-interval 5 --max-wait 120
```

## New Command Line Options

| Option | Description |
|--------|-------------|
| `--check-result` | Check result instead of submitting job |
| `--node NODE` | Node ID for result checking (required with --check-result) |
| `--job-id ID` | Job ID for result checking (required with --check-result) |
| `--list-results` | List all available results |
| `--wait` | Wait for job completion and fetch result |
| `--poll-interval N` | Polling interval in seconds (default: 2) |
| `--max-wait N` | Maximum time to wait in seconds (default: 60) |

## Complete Workflow Examples

### 1. Fire-and-Forget
```bash
# Submit job, get job ID back immediately
./post.sh --secret "mysecret" --url "http://server:8080" \
  --target "node1" --command "backup-database" --timeout 1800
# Output: {"status":"queued","id":"1234567890","target":"node1"}
```

### 2. Submit and Wait
```bash
# Submit job and automatically wait for completion
./post.sh --secret "mysecret" --url "http://server:8080" \
  --target "node1" --command "generate-report" --timeout 300 --wait
# Output: Job submission response, then result when completed
```

### 3. Check Later
```bash
# Check result of previously submitted job
./post.sh --secret "mysecret" --url "http://server:8080" \
  --check-result --node "node1" --job-id "1234567890"
```

### 4. Monitor All Jobs
```bash
# List all results to monitor job completion status
./post.sh --secret "mysecret" --url "http://server:8080" --list-results
```

## Security

- All result endpoints require HMAC authentication
- Node access control is enforced (only allowed nodes can be queried)
- Results are stored in `RESULT_DIR` with restricted file permissions
- Timestamp-based replay protection is applied to all requests

## Integration Examples

### Shell Scripts
```bash
#!/bin/bash
SECRET="mysecret"
URL="http://server:8080"

# Submit job
RESPONSE=$(./post.sh --secret "$SECRET" --url "$URL" \
  --target "node1" --command "important-task" --timeout 600)

JOB_ID=$(echo "$RESPONSE" | jq -r '.id')
echo "Submitted job $JOB_ID"

# Poll for completion
while true; do
  RESULT=$(./post.sh --secret "$SECRET" --url "$URL" \
    --check-result --node "node1" --job-id "$JOB_ID")
  
  if [[ "$(echo "$RESULT" | jq -r '.error // empty')" != "result not found" ]]; then
    echo "Job completed:"
    echo "$RESULT" | jq '.output'
    exit $(echo "$RESULT" | jq -r '.status')
  fi
  
  sleep 5
done
```

### CI/CD Integration
```yaml
# Example GitHub Actions workflow
- name: Deploy to Node
  run: |
    RESULT=$(./post.sh --secret "${{ secrets.BROKER_SECRET }}" \
      --url "https://broker.example.com" \
      --target "prod-node1" --command "deploy-app v1.2.3" \
      --timeout 1800 --wait)
    
    STATUS=$(echo "$RESULT" | jq -r '.status')
    if [ "$STATUS" != "0" ]; then
      echo "Deployment failed!"
      echo "$RESULT" | jq -r '.output'
      exit 1
    fi
```

## Benefits

1. **Asynchronous Operations** - Submit jobs and check results later
2. **Job Monitoring** - Track completion status of all submitted jobs  
3. **Error Handling** - Retrieve detailed error information and exit codes
4. **Integration Friendly** - Easy to integrate into scripts, CI/CD, and monitoring systems
5. **Audit Trail** - Complete history of job executions with timestamps
6. **Flexible Polling** - Configurable polling intervals and timeouts