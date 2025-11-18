# Linux-monitor-platform
轻量的 Linux 系统监控与可视化平台：后端使用 FastAPI + psutil 每秒采样，前端用 Chart.js 展示 CPU/内存/磁盘/网络的实时曲线与进程 Top-N。

## 项目结构
```
linux-monitor-platform/
├─ backend/          # FastAPI + psutil 采集与接口
│  ├─ app.py
│  ├─ requirements.txt
│  └─ venv/          # 本地虚拟环境（已在 .gitignore）
├─ frontend/         # 前端仪表盘（纯静态 HTML/JS）
│  └─ index.html
├─ .gitignore
└─ README.md (已合并到根 README，仅保留此文档)
```

## 快速开始
后端（Linux / macOS）：
```bash
cd linux-monitor-platform/backend
python3 -m venv venv
source venv/bin/activate
pip install -U pip
pip install -r requirements.txt
uvicorn app:app --host 127.0.0.1 --port 8000 --reload
```

前端（本地静态服务）：
```bash
cd linux-monitor-platform/frontend
python3 -m http.server 8080
# 浏览器访问 http://127.0.0.1:8080
```
如后端端口非 8000，请将 `frontend/index.html` 中的后端地址 `API_BASE` 调整为对应端口。

### 一键命令（Makefile）
在项目根目录提供 Makefile，一键运行与常用维护：
```bash
# 初始化并启动（创建虚拟环境、安装依赖、启动后端与前端）
make up

# 停止服务 / 重启
make down
make restart

# 安装与运行（单独使用）
make venv        # 创建后端虚拟环境
make install     # 安装后端依赖
make start       # 启动后端与前端（后台运行，日志写入 .run/）
make stop        # 停止后端与前端

# 诊断与信息
make status      # 查看后台进程与健康状态
make urls        # 显示访问地址（后端/前端）
make logs        # 查看最近日志（后端/前端）
make backend-log # 查看后端日志（最后 100 行）
make frontend-log# 查看前端日志（最后 100 行）
make health      # 打印后端健康接口
make demo        # 快速演示各 API 输出

# 清理
make clean       # 清理 .run/、__pycache__、*.pyc
```
运行产物与日志位于 `.run/`（已加入 `.gitignore`）。

## 验证
- 前端页面显示 CPU、内存、磁盘、网络 4 张实时曲线（每秒更新）。
- `http://127.0.0.1:8000/api/data` 返回实时采样数据（含网络 Mbps）。
- `/api/config` 返回阈值配置；前端卡片按阈值着色。
- 进程 Top-N 页面（滚动表格，按激活刷新）。
- 图表支持精确 tooltip（两位小数）、时间轴、点高亮；网络图展示收/发两条曲线（Mbps）。

## 常见问题
- 跨域：直接用 `file://` 打开 HTML 可能被策略拦截，建议启用本地静态服务。
- 端口占用：若 `8000` 被占用，可改 `--port 9000`，并同步调整前端的后端地址。

## 功能说明
- 后端 FastAPI 提供接口：
  - `GET /api/data` 最新与历史指标
  - `GET /api/top` 进程 Top-N
  - `GET /api/metrics` 统计窗口值
  - `GET /api/events` 最近事件列表
  - `GET /api/events/stream` SSE 实时事件流
  - `GET /api/config` 当前阈值/规则配置
  - `GET /api/rules` 规则列表
  - `GET /api/health` 健康状态
- 前端页面：
  - 概览：CPU/内存/磁盘/网络图表与阈值卡片
  - 进程：Top-N 表格
  - 规则：规则表格（徽章样式、阈值格式化）
  - 事件流：SSE 实时事件，支持级别/类型/关键字筛选与暂停流控

如后端端口非 8000，请在 `frontend/index.html` 调整常量 `API_BASE`。

### 正确停止与诊断
- 使用 `make down` 或 `make stop` 停止后端与前端（后台进程）
- 若端口仍被占用，可运行：
  - `make status` 查看进程与端口占用（含 8000/8080）
  - `pgrep -fa 'uvicorn|http.server'` 检查残留进程
  - `ss -lntp | awk 'NR==1 || /:(8000|8080)\b/'` 检查端口占用
- 前端页面在 `http://127.0.0.1:8080` 打开时，即使后端停止，也会继续显示历史曲线；但卡片与表格会停止更新，事件流显示“未连接”。