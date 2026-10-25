@echo off
rem Stop OC Ferry Server (kills the node process holding port 41980).
setlocal enabledelayedexpansion
for /f "tokens=5" %%p in ('netstat -ano ^| findstr ":41980" ^| findstr "LISTENING"') do (
  echo Killing PID %%p
  taskkill /PID %%p /F >nul 2>&1
)
echo Done.
