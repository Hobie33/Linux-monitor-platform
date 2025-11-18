PY=python3
BACKEND_DIR=backend
FRONTEND_DIR=frontend
# 使用绝对路径，避免在子目录下写 ../.run 失败
RUN_DIR=$(CURDIR)/.run

.PHONY: venv install start stop clean status up down restart logs backend-log frontend-log urls health demo help

venv:
	mkdir -p $(RUN_DIR)
	[ -d $(BACKEND_DIR)/venv ] || $(PY) -m venv $(BACKEND_DIR)/venv

install: venv
	$(BACKEND_DIR)/venv/bin/pip install -U pip
	$(BACKEND_DIR)/venv/bin/pip install -r $(BACKEND_DIR)/requirements.txt

start:
	mkdir -p $(RUN_DIR)
	( cd $(BACKEND_DIR) && nohup ./venv/bin/uvicorn app:app --host 127.0.0.1 --port 8000 --reload > $(RUN_DIR)/backend.log 2>&1 & echo $$! > $(RUN_DIR)/backend.pid )
	( cd $(FRONTEND_DIR) && nohup $(PY) -m http.server 8080 > $(RUN_DIR)/frontend.log 2>&1 & echo $$! > $(RUN_DIR)/frontend.pid )

up: install start

down: stop

restart: stop start

stop:
	[ -f $(RUN_DIR)/backend.pid ] && kill -TERM `cat $(RUN_DIR)/backend.pid` || true
	[ -f $(RUN_DIR)/frontend.pid ] && kill -TERM `cat $(RUN_DIR)/frontend.pid` || true
	sleep 1
	[ -f $(RUN_DIR)/backend.pid ] && rm -f $(RUN_DIR)/backend.pid || true
	[ -f $(RUN_DIR)/frontend.pid ] && rm -f $(RUN_DIR)/frontend.pid || true
	# fallback: kill by command patterns
	pgrep -f "./venv/bin/uvicorn app:app --host 127.0.0.1 --port 8000" | xargs -r kill -TERM || true
	pgrep -f "python3 -m http.server 8080" | xargs -r kill -TERM || true
	# fallback: kill by ports (8000/8080)
	for PORT in 8000 8080; do \
		ss -lntp | awk -v p=":$${PORT}" 'index($0,p){if(match($0,/pid=([0-9]+)/,m))print m[1]}' | xargs -r kill -TERM; \
	done

clean:
	rm -rf $(RUN_DIR)
	find . -name '__pycache__' -type d -exec rm -rf {} +
	find . -name '*.pyc' -type f -delete

status:
	@echo "Backend:"; [ -f $(RUN_DIR)/backend.pid ] && ps -p `cat $(RUN_DIR)/backend.pid` || echo "not running"
	@echo "Frontend:"; [ -f $(RUN_DIR)/frontend.pid ] && ps -p `cat $(RUN_DIR)/frontend.pid` || echo "not running"
	@echo "Health:"; curl -s http://127.0.0.1:8000/api/health || echo "unreachable"
	@echo "Pgrep:"; pgrep -fa 'uvicorn|http.server' || true
	@echo "Ports:"; ss -lntp | awk 'NR==1 || /:(8000|8080)\b/' || true

urls:
	@echo "Backend: http://127.0.0.1:8000"
	@echo "Frontend: http://127.0.0.1:8080"

backend-log:
	@[ -f $(RUN_DIR)/backend.log ] && tail -n 100 $(RUN_DIR)/backend.log || echo "no backend.log"

frontend-log:
	@[ -f $(RUN_DIR)/frontend.log ] && tail -n 100 $(RUN_DIR)/frontend.log || echo "no frontend.log"

logs:
	@echo "== backend.log =="; [ -f $(RUN_DIR)/backend.log ] && tail -n 50 $(RUN_DIR)/backend.log || echo "no backend.log"
	@echo "== frontend.log =="; [ -f $(RUN_DIR)/frontend.log ] && tail -n 50 $(RUN_DIR)/frontend.log || echo "no frontend.log"

health:
	curl -s http://127.0.0.1:8000/api/health

demo:
	@echo "--- /api/health ---"; curl -s http://127.0.0.1:8000/api/health
	@echo "\n--- /api/rules ---"; curl -s http://127.0.0.1:8000/api/rules
	@echo "\n--- /api/data ---"; curl -s http://127.0.0.1:8000/api/data | head -c 500; echo "..."
	@echo "\n--- /api/metrics ---"; curl -s http://127.0.0.1:8000/api/metrics
	@echo "\n--- /api/top?count=5&by=cpu ---"; curl -s "http://127.0.0.1:8000/api/top?count=5&by=cpu"
	@echo "\n--- /api/events?limit=5 ---"; curl -s "http://127.0.0.1:8000/api/events?limit=5"

help:
	@echo "Targets: venv install start stop clean status up down restart urls logs backend-log frontend-log health demo"