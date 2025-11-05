# opsbay-cron-broker

A tiny, **shell2http**-based job broker for centralizing cron/Cronicle operations across **multiple nodes**, with **HMAC authentication** and an **allowed node list**.

- Central API (`/queue`, `/fetch`, `/result`)
- Workers poll, execute, and return results
- Mixed OS support (Linux, macOS, BSD, Windows via Git Bash/Cygwin/MSYS2/WSL)
- No heavy runtime: just `shell2http`, `jq`, `openssl`, `curl`/PowerShell

## Endpoints

- `POST /queue` — Cronicle enqueues a job (targeted to a node)
- `GET  /fetch?node=<node>` — Worker fetches next job for `<node>`
- `POST /result` — Worker posts execution result

All endpoints require HMAC auth (see `server/README.md`).

## Quick start

```bash
# on the server
cd server
cp config.example.env .env
# edit .env: set SECRET and ALLOWED_NODES, optionally PORT, DIRS
./run.sh
```

On each node, run the worker (bash or PowerShell). See `workers/README.md`.

## License

BSD 2-Clause — see LICENSE.
