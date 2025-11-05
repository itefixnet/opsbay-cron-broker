# sign-post.md — POST Signature Helper (HMAC)

This document explains how to use the **signature helpers** (`sign-post.sh` and `sign-post.ps1`) to generate valid **HMAC authentication signatures** for POST requests to the Opsbay Cron Broker.

It covers:

- ✅ Why signing is required  
- ✅ How the signature is computed  
- ✅ How to use the Bash signer  
- ✅ How to use the PowerShell signer  
- ✅ Example inputs & outputs  
- ✅ How to send signed jobs directly to the broker  

---

# 🔐 Why signing is required

All POST endpoints (`/queue` and `/result`) require HMAC signatures for security:

```
sig = base64( HMAC_SHA256( SECRET , timestamp + body_without___auth ) )
```

This prevents:

✅ spoofed job submissions  
✅ replay attacks (with timestamp checking)  
✅ unauthorized nodes from submitting results  

Every signed JSON must include:

```json
"__auth": {
  "time": "<epoch_seconds>",
  "sig": "<base64_hmac>"
}
```

The signature helpers generate this block automatically.

---

# 🧰 1. Bash: sign-post.sh

### Usage

```bash
export SECRET="mysecret"
cat job.json | ./tools/sign-post.sh
```

### Or produce a signed file

```bash
cat job.json | SECRET=mysecret ./tools/sign-post.sh > signed.json
```

### Or send directly to the API

```bash
cat job.json   | SECRET=mysecret ./tools/sign-post.sh   | curl -X POST http://server:8080/queue       -H "Content-Type: application/json"       -d @-
```

---

# 🪟 2. PowerShell: sign-post.ps1

Works on:

- ✅ Windows PowerShell 5.1  
- ✅ PowerShell 7 (Core)  
- ✅ macOS/Linux PowerShell  

### Usage

```powershell
Get-Content job.json | .\tools\sign-post.ps1 -Secret "mysecret"
```

### Using an environment variable

```powershell
$Env:SECRET = "mysecret"
cat job.json | ./tools/sign-post.ps1 -Secret $Env:SECRET
```

### POST directly to the broker

```powershell
cat job.json |
  ./tools/sign-post.ps1 -Secret "mysecret" |
  Invoke-RestMethod -Uri http://server:8080/queue `
                    -Method POST `
                    -ContentType "application/json"
```

---

# 📄 3. Example Input

**job.json**

```json
{
  "target": "node1",
  "command": "hostname",
  "timeout": 20
}
```

---

# 📤 4. Example Signed Output

```json
{
  "target": "node1",
  "command": "hostname",
  "timeout": 20,
  "__auth": {
    "time": "1730849123",
    "sig": "5mA7pJj7vE4D9PqkUbRT9K8qQb2i..."
  }
}
```

This JSON is fully authenticated and can be POSTed to `/queue`.

---

# ✅ Summary

| Task | Bash | PowerShell |
|------|------|------------|
| Sign JSON | ✅ | ✅ |
| Remove old `__auth` | ✅ | ✅ |
| Compute timestamp | ✅ | ✅ |
| Compute HMAC-SHA256 (Base64) | ✅ | ✅ |
| Output full signed JSON | ✅ | ✅ |

Use these helpers anywhere you need to prepare authenticated job submissions — from scripts, CI/CD pipelines, Windows automation, or Cronicle pre-webhook wrappers.