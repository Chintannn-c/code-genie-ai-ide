import logging
import time
from typing import Dict, List, Any
from fastapi import WebSocket

logger = logging.getLogger(__name__)

class ConnectionManager:
    def __init__(self):
        # user_id -> list of active WebSockets
        self.active_connections: Dict[str, List[WebSocket]] = {}
        # websocket -> token_hash string
        self.websocket_tokens: Dict[WebSocket, str] = {}

    async def connect(self, websocket: WebSocket, user_id: str, token_hash: str = None):
        await websocket.accept()
        if user_id not in self.active_connections:
            self.active_connections[user_id] = []
        self.active_connections[user_id].append(websocket)
        if token_hash:
            self.websocket_tokens[websocket] = token_hash
        logger.info(f"User {user_id} connected. Total connections for user: {len(self.active_connections[user_id])}")

    def disconnect(self, websocket: WebSocket, user_id: str):
        if user_id in self.active_connections:
            if websocket in self.active_connections[user_id]:
                self.active_connections[user_id].remove(websocket)
            if not self.active_connections[user_id]:
                del self.active_connections[user_id]
        if websocket in self.websocket_tokens:
            del self.websocket_tokens[websocket]
        logger.info(f"User {user_id} disconnected.")

    async def disconnect_session(self, token_hash: str):
        """Find the WebSocket associated with a token hash and tear it down cleanly."""
        for ws, t_hash in list(self.websocket_tokens.items()):
            if t_hash == token_hash:
                try:
                    logger.info(f"🔌 [WEBSOCKET] Remote revocation: closing WS connection for token hash {token_hash}")
                    await ws.send_json({"type": "session_revoked", "message": "This session has been revoked remotely."})
                    await ws.close(code=1008)  # Policy Violation / Forced Logout
                except Exception as e:
                    logger.error(f"Error closing WebSocket on session revocation: {e}")

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
