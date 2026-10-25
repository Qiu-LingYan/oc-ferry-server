# OC Ferry Server

把 OpenCode 的免费模型包装成一个 **OpenAI 兼容接口**，专供 NewAPI / LobeChat / 各类 OpenAI 客户端接渠道。无界面、无 Electron、单 Node 进程，Windows / Linux / macOS 通用。

```
NewAPI  ──HTTP──▶  OC Ferry Server (Node, 128MB 堆上限)  ──▶  opencode serve (本地随机端口)
                    :41980 /v1/chat/completions                    └─▶ opencode.ai 免费层
```

**本服务默认监听 `0.0.0.0:41980`，即对本机之外（局域网 / 服务器公网）暴露端口，供 NewAPI 作为上游渠道接入。** 两个对外接口：

| 路径 | 鉴权 | 用途 |
|---|---|---|
| `/v1/chat/completions`、`/v1/models` | 需要 `Bearer <FERRY_API_KEY>` | NewAPI 渠道实际调用 |
| `/health` | 免密钥 | 探活，返回 `status` 与模型数 |

> 只想本机用就把 `FERRY_HOST=127.0.0.1`。要对外就保持 `0.0.0.0`，并记得放行防火墙（见下方「端口与暴露」）。

> **本项目来源**
> 原项目：**[HRuiCcc/RuiC-oc-ferry](https://github.com/HRuiCcc/RuiC-oc-ferry)**（MIT，Electron 桌面版，仅发布 macOS 包）
> 本仓库是它的**无界面服务器版**，由 **[Qiu-LingYan](https://github.com/Qiu-LingYan)** 改编：去掉 Electron 外壳与 WorkBuddy 联动，改为纯 Node 服务、三平台运行、固定密钥、并发排队与引擎内存回收，方便做 NewAPI 的上游渠道。
> 遵循 MIT 协议，原作者版权声明保留在 [LICENSE](./LICENSE) 中。

## 相对原版的改动

| 项 | 原版（Electron） | 本版（Server） |
|---|---|---|
| 形态 | 桌面 GUI + 托盘 | 纯 HTTP 服务，无界面 |
| 平台 | 仅发布 macOS 包 | Windows / Linux / macOS 均可跑 |
| 磁盘 | 约 630 MB | 约 223 MB（代码 181 KB + 依赖 5.6 MB + 引擎 202 MB） |
| 监听 | `127.0.0.1` | `0.0.0.0:41980`，可对外 |
| 模型 ID | `OC · 名字` | `FERRY_MODEL_ID=slug` → `glm-5.3-flash-free` 这类小写短名 |
| 密钥 | 每次随机生成 | `FERRY_API_KEY` 固定，NewAPI 渠道填同一个 |
| 并发 | 超过 4 个直接 429 | 超出上限排队等待，等不到空位才 429 |
| 内存 | 不回收 | 累计 N 次请求后空闲时重启引擎，把内存压回去 |
| 探活 | 需密钥 | `GET /health` 免密钥 |
| 本机联动 | 读写 WorkBuddy `models.json` | `FERRY_NO_SYNC=1` 彻底跳过 |

## 资源占用（实测）

| 部分 | 常驻内存 | 说明 |
|---|---|---|
| Node 代理进程 | **约 56 MB** | 只做 JSON 转发与协议适配，堆上限 128 MB |
| opencode 引擎 | 约 270 MB → 请求后 380 MB | 免费模型的唯一入口，无法替代 |
| 磁盘 | 代码 181 KB + 依赖 5.6 MB + 引擎 202 MB | — |

> 为什么不能更轻：直接调 `opencode.ai/inference/openai/v1` 会被判 `403 FreeTierError — free tier can only be used from within OpenCode`，必须由 OpenCode 运行时发起。能省的是外壳（Electron、GUI、WorkBuddy 联动），省不掉引擎。

## 快速开始

### 方式一：Release 包（推荐，无需 npm install）

1. 到 [Releases](../../releases) 下载 `oc-ferry-server-<版本>-windows-x64.zip` 或 `oc-ferry-server-<版本>-linux-x64.tar.gz`
2. 解压到任意目录
3. 启动：
   - **Windows**：双击 `start-server.cmd`
   - **Linux / macOS**：`./start-server.sh`
4. 看到 `OC Ferry ready at …` 即成功，监听 `0.0.0.0:41980`
5. 首次启动会下载当前平台的 opencode 引擎（约 200 MB，从 npm 源拉取，耐心等一次）

停止：Windows 双击 `stop-server.cmd`；Linux `./stop-server.sh`。

### 方式二：源码运行

```bash
git clone https://github.com/Qiu-LingYan/oc-ferry-server.git
cd oc-ferry-server
npm install --omit=dev          # 只有 tar + undici 两个依赖

cp config.cmd.example config.cmd    # Windows：改成自己的密钥
export FERRY_API_KEY=sk-ocferry-xxx # Linux：环境变量即可

./start-server.sh                # Windows 用 start-server.cmd
```

### 方式三：Docker

```bash
cp .env.example .env && vi .env   # 填 FERRY_API_KEY
docker compose up -d --build
docker compose logs -f
```

镜像基于 `node:22-slim`（glibc），`data/` 挂卷持久化，内存硬上限 768 MB——超了直接 OOM 重启，不会把宿主机拖死。

### 方式四：systemd（Linux 常驻）

```bash
sudo cp deploy/oc-ferry.service /etc/systemd/system/
sudo vi /etc/systemd/system/oc-ferry.service   # 改 WorkingDirectory / User / FERRY_API_KEY
sudo systemctl enable --now oc-ferry
sudo journalctl -u oc-ferry -f
```

## 端口与暴露（NewAPI 怎么连进来）

服务只开 **一个 TCP 端口 `41980`**，`FERRY_HOST=0.0.0.0` 时对本机以外的地址开放。NewAPI 通过它接渠道：

```
NewAPI (任意机器)  ──HTTP:41980──▶  OC Ferry Server
```

**同机部署**：Base URL 填 `http://127.0.0.1:41980`
**同局域网**：填 `http://<运行本服务的机器内网IP>:41980`（如 `http://192.168.1.20:41980`）
**跨公网 / 云服务器**：填 `http://<公网IP>:41980`，或经反代 `https://ocf.example.com`

放行防火墙：

```bash
# Linux (ufw)
sudo ufw allow 41980/tcp
# Linux (firewalld)
sudo firewall-cmd --add-port=41980/tcp --permanent && sudo firewall-cmd --reload
```

```powershell
# Windows（管理员 PowerShell）
New-NetFirewallRule -DisplayName "OC Ferry 41980" -Direction Inbound -Protocol TCP -LocalPort 41980 -Action Allow
```

云服务器还要在**安全组**里放行 41980/TCP。

> **安全提醒**：接口本身没有 TLS、没有限流。暴露到公网时，建议用 Nginx / Caddy 反代加 HTTPS，只让反代访问 41980，并设置足够长的 `FERRY_API_KEY`。不要把裸端口直接甩到公网上。

## NewAPI 接渠道

**渠道 → 新建渠道**

| 字段 | 值 |
|---|---|
| 类型 | OpenAI |
| 名称 | OC Ferry 免费模型 |
| 代理地址 / Base URL | `http://<这台机器的IP>:41980` |
| 密钥 | 你的 `FERRY_API_KEY`；留空启动的话看 `data/api-key` |
| 模型 | 点「获取模型列表」自动拉，或手填下面清单 |

> 若该 NewAPI 版本不会自动补 `/v1`，地址填 `http://<IP>:41980/v1`。
> 容器部署且 NewAPI 在同一个 compose 网络里，用 `http://oc-ferry:41980`。

**当前免费模型（`FERRY_MODEL_ID=slug`）**

```
big-pickle
deepseek-v4.1-flash-free
glm-5.3-flash-free
mimo-v2.6-flash-free
nemotron-3-ultra-free
nemotron-3.5-lightning-free
nemotron-3.5-super-vl-free
```

`GET /v1/models` 返回的就是最终清单，以它为准。上游模型上下架随时可能变化，`POST /admin/probe`（带 Bearer 密钥）可重新检测。

**探活**：`GET /health` 免密钥，返回 `{"status":"ok","models":7,...}`，NewAPI 渠道测试与容器 healthcheck 都可用它。

## 环境变量

| 变量 | 默认 | 作用 |
|---|---|---|
| `FERRY_HOST` | `127.0.0.1` | 改成 `0.0.0.0` 才对外暴露 |
| `FERRY_PORT` | `41980` | 监听端口 |
| `FERRY_API_KEY` | 随机（写在 `data/api-key`） | 固定密钥，NewAPI 填这个 |
| `FERRY_NO_SYNC` | — | 设 `1` 关闭 WorkBuddy 配置读写（服务器必开） |
| `FERRY_MODEL_ID` | `OC · 名字` | 设 `slug` → 小写短名，便于渠道配置 |
| `FERRY_SKIP_PROBE` | — | 设 `1` 启动只读判定缓存，不额外探测（省内存、省额度）；设 `0` 全量探测 |
| `FERRY_MAX_CONCURRENCY` | `4` | 同时在跑的请求数上限，超出排队 |
| `FERRY_QUEUE_WAIT_MS` | `60000` | 排队等待上限，等满仍无空位才返回 429 |
| `FERRY_RECYCLE_REQUESTS` | `0`（不回收） | 累计 N 次请求后空闲时重启引擎回收内存，脚本默认 **50** |
| `FERRY_DATA_DIR` | 脚本内 `./data` | 引擎、缓存、日志存放位置 |
| `NODE_OPTIONS` | `--max-old-space-size=128` | Node 堆上限 |

## 已知限制（务必看）

- **实测范围**：Windows 11 + Node 22 上完整验证过（启动、鉴权、对话、流式、工具调用、并发排队、引擎回收）。Linux / macOS 走同一套 Node 代码，引擎与路径由 `src/platform.js` 按平台自适应下载，逻辑等价但**未在实机跑过**；有条件的话先 `npm run smoke` 确认。
- **免费层是限时免费的**。官方定价页只写「free on OpenCode for a limited time、按 $0 计价」，**没有公布每日次数**；实测的限制是隐性的：短时间密集调用后，全部免费模型会集体「挂住」（不返回、不报错），过一阵才恢复。**当备用渠道用，别当生产主力**；并发压到 1–2。
- **单次回答通常 5–10 秒**起（OpenCode 会话逐步执行），NewAPI 渠道超时请设 **120 秒以上**。
- **判定缓存是命门**。`data/probe-cache.json` 里没有的模型不会出现在清单里。换机器时把该文件一起带走，或调 `POST /admin/probe` 补检测。
- **代理变量必须清空**。`HTTP_PROXY` 指向不存在的代理会让所有本机回环请求失败（`10061`），启动脚本已自动 `unset`。
- **引擎内存随请求增长**（~270MB → ~380MB）。累计 50 次请求后空闲时重启引擎，重启约 5 秒，期间请求会排队；设 `0` 可关闭。
- **不要把这套东西直接暴露到公网**。它本身没有 TLS、没有限流，务必套 Nginx / Caddy 反代，并保持强密钥。
- 日志在 `data/opencode.log`，超过 5 MB 自动轮转。

## 目录结构

```
oc-ferry-server/
├─ src/                     # 代理代码（19 个文件，181 KB）
├─ data/                    # 引擎、缓存、状态、日志（gitignore，可迁移）
├─ deploy/oc-ferry.service  # systemd 单元示例
├─ start-server.cmd / .sh   # 启动（Windows / Linux）
├─ stop-server.cmd / .sh    # 停止
├─ config.cmd.example       # Windows 本地配置模板（复制成 config.cmd）
├─ .env.example             # Docker / Linux 密钥模板
├─ Dockerfile / docker-compose.yml
├─ smoke.mjs                # 冒烟测试：普通对话 + 流式 + 工具调用
└─ test-queue.mjs           # 并发排队逻辑回归
```

## 许可

MIT。原项目版权归 [HRuiCcc](https://github.com/HRuiCcc) 所有，服务器版改动归 [Qiu-LingYan](https://github.com/Qiu-LingYan)。详见 [LICENSE](./LICENSE)。

本项目与 OpenCode / NewAPI 官方无隶属关系，仅做协议适配。请遵守上游服务条款。
