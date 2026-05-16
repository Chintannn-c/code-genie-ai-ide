"""
Workflow Runtime Engine — The Brain Stem
==========================================
Persistent, stateful workflow execution engine that maintains
DAGs, checkpoints state to MongoDB, and supports resumable
long-running autonomous engineering workflows.

States: INITIALIZING → PLANNING → EXECUTING → WAITING → 
        REVIEWING → RETRYING → RECOVERING → COMPLETED → FAILED
"""

import asyncio
import logging
import time
import json
from typing import Dict, Any, List, Optional
from datetime import datetime, timezone
from enum import Enum

logger = logging.getLogger(__name__)


class WorkflowState(str, Enum):
    INITIALIZING = "initializing"
    PLANNING = "planning"
    EXECUTING = "executing"
    WAITING = "waiting_approval"
    REVIEWING = "reviewing"
    RETRYING = "retrying"
    RECOVERING = "recovering"
    COMPLETED = "completed"
    FAILED = "failed"
    QUARANTINED = "quarantined"


class WorkflowStep:
    """A single step in a workflow DAG."""

    def __init__(self, step_id: str, title: str, description: str,
                 assigned_agent: str = "coder", depends_on: List[str] = None):
        self.step_id = step_id
        self.title = title
        self.description = description
        self.assigned_agent = assigned_agent
        self.depends_on = depends_on or []
        self.status = "pending"
        self.output = ""
        self.error = ""
        self.retries = 0
        self.max_retries = 3
        self.started_at = None
        self.completed_at = None

    def to_dict(self) -> Dict[str, Any]:
        return {
            "step_id": self.step_id,
            "title": self.title,
            "description": self.description,
            "assigned_agent": self.assigned_agent,
            "depends_on": self.depends_on,
            "status": self.status,
            "output": self.output[:500] if self.output else "",
            "error": self.error,
            "retries": self.retries,
            "started_at": self.started_at,
            "completed_at": self.completed_at,
        }


class Workflow:
    """A complete workflow with state management and checkpointing."""

    def __init__(self, workflow_id: str, goal: str, user_id: str):
        self.workflow_id = workflow_id
        self.goal = goal
        self.user_id = user_id
        self.state = WorkflowState.INITIALIZING
        self.steps: List[WorkflowStep] = []
        self.created_at = datetime.now(timezone.utc).isoformat()
        self.updated_at = self.created_at
        self.completed_at = None
        self.metadata: Dict[str, Any] = {}
        self._state_history: List[Dict[str, Any]] = []

    def transition(self, new_state: WorkflowState, reason: str = ""):
        """Transitions workflow to a new state with history tracking."""
        old_state = self.state
        self.state = new_state
        self.updated_at = datetime.now(timezone.utc).isoformat()
        self._state_history.append({
            "from": old_state.value,
            "to": new_state.value,
            "reason": reason,
            "timestamp": self.updated_at,
        })
        logger.info(f"🔄 [WORKFLOW {self.workflow_id}] {old_state.value} → {new_state.value}: {reason}")

    def add_step(self, step: WorkflowStep):
        self.steps.append(step)

    def get_ready_steps(self) -> List[WorkflowStep]:
        """Returns steps whose dependencies are all completed."""
        completed_ids = {s.step_id for s in self.steps if s.status == "completed"}
        return [
            s for s in self.steps
            if s.status == "pending" and all(d in completed_ids for d in s.depends_on)
        ]

    def is_complete(self) -> bool:
        return all(s.status in ("completed", "skipped") for s in self.steps)

    def has_failed(self) -> bool:
        return any(s.status == "failed" and s.retries >= s.max_retries for s in self.steps)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "workflow_id": self.workflow_id,
            "goal": self.goal,
            "user_id": self.user_id,
            "state": self.state.value,
            "steps": [s.to_dict() for s in self.steps],
            "created_at": self.created_at,
            "updated_at": self.updated_at,
            "completed_at": self.completed_at,
            "state_history": self._state_history[-20:],
            "metadata": self.metadata,
        }


class WorkflowRuntime:
    """
    Persistent Workflow Runtime Engine.
    Manages workflow lifecycle, checkpointing, and recovery.
    """

    def __init__(self):
        self._active_workflows: Dict[str, Workflow] = {}
        self._db_collection = None
        self._total_workflows = 0
        self._completed_workflows = 0
        self._failed_workflows = 0

    async def initialize(self, db):
        """Connect to MongoDB for persistent workflow storage."""
        try:
            self._db_collection = db["workflows"]
            await self._db_collection.create_index("workflow_id", unique=True)
            await self._db_collection.create_index("user_id")
            await self._db_collection.create_index("state")
            logger.info("🧠 [WORKFLOW RUNTIME] MongoDB persistence initialized.")
        except Exception as e:
            logger.warning(f"⚠️ [WORKFLOW RUNTIME] MongoDB init failed (in-memory only): {e}")

    async def create_workflow(self, goal: str, user_id: str, steps_data: List[Dict] = None) -> Workflow:
        """Creates and registers a new workflow."""
        self._total_workflows += 1
        workflow_id = f"wf_{int(time.time())}_{self._total_workflows}"

        workflow = Workflow(workflow_id, goal, user_id)

        if steps_data:
            for step_data in steps_data:
                step = WorkflowStep(
                    step_id=step_data.get("id", f"step_{len(workflow.steps) + 1}"),
                    title=step_data.get("title", "Untitled"),
                    description=step_data.get("description", ""),
                    assigned_agent=step_data.get("assigned_agent", "coder"),
                    depends_on=step_data.get("depends_on", []),
                )
                workflow.add_step(step)

        workflow.transition(WorkflowState.PLANNING, "Workflow created")
        self._active_workflows[workflow_id] = workflow

        await self._checkpoint(workflow)
        return workflow

    async def execute_workflow(self, workflow_id: str) -> Workflow:
        """
        Executes a workflow by running ready steps in dependency order.
        Steps with satisfied dependencies run in parallel.
        """
        workflow = self._active_workflows.get(workflow_id)
        if not workflow:
            raise ValueError(f"Workflow {workflow_id} not found")

        workflow.transition(WorkflowState.EXECUTING, "Execution started")

        from .audit_logger import audit_logger

        while not workflow.is_complete() and not workflow.has_failed():
            ready_steps = workflow.get_ready_steps()

            if not ready_steps:
                if workflow.has_failed():
                    workflow.transition(WorkflowState.FAILED, "Step failures exceeded retry limit")
                    break
                # No ready steps and not complete = deadlock
                logger.error(f"🛑 [WORKFLOW] Deadlock detected in {workflow_id}")
                workflow.transition(WorkflowState.FAILED, "Deadlock: no ready steps")
                break

            # Execute ready steps in parallel
            tasks = [self._execute_step(workflow, step) for step in ready_steps]

            try:
                await asyncio.wait_for(
                    asyncio.gather(*tasks, return_exceptions=True),
                    timeout=60.0,
                )
            except asyncio.TimeoutError:
                logger.error(f"🛑 [WORKFLOW] Step batch timed out in {workflow_id}")
                for step in ready_steps:
                    if step.status == "running":
                        step.status = "failed"
                        step.error = "Execution timeout"

            await self._checkpoint(workflow)

        if workflow.is_complete():
            workflow.transition(WorkflowState.COMPLETED, "All steps finished")
            workflow.completed_at = datetime.now(timezone.utc).isoformat()
            self._completed_workflows += 1
        elif workflow.has_failed():
            self._failed_workflows += 1

        await self._checkpoint(workflow)

        await audit_logger.log(
            "COMPLETE" if workflow.is_complete() else "ERROR",
            "workflow_runtime",
            f"workflow_{workflow.state.value}",
            {"workflow_id": workflow_id, "steps": len(workflow.steps)},
            user_id=workflow.user_id,
            workflow_id=workflow_id,
        )

        return workflow

    async def _execute_step(self, workflow: Workflow, step: WorkflowStep):
        """Executes a single workflow step."""
        step.status = "running"
        step.started_at = datetime.now(timezone.utc).isoformat()

        try:
            from .orchestrator_service import orchestrator

            # Use the orchestrator's collaborative engine for each step
            result = await orchestrator.get_collaborative_response(
                prompt=f"STEP: {step.title}\nDETAIL: {step.description}\nCONTEXT: Part of workflow goal: {workflow.goal}",
                user_id=workflow.user_id,
            )

            step.output = result.get("answer", "")
            step.status = "completed"
            step.completed_at = datetime.now(timezone.utc).isoformat()

        except Exception as e:
            step.retries += 1
            if step.retries >= step.max_retries:
                step.status = "failed"
                step.error = str(e)
            else:
                step.status = "pending"  # Will be retried
                step.error = f"Retry {step.retries}/{step.max_retries}: {e}"
                logger.warning(f"🔄 [WORKFLOW] Step {step.step_id} retry {step.retries}: {e}")

    async def _checkpoint(self, workflow: Workflow):
        """Persists workflow state to MongoDB."""
        if self._db_collection is not None:
            try:
                await self._db_collection.update_one(
                    {"workflow_id": workflow.workflow_id},
                    {"$set": workflow.to_dict()},
                    upsert=True,
                )
            except Exception as e:
                logger.error(f"❌ [WORKFLOW] Checkpoint failed: {e}")

    async def resume_workflow(self, workflow_id: str) -> Optional[Workflow]:
        """Resumes a previously interrupted workflow from its last checkpoint."""
        if self._db_collection is None:
            return None

        try:
            doc = await self._db_collection.find_one({"workflow_id": workflow_id})
            if not doc:
                return None

            workflow = Workflow(doc["workflow_id"], doc["goal"], doc["user_id"])
            workflow.state = WorkflowState(doc.get("state", "failed"))
            workflow.created_at = doc.get("created_at", "")
            workflow.updated_at = doc.get("updated_at", "")

            for step_data in doc.get("steps", []):
                step = WorkflowStep(
                    step_id=step_data["step_id"],
                    title=step_data["title"],
                    description=step_data["description"],
                    assigned_agent=step_data.get("assigned_agent", "coder"),
                    depends_on=step_data.get("depends_on", []),
                )
                step.status = step_data.get("status", "pending")
                step.output = step_data.get("output", "")
                step.retries = step_data.get("retries", 0)
                workflow.add_step(step)

            self._active_workflows[workflow_id] = workflow
            workflow.transition(WorkflowState.RECOVERING, "Resumed from checkpoint")

            logger.info(f"🔄 [WORKFLOW] Resumed workflow {workflow_id}")
            return workflow

        except Exception as e:
            logger.error(f"❌ [WORKFLOW] Resume failed: {e}")
            return None

    def get_active_workflows(self, user_id: str = None) -> List[Dict]:
        """Returns all active workflows, optionally filtered by user."""
        workflows = self._active_workflows.values()
        if user_id:
            workflows = [w for w in workflows if w.user_id == user_id]
        return [w.to_dict() for w in workflows]

    def get_stats(self) -> Dict[str, Any]:
        return {
            "total_created": self._total_workflows,
            "completed": self._completed_workflows,
            "failed": self._failed_workflows,
            "active": len(self._active_workflows),
            "active_workflows": [
                {"id": w.workflow_id, "state": w.state.value, "goal": w.goal[:80]}
                for w in self._active_workflows.values()
            ],
        }


# Singleton
workflow_runtime = WorkflowRuntime()
