import logging
from typing import List, Dict, Any
from . import gemini_service as gemini_mod

logger = logging.getLogger(__name__)

class SynthesisEngine:
    """
    Merging Engine for Code Genie 2.0.
    Consolidates outputs from parallel agents (Planner, Coder, Auditor) into a single response.
    """
    def __init__(self):
        self.synthesis_count = 0

    async def synthesize(self, prompt: str, agent_outputs: List[Dict[str, Any]], workflow_id: str) -> Dict[str, Any]:
        """Uses a 'Judge' LLM to merge agent contributions."""
        self.synthesis_count += 1
        
        # Prepare the synthesis prompt
        merged_context = ""
        agents_participated = []
        for out in agent_outputs:
            agent_name = out.get("agent_name", "Unknown")
            agents_participated.append(agent_name)
            content = out.get("content", "")
            merged_context += f"--- AGENT: {agent_name} ---\n{content}\n\n"

        synthesis_prompt = f"""
        YOU ARE THE 'JUDGE' AGENT FOR CODE GENIE 2.0.
        YOUR TASK: Merge the following agent outputs into a single, high-quality, comprehensive response.
        
        ORIGINAL USER REQUEST: {prompt}
        
        AGENT CONTRIBUTIONS:
        {merged_context}
        
        INSTRUCTIONS:
        1. Eliminate redundancies.
        2. Resolve contradictions (favor the Auditor/Security agent if conflicts arise).
        3. Maintain a professional, engineering-focused tone.
        4. If code is provided, ensure it's functional and complete.
        
        FINAL CONSOLIDATED RESPONSE:
        """

        try:
            # Use Gemini as the primary synthesizer
            final_content = await gemini_mod.generate([{"role": "user", "parts": [{"text": synthesis_prompt}]}])
            return {
                "content": final_content,
                "strategy": "collaborative_synthesis",
                "agents_contributed": agents_participated
            }
        except Exception as e:
            logger.error(f"Synthesis failed: {e}")
            return {
                "content": "⚠️ Synthesis failed. Returning raw agent output.",
                "strategy": "fallback_raw",
                "agents_contributed": agents_participated
            }

# Global instance
synthesis_engine = SynthesisEngine()
