import asyncio

from fastapi import APIRouter, WebSocket, WebSocketDisconnect, status

from ..realtime import message_hub


router = APIRouter(prefix="/ws", tags=["realtime"])


@router.websocket("/messages")
async def messages_socket(websocket: WebSocket):
    user_id = websocket.query_params.get("user_id")
    if not user_id:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason="user_id is required")
        return

    await message_hub.connect(websocket, user_id)
    try:
        while True:
            await asyncio.sleep(3600)
    except WebSocketDisconnect:
        pass
    finally:
        await message_hub.disconnect(websocket)
