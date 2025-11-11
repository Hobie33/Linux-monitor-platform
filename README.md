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
在项目根目录提供 Makefile，常用目标：
```bash
make venv        # 创建后端虚拟环境
make install     # 安装后端依赖
make start       # 启动后端与前端（后台运行，日志写入 .run/）
make status      # 查看后台进程状态
make stop        # 停止后端与前端
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
- 状态：未实现。
- 规划：阈值比较、滑动窗口与“连续 N 次触发”抖动抑制；按用户/进程/正则选择器与白名单/冷却期。
- 现状：前端仅依据 `config.json` 的阈值进行基础徽章着色，不含后端规则引擎与事件生成。

4) 接口与可视化
- 状态：部分完成。
- 已完成：`/api/data`、`/api/config`、`/api/top`、`/api/metrics`、`/api/events`、`/api/health`（最小实现）；前端两页面：系统概览（曲线+卡片+tooltip）与进程 Top-N（滚动表格）。
- 未完成：事件流（SSE/WS）、路由高亮与状态灯（结合 `/api/health`）。

5) 制定性能与可靠性评估方案
- 状态：未实现。
- 规划：采样开销与后端 CPU/内存占用评估；高负载下的响应稳定性；前端刷新频率与资源占用；接口错误与降级策略。