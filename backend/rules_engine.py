import os
import time
import uuid
from typing import Any, Dict, List, Optional
from datetime import datetime, timezone


class Rule:
    """
    最小规则模型：基于单一指标与阈值的连续触发与冷却期。

    字段：
    - name: 规则名
    - metric: 指标键（cpu/mem/disk/net_recv/net_sent）
    - threshold: 数值阈值（百分比或 Mbps）
    - comparator: 比较符（默认 '>'，支持 '<'）
    - severity: 'warning' | 'critical'
    - consecutive: 连续满足 N 次才触发（抖动抑制）
    - cooldown_sec: 冷却期（触发后在该时长内不重复触发）
    """

    def __init__(
        self,
        name: str,
        metric: str,
        threshold: float,
        comparator: str = ">",
        severity: str = "warning",
        consecutive: int = 3,
        cooldown_sec: float = 10.0,
    ) -> None:
        self.name = name
        self.metric = metric
        self.threshold = float(threshold)
        self.comparator = comparator
        self.severity = severity
        self.consecutive = max(1, int(consecutive))
        self.cooldown_sec = float(cooldown_sec)

        # 运行态
        self._streak = 0
        self._last_trigger_at = 0.0

    def check(self, value: Optional[float]) -> Optional[Dict[str, Any]]:
        """
        返回触发上下文或 None。
        连续 N 次满足条件且过冷却期则触发。
        """
        now = time.time()
        if value is None:
            self._streak = 0
            return None

        condition = (value > self.threshold) if self.comparator == ">" else (value < self.threshold)

        if condition:
            self._streak += 1
        else:
            self._streak = 0

        if self._streak >= self.consecutive:
            if (now - self._last_trigger_at) >= self.cooldown_sec:
                self._last_trigger_at = now
                # 重置 streak，以便下一轮再次累计
                self._streak = 0
                return {
                    "name": self.name,
                    "metric": self.metric,
                    "threshold": self.threshold,
                    "severity": self.severity,
                    "value": float(value),
                    "comparator": self.comparator,
                    "consecutive": self.consecutive,
                }

        return None


class RulesEngine:
    """
    规则引擎：加载配置 -> 逐规则评估 -> 生成符合事件契约(v1)的事件。
    - 默认兼容旧配置：若无 rules，则根据 thresholds 生成默认规则（warning）。
    - 发布接口可注入到后端的事件总线（例如 deque、SSE）。
    """

    def __init__(self, config: Dict[str, Any], publish_fn) -> None:
        self.config = config or {}
        self.publish_fn = publish_fn
        self.rules: List[Rule] = []
        self._host = os.uname().nodename if hasattr(os, "uname") else "unknown"
        self._pid = os.getpid()
        self._load_rules()

    def _load_rules(self) -> None:
        self.rules.clear()

        # 1) 新版配置（推荐）：config["rules"] 为数组
        for r in (self.config.get("rules") or []):
            try:
                self.rules.append(
                    Rule(
                        name=r.get("name") or f"{r.get('metric','unknown')}_rule",
                        metric=r.get("metric") or "cpu",
                        threshold=float(r.get("threshold")),
                        comparator=r.get("comparator") or ">",
                        severity=r.get("severity") or "warning",
                        consecutive=int(r.get("consecutive", 3)),
                        cooldown_sec=float(r.get("cooldown_sec", self.config.get("cooldown_sec", 10.0))),
                    )
                )
            except Exception:
                continue

        # 2) 旧版兼容：仅 thresholds（数值）时，自动生成默认规则
        if not self.rules:
            thresholds = self.config.get("thresholds") or {}
            for metric, th in thresholds.items():
                try:
                    self.rules.append(
                        Rule(
                            name=f"{metric}_high",
                            metric=metric,
                            threshold=float(th),
                            comparator=">",
                            severity="warning",
                            consecutive=int(self.config.get("consecutive", 3)),
                            cooldown_sec=float(self.config.get("cooldown_sec", 10.0)),
                        )
                    )
                except Exception:
                    continue

    def to_dict(self) -> Dict[str, Any]:
        return {
            "rules": [
                {
                    "name": r.name,
                    "metric": r.metric,
                    "threshold": r.threshold,
                    "comparator": r.comparator,
                    "severity": r.severity,
                    "consecutive": r.consecutive,
                    "cooldown_sec": r.cooldown_sec,
                }
                for r in self.rules
            ]
        }

    def evaluate(self, metrics: Dict[str, Optional[float]]) -> None:
        """
        遍历所有规则并发布触发事件（符合 v1 契约）。
        metrics 应包含：cpu, mem, disk, net_recv, net_sent。
        """
        for rule in self.rules:
            ctx = rule.check(metrics.get(rule.metric))
            if ctx is None:
                continue

            # 构造契约事件
            evt = {
                "id": str(uuid.uuid4()),
                "timestamp": datetime.now(timezone.utc).isoformat(timespec="milliseconds"),
                "level": "warning" if rule.severity == "warning" else "critical",
                "type": "metric_threshold",  # 系统监控阈值事件
                "message": f"{rule.metric} {rule.comparator} {rule.threshold}",
                "source": {
                    "service": "backend",
                    "host": self._host,
                    "pid": self._pid,
                },
                "metrics": {
                    "cpu": metrics.get("cpu"),
                    "mem": metrics.get("mem"),
                    "disk": metrics.get("disk"),
                    "net_recv": metrics.get("net_recv"),
                    "net_sent": metrics.get("net_sent"),
                },
                "rule": {
                    "name": rule.name,
                    "threshold": rule.threshold,
                    "severity": rule.severity,
                },
                "version": "v1",
            }

            try:
                self.publish_fn(evt)
            except Exception:
                # 发布失败不应阻塞采样器
                pass