# Server (shell2http endpoints)

### Requirements
- `shell2http`, `jq`, `openssl`, `bash`
- Configure `.env` (copy from `config.example.env`)

### Start
```bash
./run.sh
```

### Auth model
- **Shared secret** (HMAC SHA-256, Base64)
- **Allowed node list** controls which `node` values can:
  - `GET /fetch?node=<node>` (signed with timestamp + node)
  - `POST /result` (body includes `node`, validated and enforced)
- `POST /queue` is HMAC-signed and may also enforce `target` ∈ allowed nodes.

### Signatures

#### POST (queue, result)
Body must include:

```json
"__auth": {
  "time": "<epoch_seconds>",
  "sig": "<base64 hmac of time + (json-without-__auth)>"
}
```

#### GET (fetch)
Headers:
```
X-Time: <epoch_seconds>
X-Auth: base64 hmac of (timestamp + node)
```

Query:
```
?node=<node>
```
