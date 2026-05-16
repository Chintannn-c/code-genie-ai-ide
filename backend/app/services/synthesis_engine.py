"""
Synthesis Engine — The Judge
==============================
The final stage of the collaborative pipeline.
Takes outputs from multiple specialized agents and merges them
into a single, polished, production-ready response.

Implements:
- Deduplication of overlapping content
- Best-of-breed code snippet selection
- Security-first prioritization
- Coherent narrative construction
- Collaboration summary generation
"""

import logging
import time
from typing import Dict, Any, List
from . import gemini_service as gemini_mod
from .security_gateway import security_gateway
from .audit_logger import audit_logger

logger = logging.getLogger(__name__)


SYNTHESIS_SYSTEM_PROMPT = """You are the SYNTHESIS JUDGE — the final stage of a collaborative AI engineering team.

You will receive outputs from multiple specialized expert agents who have each analyzed the same user request from their unique perspective:
- Architect: system design and structure
- Coder: implementation code
- Auditor: security analysis
- Optimizer: performance recommendations
- Debugger: error analysis and fixes
- Reviewer: code quality assessment

YOUR TASK:
1. **Merge** the best parts of each expert's output into ONE cohesive response.
2. **Deduplicate** — remove repeated information across agents.
3. **Prioritize Security** — if the Auditor flagged issues, ensure fixes are applied in the code.
4. **Preserve Code Quality** — use the Coder's implementation but apply the Optimizer's improvements.
5. **Maintain Formatting** — preserve markdown, code blocks, and structure.
6. **Add Collaboration Summary** — at the end, briefly note which agents contributed.

OUTPUT RULES:
- Deliver a single, unified, production-ready response.
- Do NOT reference the agents or the synthesis process in the main body.
- The collaboration summary goes at the very end in a small note.
- If agents disagree, prefer the SECURE solution.
"""


class SynthesisEngine:
    """
    Merges multi-agent outputs into a single response using a Judge model.
    """

    def __init__(self):
        self.synthesis_count = 0

    async def synthesize(
        self,
        user_prompt: str,
        agent_outputs: List[Dict[str, Any]],
        workflow_id: str = None,
    ) -> Dict[str, Any]:
        """
        Takes a list of agent outputs and produces a unified final response.
        
        Each agent_output should have:
        - agent_name: str
        - role: str
        - content: str
        - latency: float
        - model: str
        """
        self.synthesis_count += 1
        start = time.time()

        if not agent_outputs:
            return {
                "content": "No agent responses were available for synthesis.",
                "strategy": "no_input",
                "agents_contributed": [],
                "latency": 0.0,
            }

        # Fast path: If only one agent responded, skip synthesis
        if len(agent_outputs) == 1:
            single = agent_outputs[0]
            await audit_logger.log(
                event_type="SYNTHESIS",
                agent_name="synthesizer",
                action="single_agent_passthrough",
                details={"source_agent": single.get("agent_name", "unknown")},
                workflow_id=workflow_id,
            )
            return {
                "content": single["content"],
                "strategy": f"Single agent passthrough ({single.get('agent_name', 'unknown')})",
                "agents_contributed": [single.get("agent_name", "unknown")],
                "latency": round(time.time() - start, 2),
            }

        # Pre-Synthesis Security Scan: Check all agent outputs for contamination
        clean_outputs = []
        for output in agent_outputs:
            scan_result = await security_gateway.scan_agent_output(
                output.get("content", ""),
                output.get("agent_name", "unknown"),
            )
            if scan_result["verdict"] == "CLEAN":
                clean_outputs.append(output)
            else:
                logger.warning(
                    f"🚨 [SYNTHESIS] Rejecting contaminated output from {output.get('agent_name')}"
                )
                await audit_logger.log(
                    event_type="QUARANTINE",
                    agent_name="synthesizer",
                    action="rejected_contaminated_output",
                    details={
                        "source_agent": output.get("agent_name"),
                        "threats": scan_result.get("threats", []),
                    },
                    workflow_id=workflow_id,
                )

        if not clean_outputs:
            clean_outputs = agent_outputs[:1]  # Fallback to first output

        # Build the synthesis prompt
        synthesis_input = f"USER REQUEST:\n{user_prompt}\n\n"
        synthesis_input += "=" * 60 + "\n"
        synthesis_input += "EXPERT AGENT OUTPUTS:\n"
        synthesis_input += "=" * 60 + "\n\n"

        for output in clean_outputs:
            agent_name = output.get("agent_name", "Unknown")
            role = output.get("role", "Expert")
            content = output.get("content", "")
            model = output.get("model", "unknown")
            latency = output.get("latency", 0)

            synthesis_input += f"--- {agent_name.upper()} ({role}) | Model: {model} | {latency:.1f}s ---\n"
            synthesis_input += content[:4000]  # Cap per-agent output to prevent token explosion
            synthesis_input += "\n\n"

        synthesis_input += "=" * 60 + "\n"
        synthesis_input += "SYNTHESIZE the above into ONE final response. Follow the synthesis rules.\n"

        # Call the Judge model (Gemini 3.1 Pro)
        try:
            contents = [
                {"role": "user", "parts": [{"text": SYNTHESIS_SYSTEM_PROMPT}]},
                {"role": "model", "parts": [{"text": "I understand. I will merge the expert outputs into one cohesive response."}]},
                {"role": "user", "parts": [{"text": synthesis_input}]},
            ]

            final_content = await gemini_mod.generate(contents)
            strategy = f"Judge synthesis from {len(clean_outputs)} agents"

        except Exception as e:
            logger.error(f"❌ [SYNTHESIS] Judge model failed: {e}. Using best single output.")
            # Fallback: Pick the longest/most complete response
            best = max(clean_outputs, key=lambda x: len(x.get("content", "")))
            final_content = best["content"]
            strategy = f"Fallback to best single output ({best.get('agent_name', 'unknown')})"

        latency = round(time.time() - start, 2)
        agents_contributed = [o.get("agent_name", "unknown") for o in clean_outputs]

        await audit_logger.log(
            event_type="SYNTHESIS",
            agent_name="synthesizer",
            action="merge_complete",
            details={
                "agents_contributed": agents_contributed,
                "strategy": strategy,
                "latency": latency,
            },
            workflow_id=workflow_id,
        )

        return {
            "content": final_content,
            "strategy": strategy,
            "agents_contributed": agents_contributed,
            "latency": latency,
        }


# Singleton
synthesis_engine = SynthesisEngine()
