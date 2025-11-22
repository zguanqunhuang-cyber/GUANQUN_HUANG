from __future__ import annotations

import asyncio
from typing import Any

from fastapi import WebSocket


class MessageHub:
    def __init__(self) -> None:
        self.connections: dict[str, set[WebSocket]] = {}
        self.connection_index: dict[WebSocket, str] = {}
        self.lock = asyncio.Lock()

    async def connect(self, websocket: WebSocket, user_id: str) -> None:
        await websocket.accept()
        async with self.lock:
            sockets = self.connections.setdefault(user_id, set())
            sockets.add(websocket)
            self.connection_index[websocket] = user_id

    async def disconnect(self, websocket: WebSocket) -> None:
        async with self.lock:
            user_id = self.connection_index.pop(websocket, None)
            if user_id is None:
                return
            sockets = self.connections.get(user_id)
            if sockets is None:
                return
            sockets.discard(websocket)
            if not sockets:
                self.connections.pop(user_id, None)

    async def broadcast(self, target_user_ids: list[str], payload: dict[str, Any]) -> None:
        unique_ids = set(target_user_ids)
        async with self.lock:
            targets: list[WebSocket] = []
            for user_id in unique_ids:
                sockets = self.connections.get(user_id)
                if sockets:
                    targets.extend(sockets)

        for websocket in targets:
            try:
                await websocket.send_json(payload)
            except Exception:
                await self.disconnect(websocket)


message_hub = MessageHub()
