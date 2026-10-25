# OC Ferry Server —— 极简镜像：只有 Node + 代理代码，OpenCode 引擎首次启动时自动下载
# 用 slim（Debian / glibc）而不是 alpine：opencode 引擎是 glibc 二进制，musl 下跑不起来。
FROM node:22-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev --ignore-scripts && npm cache clean --force
COPY src ./src

# 运行时与状态都放这里，挂卷即可持久化（含 200MB 的 opencode 引擎）
ENV FERRY_DATA_DIR=/data \
    FERRY_HOST=0.0.0.0 \
    FERRY_PORT=41980 \
    FERRY_NO_SYNC=1 \
    FERRY_MODEL_ID=slug \
    FERRY_SKIP_PROBE=1 \
    FERRY_MAX_CONCURRENCY=2 \
    NODE_OPTIONS=--max-old-space-size=128

VOLUME ["/data"]
EXPOSE 41980

HEALTHCHECK --interval=30s --timeout=5s --start-period=120s --retries=3 \
  CMD curl -fsS http://127.0.0.1:41980/health >/dev/null || exit 1
CMD ["node", "src/main.js"]
