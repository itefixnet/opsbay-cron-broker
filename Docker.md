# Dockerfile.md — Docker Instructions for opsbay-cron-broker

This document provides usage instructions for running **opsbay-cron-broker** inside a container.  
The image is based on Alpine Linux, includes all required dependencies, and runs the broker via `run.sh`.


# ✅ Build the Docker image

```bash
docker build -t opsbay-cron-broker .
```

---

# ✅ Run with a mounted .env file

```bash
docker run -d \
  --name cron-broker \
  -p 8080:8080 \
  -v $(pwd)/server/.env:/app/server/.env \
  opsbay-cron-broker
```

---

# ✅ Run with persistent directories

```bash
docker run -d \
  -p 8080:8080 \
  -v $(pwd)/data/jobs:/tmp/opsbay_jobs \
  -v $(pwd)/data/results:/tmp/opsbay_results \
  -v $(pwd)/data/logs:/tmp/opsbay_logs \
  -v $(pwd)/server/.env:/app/server/.env \
  opsbay-cron-broker
```

---

# ✅ Notes

- This image includes everything necessary for the broker: `shell2http`, `bash`, `jq`, `openssl`.
- The container simply executes `run.sh` inside `/app/server/`, exactly as in the normal server setup.
- You can override the port, directories, and node settings using the `.env` file.

---
