# opsbay-cron-broker

A lightweight distributed job broker for centralizing cron/Cronicle operations across multiple nodes.

## 🎯 Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   post.sh       │    │   Broker Server  │    │   Worker Nodes  │
│   (Client)      │───▶│   (shell2http)   │◀───│   (worker.sh)   │
│                 │    │                  │    │                 │
│ • Submit jobs   │    │ • Queue mgmt     │    │ • Poll for jobs │
│ • Check results │    │ • HMAC auth      │    │ • Execute cmds  │
│ • Monitor       │    │ • Node tracking  │    │ • Report back   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 🚀 Core Components

### 1. Broker Server (`server/`)
- **shell2http**-based HTTP API
- HMAC SHA-256 authentication
- Node information tracking
- Result storage and retrieval
- No heavy dependencies

### 2. Worker Daemon (`workers/worker.sh`)
- Bash-based worker daemon
- Continuous polling for jobs
- Command execution with timeout support
- System information reporting
- Automatic result submission

### 3. Client Tool (`post.sh`)
- Command-line job submission
- Result checking and monitoring  
- Wait for completion with polling
- List all job results
- CI/CD integration ready

## 📋 Supported Platforms

- **Linux** (all distributions)
- **macOS** 
- **BSD** variants
- **WSL** (Windows Subsystem for Linux)
- **MSYS2/Cygwin** (Windows with bash tools)

### 📦 Dependencies
- `bash` (4.0+)
- `jq` (JSON processing)
- `openssl` (HMAC signatures)
- `curl` (HTTP client)
- `shell2http` (server only)

## 🔧 Quick Setup

### Server Setup
```bash
# Download and setup
git clone https://github.com/itefixnet/opsbay-cron-broker.git
cd opsbay-cron-broker/server

# Configure
cp config.example.env .env
vim .env  # Set SECRET, ALLOWED_NODES

# Install shell2http
curl -L https://github.com/msoap/shell2http/releases/download/v1.17.0/shell2http_1.17.0_linux_amd64.tar.gz | tar xz
chmod +x shell2http

# Start broker
./run.sh
```

### Worker Setup
```bash
# On each worker node
cd opsbay-cron-broker
API="http://server:8080" \
NODE_ID="worker1" \
SECRET="your-shared-secret" \
./workers/worker.sh
```

### Client Usage
```bash
# Submit a job
./post.sh --secret "your-secret" --url "http://server:8080" \
  --target "worker1" --command "echo hello" --timeout 30

# Submit and wait
./post.sh --secret "your-secret" --url "http://server:8080" \
  --target "worker1" --command "backup-db" --timeout 300 --wait

# Check specific result
./post.sh --secret "your-secret" --url "http://server:8080" \
  --check-result --node "worker1" --job-id "1234567890"

# List all results
./post.sh --secret "your-secret" --url "http://server:8080" --list-results
```

## 🔐 Security Features

- **HMAC Authentication**: SHA-256 signatures prevent unauthorized access
- **Node Authorization**: Only allowed nodes can fetch jobs
- **Timestamp Protection**: Prevents replay attacks
- **Secure Headers**: Node information passed securely
- **No Credentials Storage**: Workers only need shared secret

## 📊 Monitoring & Observability

### Node Information Tracking
Workers automatically report:
- Hostname
- Operating System
- Architecture (x86_64, arm64, etc.)
- Kernel version
- System uptime

### Result Management
- Complete job history with timestamps
- Exit codes and output capture
- File-based result storage
- RESTful result retrieval
- Metadata tracking (job size, modification time)

## 🔌 Integration Examples

### Systemd Service
```ini
[Unit]
Description=OpsBay Worker
After=network.target

[Service]
Type=simple
ExecStart=/opt/opsbay-worker/worker.sh
Environment=API=http://broker:8080
Environment=NODE_ID=prod-worker1
Environment=SECRET=your-secret-here
Restart=always
User=opsbay

[Install]
WantedBy=multi-user.target
```

### CI/CD Pipeline
```yaml
name: Deploy Application
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to Production
        run: |
          ./post.sh \
            --secret "${{ secrets.BROKER_SECRET }}" \
            --url "https://broker.company.com" \
            --target "prod-server" \
            --command "deploy-app v${{ github.run_number }}" \
            --timeout 1800 \
            --wait
```

### Cronicle Integration
```json
{
  "__auth": {
    "time": "${time_epoch}",
    "sig": "${hmac_signature}"
  },
  "target": "maintenance-node",
  "command": "run-maintenance-script.sh",
  "timeout": 3600
}
```

## 📚 Documentation

- **[NODE_INFO.md](NODE_INFO.md)** - Node information tracking details
- **[RESULT_DELIVERY.md](RESULT_DELIVERY.md)** - Result retrieval and monitoring
- **[workers/README.md](workers/README.md)** - Worker configuration and deployment
- **[server/README.md](server/README.md)** - Server setup and authentication
- **[Docker.md](Docker.md)** - Container deployment instructions

## 🎯 Use Cases

### Infrastructure Management
- **Configuration Deployment**: Push configs to multiple servers
- **System Maintenance**: Coordinate maintenance tasks across nodes
- **Log Collection**: Gather logs from distributed systems
- **Health Checks**: Monitor system health across environments

### DevOps & CI/CD
- **Application Deployment**: Deploy apps to multiple environments
- **Database Migrations**: Run migrations across database clusters
- **Test Execution**: Distribute test suites across test nodes
- **Backup Orchestration**: Coordinate backup operations

### Data Processing
- **ETL Pipeline**: Distribute data processing tasks
- **Report Generation**: Generate reports on dedicated nodes
- **File Processing**: Process files across worker machines
- **Batch Jobs**: Execute scheduled batch operations

## 🤝 OpsBay Integration

While designed for **[OpsBay](https://opsbay.com)** and **[Cronicle](https://cronicle.org)** integration, opsbay-cron-broker works perfectly as a standalone distributed job execution system.

## 📄 License

BSD 2-Clause License - see [LICENSE](LICENSE)

## 🔗 Links

- **Project Repository**: https://github.com/itefixnet/opsbay-cron-broker
- **OpsBay Platform**: https://opsbay.com
- **Cronicle Scheduler**: https://cronicle.org
- **shell2http**: https://github.com/msoap/shell2http