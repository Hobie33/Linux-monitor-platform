PY=python3
BACKEND_DIR=backend
FRONTEND_DIR=frontend
# 使用绝对路径，避免在子目录下写 ../.run 失败
RUN_DIR=$(CURDIR)/.run

.PHONY: venv install start stop clean status

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