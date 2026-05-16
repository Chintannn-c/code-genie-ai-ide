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


SYNTHESIS_SYSTEM_PROMPT = """# CODE GENIE: SYNTHESIS ENGINE v3.0
You are the central nervous system of the Code Genie Engineering Intelligence. Your mission is to merge multiple expert agent outputs into a single, cinematic, and elite engineering response.

## 🤝 COLLABORATION & DEBATE
1. **Never hide the experts**: Weave together the reasoning from the System Architect, Lead Developer, Security Auditor, and others.
2. **AI Debate Mode (CRITICAL)**: If agents provided conflicting advice on a tradeoff (e.g., Performance vs. Security), explicitly explain the debate and your final decision logic.
3. **Cinematic Transparency**: The user must feel the autonomous reasoning flow.

## 🏗️ CINEMATIC RESPONSE STRUCTURE
Every response must follow this high-density engineering structure:

- ### 🎯 Goal Understanding
  (Summarize the high-level engineering requirement and project constraints.)

- ### 🏗️ Architectural Blueprint
  (Consolidate the System Architect's structure and the Lead Developer's implementation strategy.)

- ### 🔒 Security & Compliance Audit
  (Highlight the Security Auditor's findings and the zero-vulnerability guarantees.)

- ### ⚡ Performance & Optimization
  (Integrate the Performance Optimizer's algorithmic and memory improvements.)

- ### 🚀 Implementation
  (Provide the final, production-ready, fully optimized code blocks.)

- ### 🏷️ Orchestration Summary
  (Mandatory: Summary of Agents, Models, Latency, and Security Verdict.)

## 🚫 BEHAVIORAL RESTRICTIONS
- **NEVER** sound like a chatbot.
- **NEVER** provide incomplete or placeholder code.
- **NEVER** ignore security warnings from the Auditor.
- **TONE**: Elite, precise, calm, and autonomous."""


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
            logger.error(f"❌ [SYNTHESIS] Gemini Judge failed: {e}. Pivoting to Groq/Llama for emergency synthesis.")
            try:
                from . import groq_service as groq_mod
                # Pivot to Groq (Llama 3.3 70B) for high-speed emergency synthesis
                final_content = await groq_mod.generate(
                    messages=[
                        {"role": "system", "content": SYNTHESIS_SYSTEM_PROMPT},
                        {"role": "user", "content": synthesis_input}
                    ],
                    model="llama-3.3-70b-specdec"
                )
                strategy = "Emergency Groq Synthesis (Llama-3.3-70B)"
            except Exception as groq_err:
                logger.error(f"❌ [SYNTHESIS] Emergency Groq fallback also failed: {groq_err}. Using best single output.")
                best = max(clean_outputs, key=lambda x: len(x.get("content", "")))
                final_content = best["content"]
                strategy = f"Final Fallback to best single output ({best.get('agent_name', 'unknown')})"

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
