# Workers

Pick one:

- `bash/worker.sh` for Linux/macOS/BSD/WSL/Cygwin/MSYS2
- `powershell/worker.ps1` for native Windows

Both require:
- Shared `SECRET`
- `NODE_ID` present in server `ALLOWED_NODES`

Run via cron, systemd user service, launchd, or Windows Task Scheduler.
