@echo off
setlocal
cd /d "%~dp0"
where node >nul 2>nul
if errorlevel 1 (
  echo Install Node.js 22.12 or newer: https://nodejs.org/
  pause
  exit /b 1
)
node scripts\launch.mjs
if errorlevel 1 pause
