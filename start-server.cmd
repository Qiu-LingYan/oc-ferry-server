@echo off
setlocal
cd /d "%~dp0"

rem ============================================================
rem  OC Ferry Server - headless, OpenAI-compatible endpoint
rem  Exposes the OpenCode free models for NewAPI.
rem  Keep this file pure ASCII with CRLF line endings.
rem ============================================================

set "FERRY_DATA_DIR=%~dp0data"
set "FERRY_HOST=0.0.0.0"
set "FERRY_PORT=41980"
set "FERRY_NO_SYNC=1"
set "FERRY_MODEL_ID=slug"
set "FERRY_SKIP_PROBE=1"
set "FERRY_MAX_CONCURRENCY=2"
rem Idle engine recycle: restart opencode after N requests (0 = never).
set "FERRY_RECYCLE_REQUESTS=50"
rem Shared secret comes from config.cmd (gitignored). Empty = auto-generate.
set "FERRY_API_KEY="

rem Local overrides, never committed.
if exist "%~dp0config.cmd" call "%~dp0config.cmd"

rem Node heap cap: this proxy only shuffles JSON, 128 MB is plenty.
if not defined NODE_OPTIONS set "NODE_OPTIONS=--max-old-space-size=128"

rem Dead proxy settings break loopback calls - clear them all.
set "HTTP_PROXY="
set "HTTPS_PROXY="
set "http_proxy="
set "https_proxy="
set "ALL_PROXY="
set "all_proxy="

echo [OC Ferry Server] data  : %FERRY_DATA_DIR%
echo [OC Ferry Server] listen: http://%FERRY_HOST%:%FERRY_PORT%/v1
if defined FERRY_API_KEY (
  echo [OC Ferry Server] key   : from config.cmd / environment
) else (
  echo [OC Ferry Server] key   : auto-generated, see data\api-key after start
)
echo.

node src\main.js
if errorlevel 1 (
  echo.
  echo [OC Ferry Server] exited with error. Is Node.js 20+ installed?
  pause
)
