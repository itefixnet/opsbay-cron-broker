# Cronicle Webhook

Create a Web Hook action in Cronicle:

- Method: `POST`
- URL: `http://SERVER:8080/queue`
- Content-Type: `application/json`

Use this payload template:

```json
{
  "__auth": {
    "time": "${time_epoch}",
    "sig": "${hmac_b64_of(time||body_without_auth)}"
  },
  "target": "node1",
  "command": "echo hello from cronicle",
  "timeout": 20
}
```

**Signature rule for POST**:  
`sig = base64( HMAC_SHA256( SECRET,  timestamp + (json-without-__auth) ) )`
