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
根目录提供增强的 Makefile（支持端口自定义与快捷操作）：
```bash
# 初始化
make venv                     # 创建后端虚拟环境 backend/venv
make install                  # 安装后端依赖

# 启停与状态
make start                    # 后端 + 前端 后台启动（日志写入 .run/）
make status                   # 查看后台进程状态
make stop                     # 停止后端与前端
make restart                  # 重启
make up                       # 安装 + 启动（首次推荐）
make down                     # 停止（别名）

# 日志与健康
make logs                     # 查看两端最新 50 行日志
make logs-backend             # 查看后端 100 行日志
make logs-frontend            # 查看前端 100 行日志
make health                   # 调用 /api/health 查看后端健康
make urls                     # 输出前后端访问地址

# 清理
make clean                    # 清理 .run/、__pycache__、*.pyc
```

支持环境变量：
```bash
BACKEND_HOST=127.0.0.1 BACKEND_PORT=8000 FRONTEND_PORT=8080 make start
```
默认端口：后端 `8000`、前端 `8080`。运行产物与日志位于 `.run/`（已加入 `.gitignore`）。

## 验证
- 前端页面显示 CPU、内存、磁盘、网络 4 张实时曲线（每秒更新）。
- `http://127.0.0.1:8000/api/data` 返回实时采样数据（含网络 Mbps）。
- `/api/config` 返回阈值配置；前端卡片按阈值着色。
- 进程 Top-N 页面（滚动表格，按激活刷新）。
- 图表支持精确 tooltip（两位小数）、时间轴、点高亮；网络图展示收/发两条曲线（Mbps）。

## 常见问题
- 跨域：直接用 `file://` 打开 HTML 可能被策略拦截，建议启用本地静态服务。
- 端口占用：若 `8000` 被占用，可改 `--port 9000`，并同步调整前端的后端地址。

## 任务进度（基于目标汇总）
1) 搭建开发与运行环境
- 状态：部分完成。
- 已完成：Ubuntu/Python3 环境、FastAPI 后端与 Chart.js 前端可运行；Git 仓库与远端已配置；提供虚拟环境与依赖安装指引，基础 Makefile/脚本（start/stop/clean）。
- 未完成：`gcc/iptables/tc` 的工具链配置（非本项目核心，后续按需补充）。

2) 系统指标采集器（Collector）
- 状态：部分完成。
- 已完成：基于 psutil 的主机级 CPU/内存/磁盘/网络采集；1s 周期采样与数据缓存；`/api/data` 提供实时数据。
- 部分完成：进程级 Top-N（`/api/top` 即时采样，前端页面已接入）；持续采样与更细粒度指标待完善。

3) 规则引擎（Alerting Engine）
- 状态：已实现最小版本。
- 已完成：加载 `config.rules` 或根据 `config.thresholds` 自动生成规则；支持比较符（`>`/`<`）、级别（warning/critical）、连续触发与冷却期；触发时生成契约事件（`version: v1`）。
- 接口：`/api/rules` 返回当前规则；`/api/events` 最近事件；`/api/events/stream` SSE 实时事件。

4) 接口与可视化
- 状态：已增强。
- 已完成：`/api/data`（实时与历史）、`/api/config`、`/api/top`、`/api/metrics`、`/api/events`（最近事件）、`/api/health`（健康）、`/api/rules`（规则），以及事件流 SSE。
- 前端页面：
  - 系统概览：曲线、阈值卡片、侧栏健康状态、事件摘要与导出 CSV
  - 进程 Top-N：滚动表格，按 CPU 排序
  - 规则：当前规则表格展示
  - 事件流：SSE 实时事件、筛选（级别/类型/关键字）、暂停/继续

5) 制定性能与可靠性评估方案
- 状态：未实现。
- 规划：采样开销与后端 CPU/内存占用评估；高负载下的响应稳定性；前端刷新频率与资源占用；接口错误与降级策略。