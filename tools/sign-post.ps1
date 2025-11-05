<#
.SYNOPSIS
  Generate HMAC POST signatures for opsbay-cron-broker.

.DESCRIPTION
  Reads JSON from stdin, removes any existing __auth field,
  computes timestamp + HMAC signature, and outputs fully
  signed JSON ready for POST to /queue or /result.

.USAGE
  PS> Get-Content job.json | ./sign-post.ps1 -Secret "mysecret"

  Or using pipeline:
  PS> cat job.json | ./sign-post.ps1 -Secret $env:SECRET

  Or send directly with curl/Invoke-RestMethod:
  PS> cat job.json | ./sign-post.ps1 -Secret $env:SECRET |
        Invoke-RestMethod -Uri http://server:8080/queue -Method Post -ContentType "application/json"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Secret
)

# Read raw JSON from stdin
$raw = [Console]::In.ReadToEnd()

if ([string]::IsNullOrWhiteSpace($raw)) {
    Write-Error "No input JSON received on stdin."
    exit 1
}

# Remove any prior __auth block
try {
    $json = $raw | ConvertFrom-Json -Depth 50
} catch {
    Write-Error "Invalid JSON input."
    exit 1
}

$json | Add-Member -MemberType NoteProperty -Name "__auth" -Value $null -Force
$null = $json.PSObject.Properties.Remove("__auth")

# Convert back to minimal JSON
$cleanBody = $json | ConvertTo-Json -Depth 50 -Compress

# Timestamp (epoch seconds)
$ts = [int][double]::Parse((Get-Date -UFormat %s))

# Build message (timestamp + clean JSON)
$data = "$ts$cleanBody"

# Compute HMAC-SHA256 (Base64)
$keyBytes  = [Text.Encoding]::UTF8.GetBytes($Secret)
$dataBytes = [Text.Encoding]::UTF8.GetBytes($data)
$hmac      = New-Object System.Security.Cryptography.HMACSHA256($keyBytes)
$hashBytes = $hmac.ComputeHash($dataBytes)
$sig       = [Convert]::ToBase64String($hashBytes)

# Build signed JSON
$result = [ordered]@{}
$json.PSObject.Properties.Name | ForEach-Object {
    $result[$_] = $json.$_
}
$result["__auth"] = @{
    time = "$ts"
    sig  = $sig
}

# Output fully signed JSON
$result | ConvertTo-Json -Depth 50
