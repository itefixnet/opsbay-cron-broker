# opsbay-cron-broker

**opsbay-cron-broker** is primarily designed to support the **Jobs** feature of [**OpsBay**](https://opsbay.com ) using [**Cronicle**](https://cronicle.org).

It acts as a lightweight, distributed job broker that lets Cronicle delegate job execution to multiple authenticated worker nodes.

However, **opsbay-cron-broker can also be used independently** as a standalone, secure cron/job dispatching system without OpsBay or Cronicle.

---

A tiny, **shell2http**-based job broker for centralizing cron/Cronicle operations across **multiple nodes**, with **HMAC authentication** and an **allowed node list**.

- Central API (`/queue`, `/fetch`, `/result`)
- Workers poll, execute, and return results
- Mixed OS support (Linux, macOS, BSD, Windows via Git Bash/Cygwin/MSYS2/WSL)
- No heavy runtime: just `shell2http`, `jq`, `openssl`, `curl`/PowerShell

## Endpoints

- `POST /queue` — Cronicle or external systems enqueue a job (targeted to a node)
- `GET  /fetch?node=<node>` — Worker fetches next job for `<node>`
- `POST /result` — Worker posts execution result

All endpoints require HMAC auth (see `server/README.md`).

## Quick start

```bash
# on the server
cd server
cp config.example.env .env
# edit .env: set SECRET and ALLOWED_NODES, optionally PORT and DIRS
./run.sh
```

On each node, run the worker (bash or PowerShell). See `workers/README.md`.

## License

BSD 2-Clause — see LICENSE.