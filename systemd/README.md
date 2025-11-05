# systemd unit

1. Create user/group `opsbay` (or adjust service file).
2. Place repo under `/opt/opsbay-cron-broker`.
3. Copy `server/config.example.env` to `server/.env` and edit.
4. Install:
   ```bash
   sudo cp systemd/jobbroker.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable --now jobbroker
   ```
