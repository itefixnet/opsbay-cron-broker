# systemd Services

This directory contains systemd service definitions for running the OpsBay broker and worker as system services.

## Services Available

- **`jobbroker.service`** - Broker server service
- **`opsbay-worker.service`** - Worker node service

## 🔧 Broker Setup

1. Create user/group `opsbay` (or adjust service file):
   ```bash
   sudo useradd -r -s /bin/false opsbay
   ```

2. Place repo under `/opt/opsbay-cron-broker`:
   ```bash
   sudo git clone https://github.com/itefixnet/opsbay-cron-broker.git /opt/opsbay-cron-broker
   sudo chown -R opsbay:opsbay /opt/opsbay-cron-broker
   ```

3. Configure broker:
   ```bash
   sudo -u opsbay cp /opt/opsbay-cron-broker/server/config.example.env /opt/opsbay-cron-broker/server/.env
   sudo -u opsbay vim /opt/opsbay-cron-broker/server/.env
   ```

4. Install and start broker service:
   ```bash
   sudo cp /opt/opsbay-cron-broker/systemd/jobbroker.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable --now jobbroker
   ```

## 🏃 Worker Setup

1. Configure worker environment:
   ```bash
   sudo -u opsbay cp /opt/opsbay-cron-broker/systemd/worker.env.example /opt/opsbay-cron-broker/worker.env
   sudo -u opsbay vim /opt/opsbay-cron-broker/worker.env
   ```

2. Update service file to use environment file:
   ```bash
   sudo cp /opt/opsbay-cron-broker/systemd/opsbay-worker.service /etc/systemd/system/
   # Edit /etc/systemd/system/opsbay-worker.service if needed
   sudo vim /etc/systemd/system/opsbay-worker.service
   ```

3. Install and start worker service:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now opsbay-worker
   ```

## 📊 Service Management

### Check status
```bash
# Broker
sudo systemctl status jobbroker

# Worker  
sudo systemctl status opsbay-worker
```

### View logs
```bash
# Broker logs
sudo journalctl -u jobbroker -f

# Worker logs
sudo journalctl -u opsbay-worker -f

# Combined logs
sudo journalctl -u jobbroker -u opsbay-worker -f
```

### Restart services
```bash
sudo systemctl restart jobbroker
sudo systemctl restart opsbay-worker
```

## 🔐 Security Features

The worker service includes comprehensive security hardening:

- **Process isolation**: Runs as dedicated `opsbay` user
- **Filesystem protection**: Read-only system, private temp directories
- **Network restrictions**: Only allows necessary network access
- **Resource limits**: Memory and task limits prevent resource exhaustion
- **Privilege restrictions**: No new privileges, restricted namespaces

## 🎯 Multi-Node Deployment

For multiple worker nodes, customize each deployment:

1. **Unique NODE_ID**: Each worker needs a unique identifier
2. **Same SECRET**: All workers must share the broker's secret
3. **Network access**: Ensure workers can reach the broker API

### Example for multiple workers:
```bash
# Worker 1
sudo sed -i 's/NODE_ID=worker-node-1/NODE_ID=web-server-01/' /etc/systemd/system/opsbay-worker.service

# Worker 2  
sudo sed -i 's/NODE_ID=worker-node-1/NODE_ID=db-server-01/' /etc/systemd/system/opsbay-worker.service

# Reload and start
sudo systemctl daemon-reload
sudo systemctl enable --now opsbay-worker
```

## 🔧 Customization

### Environment File Method (Recommended)

Instead of editing the service file directly, use an environment file:

1. Create `/opt/opsbay-cron-broker/worker.env` with your settings
2. Update the service file to include:
   ```ini
   EnvironmentFile=/opt/opsbay-cron-broker/worker.env
   ```
3. Remove individual `Environment=` lines from the service file

### Direct Service File Method

Edit the service file directly to customize:
- `Environment=API=` - Broker URL
- `Environment=NODE_ID=` - Unique worker identifier  
- `Environment=SECRET=` - Shared authentication secret
- `WorkingDirectory=` - Installation path
- `User=` and `Group=` - Service user/group
