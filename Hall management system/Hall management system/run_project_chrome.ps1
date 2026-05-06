$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Start-Process powershell -ArgumentList @(
  "-ExecutionPolicy Bypass -File `"$($projectRoot)\start_backend.ps1`""
)

Start-Sleep -Seconds 5

& "$projectRoot\start_frontend.ps1"
