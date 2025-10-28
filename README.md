# Linux Monitor Platform

本项目提供一个最小可用的“系统监控 + 可视化”示例：
- 后端：FastAPI + psutil 采样，并提供 `/api/data` 接口
- 前端：纯静态 HTML + Chart.js 仪表盘

## 目录结构

```
linux-monitor-platform/
├─ backend/          # FastAPI + psutil 采集与接口
│  ├─ app.py
│  ├─ requirements.txt
│  └─ venv/          # 本地虚拟环境（已在 .gitignore）
├─ frontend/         # 前端仪表盘（纯静态 HTML/JS）
│  └─ index.html
├─ .gitignore
└─ README.md
```

## 启动后端

```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -U pip
pip install -r requirements.txt
uvicorn app:app --host 127.0.0.1 --port 8000 --reload
```

Windows PowerShell：
```powershell
cd backend
python -m venv venv
./venv/Scripts/Activate.ps1
pip install -U pip
pip install -r requirements.txt
uvicorn app:app --host 127.0.0.1 --port 8000 --reload
```

## 打开前端
- 直接双击 `frontend/index.html`（部分浏览器在 `file://` 下跨域受限）
- 推荐：在 `frontend/` 目录开启本地静态服务器
```bash
cd frontend
python -m http.server 8080
# 在浏览器访问 http://127.0.0.1:8080
```
如后端端口非 8000，请将 `index.html` 内的 `fetch("http://127.0.0.1:8000/api/data")` 对应调整。

## 验证
- 浏览器能看到 CPU、内存、磁盘、网络的 4 张实时曲线图
- `http://127.0.0.1:8000/api/data` 能返回 JSON

## 常见问题
- 跨域：`file://` 打开 HTML 可能被浏览器策略拦截，建议用本地静态服务器
- 端口占用：若 `8000` 被占用，可改 `--port 9000`，并同时更新前端 `fetch` 目标