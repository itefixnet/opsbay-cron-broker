# Node Information Headers

The opsbay-cron-broker now includes support for **node information headers** that provide detailed system information about worker nodes to the server.

## What's Included

Workers automatically send the following system information as HTTP headers with each request:

### Headers Sent
- `X-Node-Hostname`: System hostname
- `X-Node-OS`: Operating system name  
- `X-Node-Arch`: System architecture (e.g., x86_64, arm64)
- `X-Node-Kernel`: Kernel version
- `X-Node-Uptime`: System boot time or uptime information

### Endpoints Enhanced
- **GET /fetch** - Node info headers sent with job fetch requests
- **POST /result** - Node info headers sent with job result submissions

## Server Configuration

To enable logging of node information on the server, set the following in your `.env` file:

```bash
LOG_NODE_INFO=true
```

When enabled, the server will log node information to stderr in the format:
```
NODE_INFO: node=testnode hostname=worker01 os=Linux arch=x86_64 kernel=6.8.0-86-generic uptime=2025-11-05 09:19:51
```

## Worker Implementation

### Bash Worker (workers/worker.sh)
The bash worker collects system information using standard commands:
- `hostname` - for hostname
- `uname -s` - for OS name  
- `uname -m` - for architecture
- `uname -r` - for kernel version
- `uptime -s` - for boot time

This worker supports all compatible systems including Linux, macOS, BSD, and Windows via WSL/Cygwin/MSYS2.

## Benefits

1. **Node Monitoring** - Track which physical/virtual machines are executing jobs
2. **Debugging** - Easier troubleshooting by correlating jobs with specific system configurations
3. **Inventory** - Passive discovery of worker node specifications
4. **Compliance** - Track job execution across different OS versions and hardware platforms

## Backward Compatibility

Node information headers are optional and don't affect authentication or core functionality. The system provides comprehensive node tracking capabilities.