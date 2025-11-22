from fastapi import APIRouter, Depends

from ..schemas import NotificationResponse, OfflineMessagePayload
from ..services.notification_service import NotificationService
from ..supabase_client import get_supabase

router = APIRouter(prefix="/notify", tags=["notifications"])


@router.post("/offline-message", response_model=NotificationResponse)
async def offline_message(
    payload: OfflineMessagePayload,
    service: NotificationService = Depends(lambda: NotificationService(get_supabase())),
) -> NotificationResponse:
    delivered = await service.handle_offline_message(payload)
    return NotificationResponse(delivered=delivered, queued=0)
