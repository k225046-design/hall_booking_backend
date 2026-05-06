$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$venvPath = Join-Path $projectRoot ".runtime_venv"
$pythonExe = Join-Path $venvPath "Scripts\python.exe"
$pipExe = Join-Path $venvPath "Scripts\pip.exe"

if (-not (Test-Path $pythonExe)) {
  py -3.13 -m venv $venvPath
}

& $pythonExe -m pip install --upgrade pip
& $pipExe install -r (Join-Path $projectRoot "requirements.txt")
& $pythonExe (Join-Path $projectRoot "backendcode.py")
