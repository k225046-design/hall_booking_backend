$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$appRoot = Join-Path $projectRoot "hall_booking_app"

Push-Location $appRoot
try {
  & "C:\flutter\bin\flutter.bat" pub get
  & "C:\flutter\bin\flutter.bat" run -d chrome
}
finally {
  Pop-Location
}
