import logging
import json
import re
from fastapi import APIRouter, Depends, HTTPException, Request
from app.models.requests import CriticRequest
from app.routes.deps import get_current_user_id
from app.services import gemini_service
from app.limiter import limiter

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api", tags=["critic"])

def parse_critic_response(text: str) -> dict:
    try:
        # Clean potential whitespace/markdown
        cleaned = text.strip()
        if cleaned.startswith("```"):
            cleaned = re.sub(r'^```(?:json)?', '', cleaned)
            cleaned = re.sub(r'```$', '', cleaned)
            cleaned = cleaned.strip()
        return json.loads(cleaned)
    except Exception as e:
        logger.warning(f"Failed to parse AI Critic JSON directly: {e}. Text: {text}")
        # Try finding json object
        try:
            match = re.search(r'\{.*\}', text, re.DOTALL)
            if match:
                return json.loads(match.group(0))
        except Exception:
            pass
            
    return {
        "security_issues": [],
        "performance_notes": [],
        "suggestions": [{"type": "info", "description": "Detailed review parsing failed. Raw response: " + text[:500]}],
        "overall_score": 7,
        "summary": text[:300] + "..." if len(text) > 300 else text
    }

@router.post("/critic")
@limiter.limit("20/minute")
async def critique_code(request: Request, body_req: CriticRequest, current_user_id: str = Depends(get_current_user_id)):
    """Dual-pass AI critic review on generated code."""
    critic_prompt = f"""You are a Senior Security Auditor and Performance Engineer.
    Analyze the following code written in {body_req.language} for:
    1. Security vulnerabilities (SQL injections, XSS, hardcoded secrets, weak crypto, path traversal, IDOR)
    2. Performance bottlenecks (unnecessary database calls, memory leaks, unclosed files/connections, poor time complexity)
    3. Best practice violations & clean code principles
    4. Memory leaks or resource issues

    You MUST respond with a valid raw JSON object. Do not include any explanations outside the JSON object.
    
    The JSON object MUST contain the following keys exactly:
    - security_issues: a list of objects, each with:
      - severity: string, either "high", "medium", or "low"
      - description: string describing the issue and how to fix it
      - line: integer, approximate line number of the issue or 0 if general
    - performance_notes: a list of objects, each with:
      - impact: string, either "high", "medium", or "low"
      - description: string detailing the performance bottleneck and solution
    - suggestions: a list of objects, each with:
      - type: string, either "improvement", "warning", or "info"
      - description: string
    - overall_score: an integer from 1 to 10 where 10 is perfectly secure/performant and 1 is highly critical
    - summary: a brief string summary of the review

    Code to analyze:
    ```{body_req.language}
    {body_req.code}
    ```
    """

    contents = [{"role": "user", "parts": [{"text": critic_prompt}]}]
    try:
        raw_response = await gemini_service.generate(contents)
        result = parse_critic_response(raw_response)
        return result
    except Exception as e:
        logger.error(f"Error in AI Critic: {e}")
        raise HTTPException(status_code=500, detail=f"Critic pipeline failed: {str(e)}")
