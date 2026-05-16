import logging
import asyncio
from fastapi import APIRouter, HTTPException, Depends, BackgroundTasks
from app.models.requests import PlanRequest, PlanExecuteRequest
from app.services.orchestrator_service import orchestrator
from app.services import chat_service
from app.routes.deps import get_current_user_id

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/plan", tags=["planning"])

@router.post("")
async def generate_plan(
    request: PlanRequest,
    current_user_id: str = Depends(get_current_user_id)
):
    """Generate a multi-step execution plan based on the user's prompt."""
    try:
        history = []
        if request.chat_id:
            # Optionally attach to a chat history if provided
            history = await chat_service.get_chat_context(request.chat_id, max_messages=10)
            
        plan_data = await orchestrator.generate_plan(
            prompt=request.prompt,
            history=history
        )
        return plan_data
    except Exception as e:
        logger.error(f"Error generating plan: {e}")
        raise HTTPException(status_code=500, detail="Failed to generate plan.")

@router.post("/{plan_id}/execute")
async def execute_plan(
    plan_id: str,
    request: dict,  # FastAPI allows arbitrary dicts for body, or we can use the explicit Request Model
    background_tasks: BackgroundTasks,
    current_user_id: str = Depends(get_current_user_id)
):
    """Execute an approved plan autonomously in the background."""
    try:
        # We run the autonomous plan in the background so we don't block the HTTP response
        # The frontend will listen to Socket.io events for progress updates
        background_tasks.add_task(
            orchestrator.run_autonomous_plan,
            user_id=current_user_id,
            plan_id=plan_id,
            plan_data=request
        )
        return {"status": "success", "message": f"Execution started for plan {plan_id}"}
    except Exception as e:
        logger.error(f"Error executing plan {plan_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to start execution.")
