@echo off
setlocal

cd /d "%~dp0hall_booking_app"
call C:\flutter\bin\flutter.bat pub get
call C:\flutter\bin\flutter.bat run -d chrome
