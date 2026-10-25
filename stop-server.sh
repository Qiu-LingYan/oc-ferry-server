#!/bin/sh
# Stop OC Ferry Server on Linux / macOS (kills whatever listens on $FERRY_PORT, default 41980).
set -u
PORT="${FERRY_PORT:-41980}"

if command -v lsof >/dev/null 2>&1; then
  PIDS=$(lsof -ti tcp:"$PORT" 2>/dev/null || true)
elif command -v ss >/dev/null 2>&1; then
  PIDS=$(ss -lptn "sport = :$PORT" 2>/dev/null | sed -n 's/.*pid=\([0-9]*\).*/\1/p')
else
  PIDS=$(pgrep -f 'src/main.js' 2>/dev/null || true)
fi

if [ -z "${PIDS:-}" ]; then
  echo "No process listening on port $PORT."
  exit 0
fi

for pid in $PIDS; do
  echo "Killing PID $pid"
  kill "$pid" 2>/dev/null || true
done

sleep 2
for pid in $PIDS; do
  kill -9 "$pid" 2>/dev/null || true
done
echo "Done."
