from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import psutil, asyncio, time, json, os, platform
from collections import deque
from datetime import datetime

app = FastAPI(title="Linux Monitor", version="0.2")
app.add_middleware(
    CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"]
)

# 简单历史窗口（最近100秒；采样为1s，等于100个点）
HIST = {"ts": deque(maxlen=100), "cpu": deque(maxlen=100),
        "mem": deque(maxlen=100), "disk": deque(maxlen=100),
        "net_recv": deque(maxlen=100), "net_sent": deque(maxlen=100)}

# 使用 /proc 统计网络字节，避免平台差异
_last_t = time.time()
_last_net = {"recv": 0, "sent": 0}

CONFIG = {"thresholds": {"cpu": 80, "mem": 80, "disk": 90, "net_recv": 100, "net_sent": 100}}
CONFIG_PATH = os.path.join(os.path.dirname(__file__), "config.json")

def read_net_bytes():
    # Linux 使用 /proc/net/dev；其他平台回退到 psutil
    if platform.system() == "Linux":
        recv = 0
        sent = 0
        try:
            with open("/proc/net/dev", "r") as f:
                lines = f.readlines()[2:]
            for ln in lines:
                parts = ln.split(":")
                if len(parts) != 2:
                    continue
                iface = parts[0].strip()
                if iface == "lo":
                    continue
                fields = parts[1].split()
                recv += int(fields[0])
                sent += int(fields[8])
        except Exception:
            pass
        return recv, sent
    else:
        try:
            ni = psutil.net_io_counters()
            return ni.bytes_recv, ni.bytes_sent
        except Exception:
            return 0, 0


def read_mem_percent():
    # Linux 优先从 /proc/meminfo 计算；其他平台使用 psutil
    if platform.system() == "Linux":
        try:
            mt = ma = None
            with open("/proc/meminfo", "r") as f:
                for line in f:
                    if line.startswith("MemTotal:"):
                        mt = int(line.split()[1])
                    elif line.startswith("MemAvailable:"):
                        ma = int(line.split()[1])
            if mt and ma:
                used = (mt - ma) / mt * 100.0
                return used
        except Exception:
            pass
    return psutil.virtual_memory().percent


async def sampler():
    global _last_t, _last_net
    # 初始化网络字节
    r0, s0 = read_net_bytes()
    _last_net = {"recv": r0, "sent": s0}
    while True:
        now = time.time()
        cpu = psutil.cpu_percent(interval=None)
        mem = read_mem_percent()
        disk = psutil.disk_usage("/").percent

        # 计算网络速率（Mbps）
        r1, s1 = read_net_bytes()
        dt = max(1e-6, now - _last_t)
        recv_mbps = (r1 - _last_net["recv"]) * 8 / dt / 1e6
        sent_mbps = (s1 - _last_net["sent"]) * 8 / dt / 1e6
        _last_net = {"recv": r1, "sent": s1}
        _last_t = now

        ts = datetime.now().strftime("%H:%M:%S")
        HIST["ts"].append(ts)
        HIST["cpu"].append(cpu)
        HIST["mem"].append(mem)
        HIST["disk"].append(disk)
        HIST["net_recv"].append(recv_mbps)
        HIST["net_sent"].append(sent_mbps)

        await asyncio.sleep(1)

@app.on_event("startup")
async def boot():
    # 加载配置文件
    try:
        if os.path.exists(CONFIG_PATH):
            with open(CONFIG_PATH, "r", encoding="utf-8") as f:
                CONFIG.update(json.load(f))
    except Exception:
        pass
    asyncio.create_task(sampler())

@app.get("/api/data")
def data():
    latest = {k: (HIST[k][-1] if HIST[k] else None) for k in HIST}
    return {"latest": latest, "history": {k: list(v) for k, v in HIST.items()}}



@app.get("/api/config")
def get_config():
    return CONFIG