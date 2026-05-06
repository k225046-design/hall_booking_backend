$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Start-Process powershell -ArgumentList @(
  "-NoExit",
  "-ExecutionPolicy",
  "Bypass",
  "-File",
  (Join-Path $projectRoot "start_backend.ps1")
)

Start-Sleep -Seconds 5

& (Join-Path $projectRoot "start_frontend.ps1")
