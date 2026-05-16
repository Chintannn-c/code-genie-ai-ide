"""
Task Analyzer — Intelligent Intent Routing
============================================
Uses a fast model (Gemini Flash) to classify user intent
and dynamically select the optimal expert agents for the task.

Supports:
- coding, architecture, security, debugging, UI/UX, deployment,
  optimization, testing, and general queries.
"""

import re
import logging
import time
from typing import Dict, Any, List
from .agent_roles import AgentRole, get_agents_for_task

logger = logging.getLogger(__name__)


# ============================================================
# KEYWORD-BASED FAST CLASSIFIER (< 1ms, no model call)
# ============================================================
TASK_KEYWORDS = {
    "coding": [
        "code", "function", "class", "implement", "create", "build", "write",
        "generate", "program", "script", "module", "api", "endpoint", "crud",
        "method", "variable", "loop", "array", "string", "parse", "convert",
        "import", "export", "component", "widget", "page", "screen", "form",
    ],
    "architecture": [
        "design", "architecture", "system", "pattern", "microservice", "scale",
        "structure", "database", "schema", "migrate", "refactor", "plan",
        "monolith", "serverless", "infrastructure", "framework",
    ],
    "security": [
        "security", "vulnerability", "owasp", "injection", "xss", "csrf",
        "auth", "authentication", "authorization", "encrypt", "hash", "jwt",
        "token", "ssl", "tls", "firewall", "pentest", "audit",
    ],
    "debugging": [
        "error", "bug", "fix", "debug", "crash", "exception", "traceback",
        "stack", "fail", "broken", "not working", "issue", "problem",
        "undefined", "null", "nan", "typeerror", "syntaxerror",
    ],
    "ui_ux": [
        "ui", "ux", "design", "layout", "responsive", "animation", "style",
        "theme", "color", "font", "button", "nav", "sidebar", "dashboard",
        "glassmorphism", "dark mode", "gradient", "card",
    ],
    "deployment": [
        "deploy", "docker", "railway", "ci/cd", "pipeline", "kubernetes",
        "container", "production", "staging", "nginx", "server", "host",
        "environment", "dockerfile", "compose",
    ],
    "optimization": [
        "optimize", "performance", "speed", "fast", "slow", "latency",
        "memory", "cache", "efficient", "bottleneck", "profile", "benchmark",
    ],
    "testing": [
        "test", "unittest", "pytest", "jest", "coverage", "mock", "assert",
        "integration", "e2e", "spec", "tdd", "bdd",
    ],
}


class TaskAnalyzer:
    """
    Classifies user intent and routes to the optimal expert agent team.
    Uses fast keyword matching first, with optional model-based classification.
    """

    def __init__(self):
        self.analysis_count = 0

    async def analyze(self, prompt: str) -> Dict[str, Any]:
        """
        Analyzes a user prompt and returns:
        - task_type: The classified category
        - confidence: How confident the classification is
        - selected_agents: The expert team to deploy
        - reasoning: Why this classification was chosen
        """
        self.analysis_count += 1
        start = time.time()

        prompt_lower = prompt.lower()

        # Phase 1: Fast keyword scoring
        scores: Dict[str, float] = {}
        for category, keywords in TASK_KEYWORDS.items():
            matches = sum(1 for kw in keywords if kw in prompt_lower)
            if matches > 0:
                scores[category] = matches / len(keywords)

        # Phase 2: Determine the winner
        if scores:
            task_type = max(scores, key=scores.get)
            confidence = min(scores[task_type] * 5, 1.0)  # Normalize to 0-1
        else:
            task_type = "general"
            confidence = 0.3

        # Phase 3: Select the expert team
        selected_agents = get_agents_for_task(task_type)

        # Always include the Synthesizer at the end
        if AgentRole.SYNTHESIZER not in selected_agents:
            selected_agents.append(AgentRole.SYNTHESIZER)

        latency_ms = round((time.time() - start) * 1000, 2)

        result = {
            "task_type": task_type,
            "confidence": round(confidence, 3),
            "selected_agents": [a.value for a in selected_agents],
            "all_scores": {k: round(v, 3) for k, v in sorted(scores.items(), key=lambda x: x[1], reverse=True)},
            "latency_ms": latency_ms,
        }

        logger.info(
            f"🧠 [TASK ANALYZER] Type: {task_type} | Confidence: {confidence:.2f} | "
            f"Team: {[a.value for a in selected_agents]} | Latency: {latency_ms}ms"
        )

        return result


# Singleton
task_analyzer = TaskAnalyzer()
