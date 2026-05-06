$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$appRoot = Join-Path $repoRoot "Hall management system\hall_booking_app"

Push-Location $appRoot
try {
  & "C:\flutter\bin\flutter.bat" pub get
  & "C:\flutter\bin\flutter.bat" run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:5000
}
finally {
  Pop-Location
}
