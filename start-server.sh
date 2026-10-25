#!/bin/sh
# OC Ferry Server — headless OpenAI-compatible endpoint for NewAPI.
#   ./start-server.sh            前台运行
#   nohup ./start-server.sh &    后台运行
set -eu
cd "$(dirname "$0")"

if ! command -v node >/dev/null 2>&1; then
  echo "[OC Ferry Server] Node.js not found. Install Node.js 20+ first." >&2
  exit 1
fi

NODE_MAJOR=$(node -p 'process.versions.node.split(".")[0]')
if [ "$NODE_MAJOR" -lt 20 ]; then
  echo "[OC Ferry Server] Node.js 20+ required, found $(node -v)." >&2
  exit 1
fi

export FERRY_DATA_DIR="${FERRY_DATA_DIR:-$(pwd)/data}"
export FERRY_HOST="${FERRY_HOST:-0.0.0.0}"
export FERRY_PORT="${FERRY_PORT:-41980}"
export FERRY_NO_SYNC=1
export FERRY_MODEL_ID=slug
export FERRY_SKIP_PROBE="${FERRY_SKIP_PROBE:-1}"
export FERRY_MAX_CONCURRENCY="${FERRY_MAX_CONCURRENCY:-2}"
export FERRY_RECYCLE_REQUESTS="${FERRY_RECYCLE_REQUESTS:-50}"
# 密钥留空则由服务自己生成，写在 data/api-key
export FERRY_API_KEY="${FERRY_API_KEY:-}"
export NODE_OPTIONS="${NODE_OPTIONS:---max-old-space-size=128}"

mkdir -p "$FERRY_DATA_DIR"

# 本机回环请求不能被残留的代理变量劫持
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy ALL_PROXY all_proxy 2>/dev/null || true

echo "[OC Ferry Server] data  : $FERRY_DATA_DIR"
echo "[OC Ferry Server] listen: http://$FERRY_HOST:$FERRY_PORT/v1"
if [ -n "$FERRY_API_KEY" ]; then
  echo "[OC Ferry Server] key   : from environment"
else
  echo "[OC Ferry Server] key   : auto-generated, see $FERRY_DATA_DIR/api-key after start"
fi

exec node src/main.js
