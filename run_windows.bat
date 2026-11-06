@echo off
cd /d "%~dp0"
flutter run -d windows
if errorlevel 1 pause
