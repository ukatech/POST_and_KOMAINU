@echo off
rem Opens the log receiver window (see receiver.txt).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0receiver.ps1"
if errorlevel 1 pause
