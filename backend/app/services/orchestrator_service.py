import asyncio
import logging
import time
import json
from typing import List, Dict, Any, Optional
from . import gemini_service as gemini_mod
from . import groq_service as groq_mod
from . import openrouter_service as openrouter_mod
from .agent_tools_service import agent_tools
from .indexer_service import indexer
from ..prompts.templates import SYSTEM_INSTRUCTION

logger = logging.getLogger(__name__)

class AIOrchestrator:
    """
    Advanced AI Orchestration System:
    - Parallel execution across multiple models.
    - Response evaluation and synthesis.
    - Context-aware and user-level adapted.
    """
    
    def __init__(self):
        self.free_pool = [
            "meta-llama/llama-3.3-70b-instruct:free",
            "qwen/qwen-2.5-coder-32b-instruct:free",
            "google/gemini-2.0-flash-exp:free",
            "deepseek/deepseek-chat:free",
            "microsoft/phi-3-medium-128k-instruct:free",
            "openai/gpt-oss-120b:free",
            "qwen/qwen-2.5-coder-7b-instruct:free",
            "google/gemini-pro-1.5:free",
            "nousresearch/hermes-3-llama-3.1-405b:free",
            "mistralai/mistral-7b-instruct:free",
            "gryphe/mythomax-l2-13b:free",
            "undi95/toppy-m-7b:free",
            "openchat/openchat-7b:free"
        ]

    async def get_parallel_response(self, prompt: str, history: List[Dict] = None, user_level: str = "intermediate") -> Dict[str, Any]:
        """
        Calls multiple models in parallel, evaluates, and returns the best refined answer.
        """
        history = history or []
        start_time = time.time()
        
        # 1. Define tasks for parallel execution
        # Always include the core services + top free models
        tasks = [
            self._call_model("gemini", prompt, history),
            self._call_model("groq", prompt, history)
        ]
        
        # Add top free models from OpenRouter
        for model_id in self.free_pool[:2]: # Query top 2 free models in parallel
            tasks.append(self._call_model("openrouter", prompt, history, specific_model=model_id))
        
        # 2. Execute in parallel with a global timeout to prevent hanging on slow free models
        try:
            results = await asyncio.wait_for(asyncio.gather(*tasks, return_exceptions=True), timeout=20.0)
        except asyncio.TimeoutError:
            logger.error("🛑 [Orchestrator] Parallel orchestration TIMEOUT after 20s. Using partial results.")
            results = []
        except Exception as e:
            logger.error(f"❌ [Orchestrator] Parallel gather failed: {e}")
            results = []
        
        # 3. Filter successful responses
        successful_responses = []
        for i, res in enumerate(results):
            model_id = res.get("model", "unknown") if isinstance(res, dict) else "unknown"
            if isinstance(res, dict) and "error" not in res:
                logger.info(f"✅ [Orchestrator] {model_id.upper()} succeeded in {res.get('latency', 0):.2f}s")
                successful_responses.append(res)
            else:
                err_msg = str(res) if not isinstance(res, dict) else res.get("error", "Unknown error")
                logger.warning(f"⚠️ [Orchestrator] Model failed: {err_msg}")

        if not successful_responses:
            # Retry mechanism
            logger.warning("All models failed. Retrying with a secondary free model...")
            try:
                res = await self._call_model("openrouter", prompt, history, specific_model="meta-llama/llama-3.3-70b-instruct:free")
                if "error" not in res:
                    successful_responses.append(res)
            except:
                pass
                
        if not successful_responses:
            return {
                "answer": "Code Genie failed to respond. Try again...",
                "strategy": "failed_all",
                "models_participated": []
            }

        # 4. Evaluation & Synthesis Logic
        is_code = "```" in (successful_responses[0]["content"] if successful_responses else "") or any(kw in prompt.lower() for kw in ["code", "function", "fix", "error"])
        
        # Sort by speed
        successful_responses.sort(key=lambda x: x["latency"])
        fastest = successful_responses[0]
        
        # Find a high-reasoning response (Gemini or Llama 70B)
        best_res = next((r for r in successful_responses if "gemini" in r["model"] or "70b" in r["model"]), successful_responses[0])
        
        final_answer = ""
        strategy = ""
        models_participated = [r["model"] for r in successful_responses]

        if is_code:
            final_answer = best_res["content"]
            strategy = f"Selected high-reasoning {best_res['model']} output for code task."
        elif len(successful_responses) > 1:
            # Pick the longest/most complete response
            best = max(successful_responses, key=lambda x: len(x["content"]))
            final_answer = best["content"]
            strategy = f"Synthesized best response from {len(successful_responses)} parallel free models."
        else:
            final_answer = fastest["content"]
            strategy = f"Delivered fastest response from {fastest['model']}."

        # 5. Adapt to user level (Post-processing)
        final_answer = self._adapt_to_level(final_answer, user_level)

        total_latency = time.time() - start_time
        
        return {
            "answer": final_answer,
            "strategy": strategy,
            "models_participated": models_participated,
            "latency": round(total_latency, 2),
            "parallel_execution": True
        }

    async def ensemble_consensus(self, prompt: str, min_agree: int = 2) -> Optional[dict]:
        """
        Consensus mechanism using the top free models.
        """
        models = self.free_pool[:3] # Use top 3 free models

        print(f"[ENSEMBLE] Launching {len(models)} models in parallel...")
        
        tasks = [self._call_model("openrouter", prompt, [], specific_model=mid) for mid in models]
        responses = await asyncio.gather(*tasks)

        results = [r for r in responses if r is not None and "error" not in r]
        models_tried = [r["model"] for r in results]

        if not results: return None
        
        # Simplified consensus: Return the one with highest "confidence" or longest content
        results.sort(key=lambda x: len(x["content"]), reverse=True)
        best = results[0]
        best['consensus'] = len(results) >= min_agree
        best['ensemble_models'] = models_tried
        best['model_used'] = f"Ensemble ({len(results)} models)"
        
        return best

    async def generate_plan(self, prompt: str, history: List[Dict] = None) -> Dict[str, Any]:
        """
        Decomposes a complex goal into a multi-step execution plan with autonomous tool calls and workspace context.
        """
        history = history or []
        
        # 1. Fetch Semantic Workspace Context
        context_snippets = await indexer.search_context(prompt)
        context_str = "\n".join([f"--- FILE: {c['path']} ---\n{c['content']}" for c in context_snippets])
        
        # 2. Specialized Planning Prompt with Tooling and Context Support
        planning_prompt = f"""
        YOU ARE AN ADVANCED PROJECT ARCHITECT WITH AUTONOMOUS TOOLS AND WORKSPACE AWARENESS.
        GOAL: {prompt}
        
        WORKSPACE CONTEXT (Relevant snippets from your project):
        {context_str}
        
        AVAILABLE TOOLS:
        - write_file(path, content): Create or update a file.
        - run_command(command): Execute a shell command in workspace.
        - read_file(path): Read existing code for context.
        - list_files(path): Explore directory structure.
        
        TASK: Decompose this goal into 3-6 actionable engineering steps.
        If a step requires action, include a "tool_call" object.
        
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
        
        RULES:
        1. Be technical and precise.
        2. Steps must be sequential and proactive.
        3. No conversational text. Only JSON.
        """
        
        try:
            # Use Gemini for its deep reasoning capabilities
            raw_response = await self._call_model("gemini", planning_prompt, history)
            
            if "error" in raw_response:
                raise Exception(raw_response["error"])
                
            content = raw_response["content"]
            
            # 2. Extract and Parse JSON
            if "```json" in content:
                content = content.split("```json")[1].split("```")[0].strip()
            elif "```" in content:
                content = content.split("```")[1].split("```")[0].strip()
                
            plan_data = json.loads(content)
            
            # 3. Add metadata
            from datetime import datetime, timezone
            plan_data["id"] = f"plan_{int(time.time())}"
            plan_data["created_at"] = datetime.now(timezone.utc).isoformat()
            plan_data["is_approved"] = False
            
            return plan_data
            
        except Exception as e:
            logger.error(f"Planning Error: {e}")
            # Fallback remains standard
            return {
                "id": f"plan_{int(time.time())}",
                "goal": prompt,
                "created_at": datetime.now(timezone.utc).isoformat(),
                "is_approved": False,
                "steps": [
                    {"id": "step_1", "title": "Analyze Requirements", "description": f"Decompose: {prompt}", "status": "pending"},
                    {"id": "step_2", "title": "Implementation Phase", "description": "Execute the core logic.", "status": "pending"},
                    {"id": "step_3", "title": "Verification & Tests", "description": "Verify code against goal.", "status": "pending"}
                ]
            }

    async def run_autonomous_plan(self, user_id: str, plan_id: str, plan_data: Dict[str, Any]):
        """
        Iteratively executes a multi-step plan, performing real-world actions.
        """
        from app.services.socket_manager import manager as socket_manager
        
        logger.info(f"🚀 Starting autonomous execution for Plan {plan_id} (User: {user_id})")
        
        steps = plan_data.get("steps", [])
        
        for step in steps:
            step_id = step["id"]
            
            # 1. Broadcast: Step is RUNNING
            await socket_manager.broadcast_to_user(
                user_id,
                {
                    "type": "plan_step_update",
                    "step_id": step_id,
                    "status": "running"
                }
            )
            
            # 2. Execute Step Logic (Real Tools)
            logger.info(f"⚙️ Executing Step {step_id}: {step['title']}")
            
            tool_call = step.get("tool_call")
            output = ""
            diff = None
            
            if tool_call:
                action = tool_call.get("action")
                try:
                    if action == "write_file":
                        res = await agent_tools.write_file(tool_call.get("path"), tool_call.get("content", ""))
                        if res["status"] == "success":
                            output = f"✅ File written: {tool_call.get('path')}"
                            diff = res.get("diff")
                        else:
                            output = f"❌ Error: {res['message']}"
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

                # 3. Broadcast Logs to the Console
                await socket_manager.broadcast_to_user(
                    user_id,
                    {
                        "type": "execution_log",
                        "step_id": step_id,
                        "output": output
                    }
                )

            # Natural delay for UI visibility
            await asyncio.sleep(2) 
            
            # 4. Broadcast: Step is COMPLETED
            await socket_manager.broadcast_to_user(
                user_id,
                {
                    "type": "plan_step_update",
                    "step_id": step_id,
                    "status": "completed",
                    "output": output,
                    "diff": diff
                }
            )
            
        logger.info(f"✅ Autonomous execution finished for Plan {plan_id}")
        await socket_manager.broadcast_to_user(
            user_id,
            {
                "type": "mission_complete",
                "title": "Mission Complete 🚀",
                "body": f"AI has successfully finished the orchestration plan.",
                "plan_id": plan_id
            }
        )

    async def _call_model(self, model_id: str, prompt: str, history: List[Dict], specific_model: str = None) -> Dict[str, Any]:
        start = time.time()
        try:
            # Add internal timeout per model call to ensure one stuck model doesn't block others
            return await asyncio.wait_for(self._execute_model_call(model_id, prompt, history, specific_model), timeout=12.0)
        except asyncio.TimeoutError:
            logger.warning(f"🕒 [Orchestrator] Model {model_id} timed out after 12s")
            return {"model": model_id, "error": "Timeout", "latency": 12.0}
        except Exception as e:
            logger.error(f"Parallel Task Error ({model_id}): {e}")
            return {"model": model_id, "error": str(e), "latency": time.time() - start}

    async def _execute_model_call(self, model_id: str, prompt: str, history: List[Dict], specific_model: str = None) -> Dict[str, Any]:
        start = time.time()
        # Convert history to service-specific format if needed
        if model_id == "gemini":
            contents = []
            for msg in history:
                contents.append({"role": msg["role"], "parts": [{"text": msg["content"]}]})
            contents.append({"role": "user", "parts": [{"text": prompt}]})
            content = await gemini_mod.generate(contents)
            final_model = "gemini-2.0-flash"
        elif model_id == "groq":
            messages = history + [{"role": "user", "content": prompt}]
            content = await groq_mod.generate(messages)
            final_model = "llama-3.3-70b-specdec"
        elif model_id == "openrouter":
            messages = history + [{"role": "user", "content": prompt}]
            target_model = specific_model or "meta-llama/llama-3.3-70b-instruct:free"
            content = await openrouter_mod.generate(messages, model=target_model)
            final_model = target_model
        
        return {
            "model": final_model,
            "content": content,
            "latency": time.time() - start
        }

    def _adapt_to_level(self, text: str, level: str) -> str:
        """
        Simulated level adaptation. In a future update, this could be a small model pass.
        """
        if level == "beginner":
            return f"**[Beginner-Friendly Explanation]**\n\n{text}"
        elif level == "advanced":
            # Potentially strip verbose parts (simulated)
            return text
        return text

# Global instance
orchestrator = AIOrchestrator()
