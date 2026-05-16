"""
Orchestrator Service v2.0 — Collaborative Multi-Agent Engine
=============================================================
The central nervous system of Code Genie 2.0.

Replaces the old failover-based architecture with a parallel,
collaborative multi-LLM intelligence system where specialized
agents work together simultaneously.

Architecture:
1. Security Gateway scans the prompt
2. Task Analyzer classifies intent and selects expert team
3. Agents execute in parallel with role-specific system prompts
4. Synthesis Engine (Judge) merges outputs
5. Audit Logger records the entire workflow
"""

import asyncio
import logging
import time
import json
from typing import List, Dict, Any, Optional
from datetime import datetime, timezone

# Core Services
from . import gemini_service as gemini_mod
from . import groq_service as groq_mod
from . import openrouter_service as openrouter_mod
from . import github_service as github_mod
from . import mistral_service as mistral_mod

# 2.0 Modules
from .agent_roles import AgentRole, AGENT_PERSONAS, get_agent_config
from .task_analyzer import task_analyzer
from .security_gateway import security_gateway
from .synthesis_engine import synthesis_engine
from .audit_logger import audit_logger
from .agent_tools_service import agent_tools
from .indexer_service import indexer
from .redis_service import redis_service
from ..prompts.templates import SYSTEM_INSTRUCTION

logger = logging.getLogger(__name__)


class AIOrchestrator:
    """
    Code Genie 2.0 — Collaborative Multi-Agent Orchestration Engine.

    Lifecycle: SCAN → ANALYZE → ROUTE → EXECUTE → SYNTHESIZE → AUDIT
    """

    def __init__(self):
        # Legacy free_pool preserved for backward compatibility
        self.free_pool = [
            "google/gemini-3.1-pro:free",
            "google/gemini-3.1-flash:free",
            "google/gemini-2.0-flash-exp:free",
            "google/gemini-pro-1.5:free",
            "meta-llama/llama-3.3-70b-instruct:free",
            "qwen/qwen-2.5-coder-32b-instruct:free",
            "openai/gpt-oss-120b:free",
            "deepseek/deepseek-chat:free",
            "microsoft/phi-3-medium-128k-instruct:free",
            "qwen/qwen-2.5-coder-7b-instruct:free",
            "nousresearch/hermes-3-llama-3.1-405b:free",
            "mistralai/mistral-large-latest:free",
            "mistralai/mistral-7b-instruct:free",
            "gryphe/mythomax-l2-13b:free",
            "undi95/toppy-m-7b:free",
            "openchat/openchat-7b:free",
            "microsoft/phi-4-instruct:free",
        ]

        # Orchestration metrics
        self._total_orchestrations = 0
        self._total_agent_calls = 0

    # ============================================================
    # PRIMARY ENTRY POINT: Collaborative Response
    # ============================================================

    async def get_collaborative_response(
        self,
        prompt: str,
        history: List[Dict] = None,
        user_id: str = "anonymous",
        user_level: str = "intermediate",
    ) -> Dict[str, Any]:
        """
        The v2.0 orchestration pipeline:
        1. SECURITY SCAN → 2. TASK ANALYSIS → 3. RAG CONTEXT →
        4. PARALLEL AGENTS → 5. SYNTHESIS → 6. AUDIT
        """
        history = history or []
        workflow_id = f"wf_{int(time.time())}_{self._total_orchestrations}"
        self._total_orchestrations += 1
        start_time = time.time()

        await audit_logger.log("THINK", "orchestrator", "workflow_started",
                               {"prompt_length": len(prompt), "user_id": user_id},
                               user_id=user_id, workflow_id=workflow_id)

        # ── Step 0: Semantic Cache Check ──
        cached_res = await redis_service.get(f"cache:{prompt}")
        if cached_res:
            await audit_logger.log("OBSERVE", "orchestrator", "cache_hit", 
                                   {"prompt_preview": prompt[:30]}, user_id=user_id, workflow_id=workflow_id)
            cached_res["workflow_id"] = workflow_id
            cached_res["cached"] = True
            return cached_res

        # ── Step 1: Security Gateway ──
        security_result = await security_gateway.scan_prompt(prompt, user_id)
        if security_result["verdict"] == "BLOCKED":
            await audit_logger.log("SECURITY", "security_gateway", "prompt_blocked",
                                   {"threats": security_result["threats_detected"]},
                                   user_id=user_id, workflow_id=workflow_id)
            return {
                "answer": "⚠️ Your request was blocked by the Security Gateway due to potentially unsafe content.",
                "strategy": "blocked_by_security",
                "models_participated": [],
                "security_verdict": "BLOCKED",
                "workflow_id": workflow_id,
                "latency": round(time.time() - start_time, 2),
            }

        clean_prompt = security_result["cleaned_prompt"]

        # ── Step 2: Task Analysis ──
        analysis = await task_analyzer.analyze(clean_prompt)
        task_type = analysis["task_type"]
        selected_agents = analysis["selected_agents"]

        await audit_logger.log("PLAN", "task_analyzer", f"classified_as_{task_type}",
                               {"agents": selected_agents, "confidence": analysis["confidence"]},
                               user_id=user_id, workflow_id=workflow_id)

        # ── Step 3: RAG Context Retrieval ──
        context_snippets = await indexer.search_context(clean_prompt)
        context_str = "\n".join(
            [f"--- FILE: {c['path']} ---\n{c['content']}" for c in context_snippets]
        ) if context_snippets else ""

        # ── Step 4: Parallel Agent Execution ──
        agent_tasks = []
        for agent_role_name in selected_agents:
            if agent_role_name == AgentRole.SYNTHESIZER.value:
                continue  # Synthesizer runs after all agents
            try:
                role_enum = AgentRole(agent_role_name)
                agent_tasks.append(
                    self._execute_agent(role_enum, clean_prompt, history, context_str, workflow_id)
                )
            except ValueError:
                logger.warning(f"Unknown agent role: {agent_role_name}")

        # Execute all agents in parallel with a global timeout
        agent_outputs = []
        try:
            results = await asyncio.wait_for(
                asyncio.gather(*agent_tasks, return_exceptions=True),
                timeout=25.0,
            )
            for result in results:
                if isinstance(result, dict) and "error" not in result:
                    agent_outputs.append(result)
                elif isinstance(result, Exception):
                    logger.warning(f"⚠️ Agent failed: {result}")
        except asyncio.TimeoutError:
            logger.error("🛑 Agent parallel execution timed out after 25s.")
            await audit_logger.log("ERROR", "orchestrator", "parallel_timeout",
                                   workflow_id=workflow_id)

        # ── Step 5: Synthesis ──
        if agent_outputs:
            synthesis_result = await synthesis_engine.synthesize(
                clean_prompt, agent_outputs, workflow_id
            )
            final_answer = synthesis_result["content"]
            strategy = synthesis_result["strategy"]
            agents_contributed = synthesis_result["agents_contributed"]
        else:
            # Emergency fallback: Direct Gemini call
            logger.warning("⚠️ No agent outputs. Falling back to direct Gemini.")
            final_answer = await self._emergency_fallback(clean_prompt, history)
            strategy = "emergency_gemini_fallback"
            agents_contributed = ["gemini-direct"]

        # ── Step 6: Adapt to user level ──
        final_answer = self._adapt_to_level(final_answer, user_level)

        total_latency = round(time.time() - start_time, 2)

        await audit_logger.log("COMPLETE", "orchestrator", "workflow_finished",
                               {"latency": total_latency, "agents": agents_contributed,
                                "strategy": strategy},
                               user_id=user_id, workflow_id=workflow_id)

        final_response = {
            "answer": final_answer,
            "strategy": strategy,
            "models_participated": agents_contributed,
            "task_type": task_type,
            "security_verdict": security_result["verdict"],
            "workflow_id": workflow_id,
            "latency": total_latency,
            "parallel_execution": True,
        }

        # Store in cache (expire in 6 hours)
        await redis_service.set(f"cache:{prompt}", final_response, expire_seconds=21600)

        return final_response

    # Backward compatibility alias
    async def get_parallel_response(self, prompt: str, history=None, user_level="intermediate"):
        return await self.get_collaborative_response(prompt, history, user_level=user_level)

    # ============================================================
    # AGENT EXECUTION
    # ============================================================

    async def _execute_agent(
        self,
        role: AgentRole,
        prompt: str,
        history: List[Dict],
        context: str,
        workflow_id: str,
    ) -> Dict[str, Any]:
        """
        Executes a single agent with its role-specific system prompt,
        preferred model, and workspace context.
        """
        config = get_agent_config(role)
        if not config:
            return {"error": f"No config for role {role}"}

        agent_name = config["name"]
        model_provider = config["preferred_model"]
        model_name = config["preferred_model_name"]
        system_prompt = config["system_prompt"]

        self._total_agent_calls += 1
        start = time.time()

        await audit_logger.log("ACT", agent_name, f"executing_with_{model_provider}",
                               {"model": model_name}, workflow_id=workflow_id)

        # Build the agent's enhanced prompt
        enhanced_prompt = f"{system_prompt}\n\n"
        if context:
            enhanced_prompt += f"WORKSPACE CONTEXT:\n{context}\n\n"
        enhanced_prompt += f"USER REQUEST:\n{prompt}"

        try:
            content = await asyncio.wait_for(
                self._call_provider(model_provider, enhanced_prompt, history, model_name),
                timeout=15.0,
            )

            latency = round(time.time() - start, 2)

            await audit_logger.log("OBSERVE", agent_name, "execution_success",
                                   {"latency": latency, "content_length": len(content)},
                                   workflow_id=workflow_id)

            return {
                "agent_name": agent_name,
                "role": role.value,
                "content": content,
                "model": model_name,
                "latency": latency,
            }

        except asyncio.TimeoutError:
            logger.warning(f"🕒 Agent {agent_name} timed out (15s)")
            await audit_logger.log("ERROR", agent_name, "timeout",
                                   workflow_id=workflow_id)
            return {"agent_name": agent_name, "error": "Timeout"}

        except Exception as e:
            logger.error(f"❌ Agent {agent_name} failed: {e}")
            await audit_logger.log("ERROR", agent_name, f"failed: {e}",
                                   workflow_id=workflow_id)
            return {"agent_name": agent_name, "error": str(e)}

    async def _call_provider(
        self, provider: str, prompt: str, history: List[Dict], model_name: str
    ) -> str:
        """Routes to the correct LLM provider."""
        if provider == "gemini":
            contents = []
            for msg in history:
                contents.append({"role": msg["role"], "parts": [{"text": msg["content"]}]})
            contents.append({"role": "user", "parts": [{"text": prompt}]})
            return await gemini_mod.generate(contents)

        elif provider == "groq":
            messages = history + [{"role": "user", "content": prompt}]
            return await groq_mod.generate(messages)

        elif provider == "openrouter":
            messages = history + [{"role": "user", "content": prompt}]
            return await openrouter_mod.generate(messages, model=model_name)

        elif provider == "github":
            messages = history + [{"role": "user", "content": prompt}]
            return await github_mod.generate(messages)

        elif provider == "mistral":
            messages = history + [{"role": "user", "content": prompt}]
            return await mistral_mod.generate(messages)

        else:
            raise ValueError(f"Unknown provider: {provider}")

    async def _emergency_fallback(self, prompt: str, history: List[Dict]) -> str:
        """Last-resort direct call to Gemini."""
        try:
            contents = []
            for msg in history:
                contents.append({"role": msg["role"], "parts": [{"text": msg["content"]}]})
            contents.append({"role": "user", "parts": [{"text": prompt}]})
            return await gemini_mod.generate(contents)
        except Exception as e:
            return f"Code Genie failed to respond. (Error: {e})"

    # ============================================================
    # PLAN GENERATION (Preserved from v1)
    # ============================================================

    async def generate_plan(self, prompt: str, history: List[Dict] = None) -> Dict[str, Any]:
        """Decomposes a complex goal into a multi-step execution plan."""
        history = history or []

        context_snippets = await indexer.search_context(prompt)
        context_str = "\n".join([f"--- FILE: {c['path']} ---\n{c['content']}" for c in context_snippets])

        planning_prompt = f"""
        YOU ARE AN ADVANCED PROJECT ARCHITECT WITH AUTONOMOUS TOOLS AND WORKSPACE AWARENESS.
        GOAL: {prompt}
        
        WORKSPACE CONTEXT:
        {context_str}
        
        AVAILABLE TOOLS:
        - write_file(path, content): Create or update a file.
        - run_command(command): Execute a shell command in workspace.
        - read_file(path): Read existing code for context.
        - list_files(path): Explore directory structure.
        
        TASK: Decompose this goal into 3-6 actionable engineering steps.
        FORMAT: RETURN ONLY VALID JSON.
        JSON STRUCTURE:
        {{
            "goal": "{prompt}",
            "steps": [
                {{
                    "id": "step_1",
                    "title": "Short title",
                    "description": "Technical detail",
                    "status": "pending",
                    "tool_call": {{
                        "action": "write_file | run_command | read_file | list_files",
                        "path": "relative/path/to/file",
                        "content": "Full code content for write_file",
                        "command": "shell command for run_command"
                    }}
                }}
            ]
        }}
        """

        try:
            raw_response = await self._call_provider("gemini", planning_prompt, history, "gemini-1.5-pro-latest")
            content = raw_response

            if "```json" in content:
                content = content.split("```json")[1].split("```")[0].strip()
            elif "```" in content:
                content = content.split("```")[1].split("```")[0].strip()

            plan_data = json.loads(content)
            plan_data["id"] = f"plan_{int(time.time())}"
            plan_data["created_at"] = datetime.now(timezone.utc).isoformat()
            plan_data["is_approved"] = False
            return plan_data

        except Exception as e:
            logger.error(f"Planning Error: {e}")
            return {
                "id": f"plan_{int(time.time())}",
                "goal": prompt,
                "created_at": datetime.now(timezone.utc).isoformat(),
                "is_approved": False,
                "steps": [
                    {"id": "step_1", "title": "Analyze Requirements", "description": f"Decompose: {prompt}", "status": "pending"},
                    {"id": "step_2", "title": "Implementation Phase", "description": "Execute the core logic.", "status": "pending"},
                    {"id": "step_3", "title": "Verification & Tests", "description": "Verify code against goal.", "status": "pending"},
                ],
            }

    # ============================================================
    # AUTONOMOUS PLAN EXECUTION (Preserved from v1)
    # ============================================================

    async def run_autonomous_plan(self, user_id: str, plan_id: str, plan_data: Dict[str, Any]):
        """Iteratively executes a multi-step plan using real-world tools."""
        from app.services.socket_manager import manager as socket_manager

        workflow_id = f"auto_{plan_id}"
        await audit_logger.log("ACT", "orchestrator", "autonomous_plan_started",
                               {"plan_id": plan_id}, user_id=user_id, workflow_id=workflow_id)

        steps = plan_data.get("steps", [])

        for step in steps:
            step_id = step["id"]

            await socket_manager.broadcast_to_user(user_id, {
                "type": "plan_step_update",
                "step_id": step_id,
                "status": "running",
            })

            tool_call = step.get("tool_call")
            output = ""
            diff = None

            if tool_call:
                action = tool_call.get("action")
                try:
                    if action == "write_file":
                        res = await agent_tools.write_file(tool_call.get("path"), tool_call.get("content", ""))
                        output = f"✅ File written: {tool_call.get('path')}" if res["status"] == "success" else f"❌ Error: {res['message']}"
                        diff = res.get("diff")
                    elif action == "run_command":
                        res = await agent_tools.run_command(tool_call.get("command", ""))
                        output = res.get("stdout", "") + res.get("stderr", "")
                        if not output and res["status"] == "success":
                            output = f"✅ Command finished (Code: {res['exit_code']})"
                    elif action == "read_file":
                        res = await agent_tools.read_file(tool_call.get("path"))
                        output = res.get("content", f"❌ Error: {res.get('message')}")
                    elif action == "list_files":
                        res = await agent_tools.list_files(tool_call.get("path", "."))
                        output = str(res.get("items", f"❌ Error: {res.get('message')}"))
                except Exception as e:
                    output = f"⚠️ Tool Execution Error: {e}"

                await socket_manager.broadcast_to_user(user_id, {
                    "type": "execution_log",
                    "step_id": step_id,
                    "output": output,
                })

            await asyncio.sleep(2)

            await socket_manager.broadcast_to_user(user_id, {
                "type": "plan_step_update",
                "step_id": step_id,
                "status": "completed",
                "output": output,
                "diff": diff,
            })

        await audit_logger.log("COMPLETE", "orchestrator", "autonomous_plan_finished",
                               {"plan_id": plan_id}, user_id=user_id, workflow_id=workflow_id)

        await socket_manager.broadcast_to_user(user_id, {
            "type": "mission_complete",
            "title": "Mission Complete 🚀",
            "body": "AI has successfully finished the orchestration plan.",
            "plan_id": plan_id,
        })

    # ============================================================
    # CONSENSUS (Enhanced from v1)
    # ============================================================

    async def ensemble_consensus(self, prompt: str, min_agree: int = 2) -> Optional[dict]:
        """Consensus mechanism using top free models."""
        models = self.free_pool[:3]
        tasks = [self._call_provider("openrouter", prompt, [], mid) for mid in models]

        try:
            responses = await asyncio.wait_for(
                asyncio.gather(*tasks, return_exceptions=True), timeout=15.0
            )
        except asyncio.TimeoutError:
            return None

        results = []
        for i, resp in enumerate(responses):
            if isinstance(resp, str) and resp:
                results.append({"model": models[i], "content": resp})

        if not results:
            return None

        results.sort(key=lambda x: len(x["content"]), reverse=True)
        best = results[0]
        best["consensus"] = len(results) >= min_agree
        best["ensemble_models"] = [r["model"] for r in results]
        best["model_used"] = f"Ensemble ({len(results)} models)"
        return best

    # ============================================================
    # UTILITIES
    # ============================================================

    def _adapt_to_level(self, text: str, level: str) -> str:
        if level == "beginner":
            return f"**[Beginner-Friendly Explanation]**\n\n{text}"
        return text

    def get_orchestration_stats(self) -> Dict[str, Any]:
        """Returns live orchestration metrics for the dashboard."""
        return {
            "total_orchestrations": self._total_orchestrations,
            "total_agent_calls": self._total_agent_calls,
            "security_stats": security_gateway.get_stats(),
            "audit_stats": audit_logger.get_stats(),
            "synthesis_count": synthesis_engine.synthesis_count,
        }


# Global instance
orchestrator = AIOrchestrator()
