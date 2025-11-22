from fastapi import FastAPI

from .config import settings
from .routes import notifications, realtime_ws, social

app = FastAPI(title="Chats Backend", version="0.1.0")
app.include_router(notifications.router)
app.include_router(social.router)
app.include_router(realtime_ws.router)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok", "port": str(settings.backend_port)}
