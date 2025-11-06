# Workers

The worker daemon polls the broker for jobs and executes them on the target node.

## Bash Worker

Use `worker.sh` for Unix-like systems:
- Linux, macOS, BSD
- Windows via WSL, Cygwin, MSYS2, Git Bash

## Requirements

- Shared `SECRET` between worker and server
- `NODE_ID` present in server `ALLOWED_NODES` configuration
- Dependencies: `bash`, `jq`, `openssl`, `curl`

## Configuration

Set these environment variables:

```bash
API="http://server:8080"        # Broker server URL
NODE_ID="node1"                 # Unique node identifier
SECRET="your-shared-secret"     # Shared secret for HMAC auth
POLL_INTERVAL="5"               # Polling interval in seconds
```

## Running

### Direct execution
```bash
API="http://server:8080" NODE_ID="node1" SECRET="mysecret" ./worker.sh
```

### Via systemd (recommended)
```bash
# Copy worker script to system location
sudo cp worker.sh /opt/opsbay-worker/
sudo chmod +x /opt/opsbay-worker/worker.sh

# Create systemd service (see ../systemd/ for examples)
sudo systemctl enable --now opsbay-worker
```

### Via cron
```bash
# Add to crontab for continuous running
*/1 * * * * /path/to/worker.sh || true
```

## Node Information

The worker automatically reports system information as headers:
- Hostname
- Operating system 
- Architecture
- Kernel version
- System uptime

This information is logged on the server when `LOG_NODE_INFO=true`.
