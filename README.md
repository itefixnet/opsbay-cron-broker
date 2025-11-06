# opsbay-cron-broker

A lightweight distributed job broker for centralizing cron/Cronicle operations across multiple nodes.

**Perfect for**: Infrastructure automation, CI/CD pipelines, distributed task execution, and OpsBay/Cronicle integration.

## ✨ Key Features

- **🔐 Secure**: HMAC SHA-256 authentication with node authorization
- **📊 Observable**: Node information tracking and comprehensive result monitoring  
- **🛠️ Simple**: Bash-based workers, shell2http server, minimal dependencies
- **🔄 Complete**: Job submission → execution → result retrieval workflow
- **⚡ Lightweight**: No heavy runtimes, just standard tools

## 🚀 Quick Start

### 1. Server Setup
```bash
git clone https://github.com/itefixnet/opsbay-cron-broker.git
cd opsbay-cron-broker/server
cp config.example.env .env
vim .env  # Set SECRET and ALLOWED_NODES
./run.sh
```

### 2. Worker Setup
```bash
# On each worker node
API="http://server:8080" NODE_ID="worker1" SECRET="your-secret" ./workers/worker.sh
```

### 3. Submit Jobs
```bash
# Submit a job
./post.sh --secret "your-secret" --url "http://server:8080" \
  --target "worker1" --command "echo hello" --timeout 30

# Submit and wait for completion  
./post.sh --secret "your-secret" --url "http://server:8080" \
  --target "worker1" --command "backup-db" --timeout 300 --wait

# Check results
./post.sh --secret "your-secret" --url "http://server:8080" --list-results
```

## 📚 Documentation

- **[PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md)** - Complete project guide with architecture, examples, and integration patterns
- **[server/README.md](server/README.md)** - Server setup, authentication, and API reference
- **[workers/README.md](workers/README.md)** - Worker configuration and deployment  
- **[RESULT_DELIVERY.md](RESULT_DELIVERY.md)** - Result retrieval and monitoring system
- **[NODE_INFO.md](NODE_INFO.md)** - Node information tracking details
- **[Docker.md](Docker.md)** - Container deployment instructions

## 🎯 Use Cases

- **Infrastructure Management**: Deploy configs, run maintenance, collect logs
- **DevOps & CI/CD**: Application deployment, database migrations, test execution  
- **Data Processing**: ETL pipelines, report generation, batch jobs
- **OpsBay Integration**: Designed for [OpsBay](https://opsbay.com) and [Cronicle](https://cronicle.org)

## 🔗 API Endpoints

- `POST /queue` — Submit jobs for execution
- `GET /fetch?node=<node>` — Workers fetch jobs
- `POST /result` — Workers submit results
- `GET /get-result?node=<node>&id=<id>` — Retrieve specific results
- `GET /list-results` — List all available results

*All endpoints use HMAC SHA-256 authentication*

## 📄 License

BSD 2-Clause — see [LICENSE](LICENSE).