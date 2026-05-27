import logging
import asyncio
from fastapi import APIRouter, HTTPException, Depends, BackgroundTasks
from app.models.requests import PlanRequest, PlanExecuteRequest
from app.services.orchestrator_service import orchestrator
from app.services import chat_service
from app.routes.deps import get_current_user_id

from app.database import get_db

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
        
        # Persist plan in MongoDB
        db = await get_db()
        plan_data["user_id"] = current_user_id
        plan_data["status"] = "pending"
        await db.plans.update_one(
            {"id": plan_data["id"]},
            {"$set": plan_data},
            upsert=True
        )
        
        return plan_data
    except Exception as e:
        logger.error(f"Error generating plan: {e}")
        raise HTTPException(status_code=500, detail="Failed to generate plan.")

@router.get("/{plan_id}")
async def get_plan(
    plan_id: str,
    current_user_id: str = Depends(get_current_user_id)
):
    """Retrieve details of a specific plan from MongoDB."""
    try:
        db = await get_db()
        plan = await db.plans.find_one({"id": plan_id})
        if not plan:
            raise HTTPException(status_code=404, detail="Plan not found")
        # Remove MongoDB _id object
        plan.pop("_id", None)
        return plan
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching plan {plan_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch plan.")

@router.get("/user/{user_id}")
async def get_user_plans(
    user_id: str,
    current_user_id: str = Depends(get_current_user_id)
):
    """Retrieve all plans for a specific user from MongoDB."""
    try:
        if user_id != current_user_id:
            raise HTTPException(status_code=403, detail="Access denied")
            
        db = await get_db()
        cursor = db.plans.find({"user_id": user_id}).sort("created_at", -1)
        plans = await cursor.to_list(length=100)
        for p in plans:
            p.pop("_id", None)
        return plans
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching user plans: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch plans.")

@router.post("/{plan_id}/execute")
async def execute_plan(
    plan_id: str,
    plan_data: dict,  # Renamed from request to avoid Starlette injection gotcha
    background_tasks: BackgroundTasks,
    current_user_id: str = Depends(get_current_user_id)
):
    """Execute an approved plan autonomously in the background."""
    try:
        # Save initial approval status in DB
        db = await get_db()
        await db.plans.update_one(
            {"id": plan_id},
            {"$set": {"is_approved": True, "status": "running"}},
            upsert=True
        )

        # We run the autonomous plan in the background so we don't block the HTTP response
        # The frontend will listen to Socket.io/WebSocket events for progress updates
        background_tasks.add_task(
            orchestrator.run_autonomous_plan,
            user_id=current_user_id,
            plan_id=plan_id,
            plan_data=plan_data
        )
        return {"status": "success", "message": f"Execution started for plan {plan_id}"}
    except Exception as e:
        logger.error(f"Error executing plan {plan_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to start execution.")
