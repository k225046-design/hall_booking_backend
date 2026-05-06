@echo off
setlocal

cd /d "%~dp0Hall management system\hall_booking_app"
call C:\flutter\bin\flutter.bat pub get
call C:\flutter\bin\flutter.bat run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:5000
