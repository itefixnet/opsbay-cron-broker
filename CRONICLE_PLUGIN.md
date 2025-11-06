# OpsBay Job Broker - Cronicle Plugin Configuration

This document describes how to configure the OpsBay Job Broker as a Cronicle plugin.

## Plugin Setup

### 1. Install Plugin in Cronicle

1. Copy `cronicle-plugin.sh` to your Cronicle plugins directory (typically `/opt/cronicle/plugins/`)
2. Make it executable: `chmod +x /opt/cronicle/plugins/cronicle-plugin.sh`
3. In Cronicle Admin → Plugins Tab, create a new plugin with these settings:

**Basic Settings:**
- **Plugin ID**: `opsbay-broker`
- **Plugin Title**: `OpsBay Job Broker`
- **Plugin Command**: `/opt/cronicle/plugins/cronicle-plugin.sh`

### 2. Plugin Parameters

Configure these parameters in the Cronicle Plugin definition:

| Parameter ID | Title | Type | Required | Default | Description |
|--------------|--------|------|----------|---------|-------------|
| `broker_url` | Broker URL | text | Yes | `http://localhost:8080` | OpsBay broker server URL |
| `target_node` | Target Node | text | Yes | | Worker node identifier to execute the job |
| `command` | Command | textarea | Yes | | Shell command to execute on the target node |
| `timeout` | Timeout (seconds) | text | No | `60` | Maximum execution time for the job |
| `secret` | Broker Secret | password | No | | HMAC secret (can use BROKER_SECRET env var) |
| `wait_for_completion` | Wait for Completion | checkbox | No | `true` | Wait for job to complete before finishing |
| `poll_interval` | Poll Interval (seconds) | text | No | `5` | How often to check for job completion |
| `max_wait` | Max Wait (seconds) | text | No | `300` | Maximum time to wait for job completion |

### 3. Environment Variables (Alternative Configuration)

Instead of using plugin parameters for sensitive data, you can set environment variables:

```bash
# In Cronicle server environment or systemd service
export BROKER_URL="https://broker.company.com:8080"
export BROKER_SECRET="your-shared-secret-here"
```

### 4. Example Event Configuration

When creating an event in Cronicle using this plugin:

**Event Details:**
- **Plugin**: OpsBay Job Broker
- **Target**: Any server (the plugin will delegate to the specified worker node)

**Plugin Parameters:**
- **Broker URL**: `https://broker.company.com:8080`
- **Target Node**: `prod-web-01`
- **Command**: `sudo systemctl restart nginx && nginx -t`
- **Timeout**: `120`
- **Wait for Completion**: ✓ (checked)
- **Max Wait**: `300`

## Security Considerations

### 1. Secret Management

**Option A: Environment Variables (Recommended)**
Set `BROKER_SECRET` in the Cronicle server environment:
```bash
# In systemd service file
Environment=BROKER_SECRET=your-secret-here
```

**Option B: Plugin Parameter**
Use the `secret` parameter, but note this will be visible in the Cronicle UI to authorized users.

### 2. Network Security

- Ensure Cronicle server can reach the broker URL
- Use HTTPS for broker communication in production
- Restrict broker access to authorized networks

### 3. Command Validation

The plugin executes arbitrary commands on target nodes. Ensure:
- Target nodes are properly secured
- Commands are validated/sanitized if accepting user input
- Worker nodes run with appropriate user permissions

## Plugin Behavior

### 1. Progress Reporting

The plugin reports progress to Cronicle:
- **10%**: Job submitted to broker
- **20%**: Job ID received
- **20-90%**: Waiting for completion (linear progress)
- **100%**: Job completed

### 2. Error Handling

The plugin will fail the Cronicle job if:
- Cannot connect to broker
- Job submission fails
- Job times out (based on `max_wait`)
- Target job exits with non-zero code

### 3. Output Handling

- Plugin status messages go to Cronicle job log
- Target job output is displayed when job completes
- Both stdout and stderr from target are captured

## Integration Examples

### 1. Database Maintenance

```json
{
  "broker_url": "https://broker.company.com:8080",
  "target_node": "db-primary",
  "command": "sudo -u postgres pg_dump production | gzip > /backups/prod-$(date +%Y%m%d).sql.gz",
  "timeout": "1800",
  "wait_for_completion": true,
  "max_wait": "2400"
}
```

### 2. Application Deployment

```json
{
  "broker_url": "https://broker.company.com:8080", 
  "target_node": "app-server-01",
  "command": "cd /app && git pull && npm install && pm2 restart all",
  "timeout": "600",
  "wait_for_completion": true,
  "max_wait": "900"
}
```

### 3. Fire-and-Forget Log Rotation

```json
{
  "broker_url": "https://broker.company.com:8080",
  "target_node": "log-server",
  "command": "logrotate -f /etc/logrotate.conf",
  "timeout": "300",
  "wait_for_completion": false
}
```

## Troubleshooting

### Common Issues

1. **"Failed to read job JSON from STDIN"**
   - Plugin is not receiving proper input from Cronicle
   - Check plugin command path and permissions

2. **"Missing broker_url parameter"**
   - Plugin parameter not configured in Cronicle
   - Check plugin definition and event configuration

3. **"Failed to submit job to broker"**
   - Network connectivity issues
   - Broker server not running
   - Incorrect broker URL

4. **"Timeout waiting for job completion"**
   - Increase `max_wait` parameter
   - Check if target node is responding
   - Verify job isn't stuck on target node

### Debug Mode

To enable debug output, modify the plugin to set:
```bash
set -x  # Enable bash debug mode
```

View detailed logs in the Cronicle job details page.

## Chain Reactions

This plugin supports Cronicle's chain reaction feature. You can:
- Chain to other OpsBay broker jobs
- Chain to different plugins based on success/failure
- Pass job results to downstream events via `chain_data`

The plugin automatically includes job execution details in the chain data when jobs complete.