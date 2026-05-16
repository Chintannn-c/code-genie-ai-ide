import logging
import time
from typing import Dict, List, Any
from fastapi import WebSocket

logger = logging.getLogger(__name__)

class ConnectionManager:
    def __init__(self):
        # user_id -> list of active WebSockets
        self.active_connections: Dict[str, List[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, user_id: str):
        await websocket.accept()
        if user_id not in self.active_connections:
            self.active_connections[user_id] = []
        self.active_connections[user_id].append(websocket)
        logger.info(f"User {user_id} connected. Total connections for user: {len(self.active_connections[user_id])}")

    def disconnect(self, websocket: WebSocket, user_id: str):
        if user_id in self.active_connections:
            if websocket in self.active_connections[user_id]:
                self.active_connections[user_id].remove(websocket)
            if not self.active_connections[user_id]:
                del self.active_connections[user_id]
        logger.info(f"User {user_id} disconnected.")

    async def broadcast_to_user(self, user_id: str, message: dict, exclude_websocket: WebSocket = None):
        """Send a message to all devices of a specific user."""
        if user_id in self.active_connections:
            for connection in self.active_connections[user_id]:
                if connection != exclude_websocket:
                    try:
                        await connection.send_json(message)
                    except Exception as e:
                        logger.error(f"Error broadcasting to {user_id}: {e}")
                        # We don't remove here, the disconnect handler will catch it

    async def send_heartbeat(self):
        """Send a ping to all active connections to prevent timeouts."""
        for user_id, connections in list(self.active_connections.items()):
            for connection in connections:
                try:
                    await connection.send_json({"type": "ping", "timestamp": time.time()})
                except Exception:
                    # Connection likely closed
                    pass

# Global instance
manager = ConnectionManager()
