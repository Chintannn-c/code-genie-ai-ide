"""
Context Manager Agent — Token Budget & RAG Optimization
"""
import logging
from typing import Dict, Any, List

logger = logging.getLogger(__name__)

class ContextManager:
    """Manages token budgets, context compression, and RAG chunk prioritization."""

    def __init__(self, max_context_tokens: int = 6000):
        self.max_context_tokens = max_context_tokens
        self._approx_chars_per_token = 4

    def optimize_context(self, rag_chunks: List[Dict], prompt: str, history: List[Dict] = None) -> str:
        """Builds an optimized context string within the token budget."""
        history = history or []
        budget_chars = self.max_context_tokens * self._approx_chars_per_token

        # Reserve space for prompt and history
        prompt_chars = len(prompt)
        history_chars = sum(len(m.get("content", "")) for m in history[-4:])  # Last 4 messages
        available = budget_chars - prompt_chars - history_chars

        if available <= 0:
            return ""

        # Sort RAG chunks by relevance (shorter distance = more relevant)
        # ChromaDB returns them in order, so just cap by budget
        context_parts = []
        used = 0
        for chunk in rag_chunks:
            content = chunk.get("content", "")
            path = chunk.get("path", "unknown")
            entry = f"--- {path} ---\n{content}\n"
            if used + len(entry) > available:
                break
            context_parts.append(entry)
            used += len(entry)

        return "\n".join(context_parts)

    def compress_history(self, history: List[Dict], max_messages: int = 6) -> List[Dict]:
        """Keeps only the most recent messages to prevent token overflow."""
        if len(history) <= max_messages:
            return history
        # Keep system message (if any) + last N messages
        system_msgs = [m for m in history if m.get("role") == "system"]
        recent = history[-max_messages:]
        return system_msgs + recent

    def estimate_tokens(self, text: str) -> int:
        return len(text) // self._approx_chars_per_token

context_manager = ContextManager()
