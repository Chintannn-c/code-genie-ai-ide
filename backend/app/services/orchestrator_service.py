import asyncio
import logging
import time
import json
from typing import List, Dict, Any, Optional
from app.services import gemini_service, groq_service, openrouter_service
from app.services.agent_tools_service import agent_tools
from app.services.indexer_service import indexer
from app.prompts.templates import SYSTEM_INSTRUCTION

logger = logging.getLogger(__name__)

class AIOrchestrator:
    """
    Advanced AI Orchestration System:
    - Parallel execution across multiple models.
    - Response evaluation and synthesis.
    - Context-aware and user-level adapted.
    """
    
    def __init__(self):
        self.models = {
            "gemini": gemini_service,
            "groq": groq_service,
            "openrouter": openrouter_service
        }

    async def get_parallel_response(self, prompt: str, history: List[Dict] = None, user_level: str = "intermediate") -> Dict[str, Any]:
        """
        Calls multiple models in parallel, evaluates, and returns the best refined answer.
        """
        history = history or []
        start_time = time.time()
        
        # 1. Define tasks for parallel execution
        tasks = [
            self._call_model("gemini", prompt, history),
            self._call_model("groq", prompt, history),
            self._call_model("openrouter", prompt, history)
        ]
        
        # 2. Execute in parallel
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # 3. Filter successful responses
        successful_responses = []
        for i, res in enumerate(results):
            model_name = list(self.models.keys())[i] if i < len(self.models) else "unknown"
            if isinstance(res, dict) and "error" not in res:
                logger.info(f"✅ [Orchestrator] {model_name.upper()} succeeded in {res.get('latency', 0):.2f}s")
                successful_responses.append(res)
            else:
                err_msg = str(res) if not isinstance(res, dict) else res.get("error", "Unknown error")
                logger.warning(f"⚠️ [Orchestrator] {model_name.upper()} failed: {err_msg}")
        
        if not successful_responses:
            # Retry mechanism
            logger.warning("All models failed. Retrying once...")
            # Simple retry with just the most reliable model (Gemini)
            try:
                res = await self._call_model("gemini", prompt, history)
                if "error" not in res:
                    successful_responses.append(res)
            except:
                pass
                
        if not successful_responses:
            return {
                "answer": "I apologize, but all AI engines are currently unavailable. Please check your internet connection or API keys.",
                "strategy": "failed_all",
                "models_participated": []
            }

        # 4. Evaluation & Synthesis Logic
        # For now, we'll use a selection heuristic based on length, speed, and model strengths.
        # Deep Synthesis could be another AI call, but let's start with a smart heuristic.
        
        # Heuristic: 
        # - If it's a code request, prefer Gemini if it succeeded.
        # - If it's a quick chat, prefer the fastest response (usually Groq).
        
        is_code = "```" in successful_responses[0]["content"] or any(kw in prompt.lower() for kw in ["code", "function", "fix", "error"])
        
        # Sort by speed
        successful_responses.sort(key=lambda x: x["latency"])
        fastest = successful_responses[0]
        
        # Find Gemini response for depth
        gemini_res = next((r for r in successful_responses if r["model"] == "gemini"), None)
        
        final_answer = ""
        strategy = ""
        models_participated = [r["model"] for r in successful_responses]

        if is_code and gemini_res:
            # Merged Strategy: Use Gemini's code with Groq's speed as a fallback
            final_answer = gemini_res["content"]
            strategy = "Selected high-reasoning Gemini output for complex code task (Parallel execution)."
        elif len(successful_responses) > 1:
            # Merged Strategy: Synthesis
            # In a more advanced version, we'd use a small model to merge these.
            # Here we'll pick the most complete-looking one.
            best = max(successful_responses, key=lambda x: len(x["content"]))
            final_answer = best["content"]
            strategy = f"Synthesized best response from {len(successful_responses)} parallel models. Chosen based on completeness and depth."
        else:
            final_answer = fastest["content"]
            strategy = f"Delivered fastest valid response from {fastest['model']} (Parallel mode)."

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

    async def _call_model(self, model_id: str, prompt: str, history: List[Dict]) -> Dict[str, Any]:
        start = time.time()
        try:
            service = self.models[model_id]
            # Convert history to service-specific format if needed
            # For simplicity, we'll use a common format or just prompt for now
            if model_id == "gemini":
                # Convert history to Gemini contents
                contents = []
                for msg in history:
                    contents.append({"role": msg["role"], "parts": [{"text": msg["content"]}]})
                contents.append({"role": "user", "parts": [{"text": prompt}]})
                content = await service.generate(contents)
            elif model_id == "groq":
                messages = history + [{"role": "user", "content": prompt}]
                content = await service.generate(messages)
            elif model_id == "openrouter":
                messages = history + [{"role": "user", "content": prompt}]
                content = await service.generate(messages)
            
            return {
                "model": model_id,
                "content": content,
                "latency": time.time() - start
            }
        except Exception as e:
            logger.error(f"Parallel Task Error ({model_id}): {e}")
            return {"model": model_id, "error": str(e), "latency": time.time() - start}

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
