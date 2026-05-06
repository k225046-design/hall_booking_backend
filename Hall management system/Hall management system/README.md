# Hall Management System

## Run In VS Code

Open the outer folder:

`C:\jassim\8th sem\Hall management system`

Then in VS Code:

1. Open **Run and Debug**
2. Choose **Flutter Chrome**
3. Press `F5`

This launches:

- Backend API: `http://127.0.0.1:5000`
- Flutter app in Chrome

## Run From Terminal

If your terminal is opened in:

`C:\jassim\8th sem\Hall management system`

then `flutter run -d chrome` will fail there because that folder does not contain the Flutter app's `pubspec.yaml`.

Use one of these commands from the outer folder instead:

- `.\run_chrome.bat`
- `powershell -ExecutionPolicy Bypass -File .\run_chrome.ps1`

## Flutter Project Root

The actual Flutter project is here:

`C:\jassim\8th sem\Hall management system\Hall management system\hall_booking_app`

That is why `pubspec.yaml` was not being found when VS Code was opened at the wrong level.

## Admin Login

- Email: `admin@admin.com`
- Password: `admin123`
