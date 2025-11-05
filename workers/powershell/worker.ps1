Param(
  [string]$API = "http://SERVER:8080",
  [string]$NODE_ID = "node1",
  [string]$SECRET = "CHANGE_ME",
  [int]$PollInterval = 5
)

# Gather system information for headers
$NodeHostname = try { [System.Net.Dns]::GetHostName() } catch { "unknown" }
$NodeOS = try { (Get-CimInstance -ClassName Win32_OperatingSystem).Caption } catch { $env:OS }
$NodeArch = try { $env:PROCESSOR_ARCHITECTURE } catch { "unknown" }
$NodeKernel = try { (Get-CimInstance -ClassName Win32_OperatingSystem).Version } catch { "unknown" }
$NodeUptime = try { (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime.ToString("yyyy-MM-dd HH:mm:ss") } catch { "unknown" }

function HmacB64([string]$data) {
  $key = [Text.Encoding]::UTF8.GetBytes($SECRET)
  $bytes = [Text.Encoding]::UTF8.GetBytes($data)
  $h = New-Object System.Security.Cryptography.HMACSHA256($key)
  $hash = $h.ComputeHash($bytes)
  [Convert]::ToBase64String($hash)
}

while ($true) {
  $ts = [int][double]::Parse((Get-Date -UFormat %s))
  $sig = HmacB64("$ts$NODE_ID")

  $headers = @{ 
    "X-Time" = $ts
    "X-Auth" = $sig
    "X-Node-Hostname" = $NodeHostname
    "X-Node-OS" = $NodeOS
    "X-Node-Arch" = $NodeArch
    "X-Node-Kernel" = $NodeKernel
    "X-Node-Uptime" = $NodeUptime
  }

  $job = Invoke-RestMethod -Uri "$API/fetch?node=$NODE_ID" -Headers $headers -Method GET -ErrorAction SilentlyContinue

  if (-not $job) { Start-Sleep -Seconds $PollInterval; continue }

  $id = $job.id
  $cmd = $job.payload.command
  $timeout = $job.payload.timeout

  $output = ""
  $status = 0
  try {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell"
    $psi.Arguments = "-NoProfile -Command $cmd"
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    $p.Start() | Out-Null
    if ($timeout -gt 0) { $ok = $p.WaitForExit($timeout * 1000) } else { $p.WaitForExit() | Out-Null; $ok = $true }
    if (-not $ok) { $p.Kill(); $status = 124 } else { $status = $p.ExitCode }
    $output = ($p.StandardOutput.ReadToEnd() + $p.StandardError.ReadToEnd())
  } catch {
    $status = 1
    $output = $_.ToString()
  }

  $payload = [ordered]@{
    id = $id
    node = $NODE_ID
    status = $status
    output = $output
    finished = [int][double]::Parse((Get-Date -UFormat %s))
  } | ConvertTo-Json -Depth 5

  $ts = [int][double]::Parse((Get-Date -UFormat %s))
  $sig = HmacB64("$ts$payload")

  $body = @{
    __auth = @{ time = "$ts"; sig = "$sig" }
  } + (ConvertFrom-Json $payload) | ConvertTo-Json -Depth 6

  $headers = @{
    "Content-Type" = "application/json"
    "X-Node-Hostname" = $NodeHostname
    "X-Node-OS" = $NodeOS
    "X-Node-Arch" = $NodeArch
    "X-Node-Kernel" = $NodeKernel
    "X-Node-Uptime" = $NodeUptime
  }

  Invoke-RestMethod -Uri "$API/result" -Method POST -Headers $headers -Body $body -ErrorAction SilentlyContinue | Out-Null

  Start-Sleep -Seconds $PollInterval
}
