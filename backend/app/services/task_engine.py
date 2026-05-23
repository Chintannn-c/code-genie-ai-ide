import asyncio
import logging
import time
from typing import Dict, Any, Callable
from uuid import uuid4
from datetime import datetime, timezone
from app.services.socket_manager import manager as socket_manager

logger = logging.getLogger(__name__)

class TaskState:
    QUEUED = "queued"
    PREPARING = "preparing"
    INDEXING = "indexing"
    RETRIEVING_CONTEXT = "retrieving_context"
    GENERATING = "generating"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"
    RECOVERING = "recovering"

class TaskEngine:
    """
    Central Asynchronous Task Orchestrator.
    Manages long-running background tasks (like file indexing) with state tracking,
    watchdog timeouts, and WebSocket broadcasting.
    """
    def __init__(self):
        self.queue = asyncio.Queue()
        self.active_tasks: Dict[str, Dict[str, Any]] = {}
        self._workers: list[asyncio.Task] = []
        self._watchdog: asyncio.Task | None = None
        
    async def start(self, num_workers: int = 3):
        """Start background workers and watchdog."""
        if not self._workers:
            for i in range(num_workers):
                worker = asyncio.create_task(self._worker_loop(i))
                self._workers.append(worker)
            self._watchdog = asyncio.create_task(self._watchdog_loop())
            logger.info(f"TaskEngine started with {num_workers} workers.")

    async def stop(self):
        """Stop workers."""
        for worker in self._workers:
            worker.cancel()
        if self._watchdog:
            self._watchdog.cancel()
        await asyncio.gather(*self._workers, self._watchdog, return_exceptions=True)
        self._workers.clear()
        logger.info("TaskEngine stopped.")

    async def submit_task(self, user_id: str, type: str, coro_func: Callable, *args, **kwargs) -> str:
        """Submit an async task to the queue."""
        task_id = str(uuid4())
        self.active_tasks[task_id] = {
            "task_id": task_id,
            "user_id": user_id,
            "type": type,
            "state": TaskState.QUEUED,
            "progress": 0.0,
            "message": "Queued for processing",
            "created_at": time.time(),
            "updated_at": time.time(),
            "coro_func": coro_func,
            "args": args,
            "kwargs": kwargs,
        }
        await self.queue.put(task_id)
        await self._broadcast_state(task_id)
        return task_id

    async def update_task_state(self, task_id: str, state: str, message: str = "", progress: float = 0.0):
        """Update task state and broadcast to UI."""
        if task_id in self.active_tasks:
            task = self.active_tasks[task_id]
            task["state"] = state
            task["message"] = message
            task["progress"] = progress
            task["updated_at"] = time.time()
            await self._broadcast_state(task_id)

    async def _broadcast_state(self, task_id: str):
        """Broadcast state to the specific user via WebSocket."""
        task = self.active_tasks.get(task_id)
        if task and "user_id" in task:
            payload = {
                "type": "task_state_update",
                "task_id": task_id,
                "task_type": task["type"],
                "state": task["state"],
                "message": task["message"],
                "progress": task["progress"],
                "timestamp": datetime.now(timezone.utc).isoformat()
            }
            await socket_manager.broadcast_to_user(task["user_id"], payload)

    async def _worker_loop(self, worker_id: int):
        """Worker to consume tasks from the queue."""
        while True:
            try:
                task_id = await self.queue.get()
                task = self.active_tasks.get(task_id)
                if not task or task["state"] == TaskState.CANCELLED:
                    self.queue.task_done()
                    continue

                await self.update_task_state(task_id, TaskState.PREPARING, "Initializing worker context...")
                
                coro_func = task["coro_func"]
                args = task.get("args", [])
                kwargs = task.get("kwargs", {})
                
                try:
                    # Pass task_id so the function can report progress back
                    kwargs["task_id"] = task_id
                    # Wrap execution in a generous global timeout (e.g., 10 mins for heavy embeddings)
                    await asyncio.wait_for(coro_func(*args, **kwargs), timeout=600.0)
                    
                    await self.update_task_state(task_id, TaskState.COMPLETED, "Task completed successfully", 1.0)
                except asyncio.TimeoutError:
                    logger.error(f"[TaskEngine] Task {task_id} timed out.")
                    await self.update_task_state(task_id, TaskState.FAILED, "Task timed out during execution.")
                except Exception as e:
                    logger.error(f"[TaskEngine] Task {task_id} failed: {e}")
                    await self.update_task_state(task_id, TaskState.FAILED, f"Task failed: {str(e)}")
                finally:
                    # Keep record for a short time, then we could prune it. Let's keep it in active_tasks for now.
                    self.queue.task_done()
            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error(f"[TaskEngine] Worker {worker_id} encountered error: {e}")

    async def _watchdog_loop(self):
        """Monitors active tasks for stuck states."""
        while True:
            try:
                await asyncio.sleep(60)
                now = time.time()
                for task_id, task in list(self.active_tasks.items()):
                    if task["state"] not in [TaskState.COMPLETED, TaskState.FAILED, TaskState.CANCELLED]:
                        # If a task hasn't updated its state in 15 minutes, mark as failed
                        if now - task["updated_at"] > 900:
                            logger.warning(f"[TaskEngine] Watchdog killing stuck task {task_id}")
                            await self.update_task_state(task_id, TaskState.FAILED, "Watchdog timeout: Task stopped responding.")
            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error(f"[TaskEngine] Watchdog error: {e}")

task_engine = TaskEngine()
