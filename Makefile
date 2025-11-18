PY=python3
BACKEND_DIR=backend
FRONTEND_DIR=frontend
# 使用绝对路径，避免在子目录下写 ../.run 失败
RUN_DIR=$(CURDIR)/.run
BACKEND_HOST?=127.0.0.1
BACKEND_PORT?=8000
FRONTEND_PORT?=8080

.PHONY: venv install start stop clean status up down restart logs logs-backend logs-frontend health urls

venv:
	mkdir -p $(RUN_DIR)
	[ -d $(BACKEND_DIR)/venv ] || $(PY) -m venv $(BACKEND_DIR)/venv

install: venv
	$(BACKEND_DIR)/venv/bin/pip install -U pip
	$(BACKEND_DIR)/venv/bin/pip install -r $(BACKEND_DIR)/requirements.txt

start:
	mkdir -p $(RUN_DIR)
	( cd $(BACKEND_DIR) && nohup ./venv/bin/uvicorn app:app --host $(BACKEND_HOST) --port $(BACKEND_PORT) --reload > $(RUN_DIR)/backend.log 2>&1 & echo $$! > $(RUN_DIR)/backend.pid )
	( cd $(FRONTEND_DIR) && nohup $(PY) -m http.server $(FRONTEND_PORT) > $(RUN_DIR)/frontend.log 2>&1 & echo $$! > $(RUN_DIR)/frontend.pid )

stop:
	[ -f $(RUN_DIR)/backend.pid ] && kill -TERM `cat $(RUN_DIR)/backend.pid` || true
	[ -f $(RUN_DIR)/frontend.pid ] && kill -TERM `cat $(RUN_DIR)/frontend.pid` || true
	sleep 1
	[ -f $(RUN_DIR)/backend.pid ] && rm -f $(RUN_DIR)/backend.pid || true
	[ -f $(RUN_DIR)/frontend.pid ] && rm -f $(RUN_DIR)/frontend.pid || true

clean:
	rm -rf $(RUN_DIR)
	find . -name '__pycache__' -type d -exec rm -rf {} +
	find . -name '*.pyc' -type f -delete

status:
	@echo "Backend:"; [ -f $(RUN_DIR)/backend.pid ] && ps -p `cat $(RUN_DIR)/backend.pid` || echo "not running"
	@echo "Frontend:"; [ -f $(RUN_DIR)/frontend.pid ] && ps -p `cat $(RUN_DIR)/frontend.pid` || echo "not running"

up: install start

down: stop

restart: stop start

logs:
	@echo "== backend.log =="; [ -f $(RUN_DIR)/backend.log ] && tail -n 50 $(RUN_DIR)/backend.log || echo "no backend log"
	@echo "== frontend.log =="; [ -f $(RUN_DIR)/frontend.log ] && tail -n 50 $(RUN_DIR)/frontend.log || echo "no frontend log"

logs-backend:
	[ -f $(RUN_DIR)/backend.log ] && tail -n 100 $(RUN_DIR)/backend.log || echo "no backend log"

logs-frontend:
	[ -f $(RUN_DIR)/frontend.log ] && tail -n 100 $(RUN_DIR)/frontend.log || echo "no frontend log"

health:
	curl -s http://$(BACKEND_HOST):$(BACKEND_PORT)/api/health

urls:
	@echo Backend: http://$(BACKEND_HOST):$(BACKEND_PORT)
	@echo Frontend: http://127.0.0.1:$(FRONTEND_PORT)