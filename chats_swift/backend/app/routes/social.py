from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query

from ..schemas import (
    ChatCreatePayload,
    ChatCreateResponse,
    FriendRequestCreatePayload,
    FriendRequestListResponse,
    FriendRequestModel,
    FriendRequestRespondPayload,
    FriendRequestRole,
    FriendsListResponse,
    MessageModel,
    MessagesResponse,
    SendMessagePayload,
)
from ..services.social_service import SocialService
from ..supabase_client import get_supabase


router = APIRouter(prefix="/social", tags=["social"])


def get_social_service() -> SocialService:
    return SocialService(get_supabase())


@router.post("/friends/request", response_model=FriendRequestModel)
async def create_friend_request(
    payload: FriendRequestCreatePayload,
    service: SocialService = Depends(get_social_service),
) -> FriendRequestModel:
    try:
        return await service.create_friend_request(payload)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.post("/friends/respond", response_model=FriendRequestModel)
async def respond_friend_request(
    payload: FriendRequestRespondPayload,
    service: SocialService = Depends(get_social_service),
) -> FriendRequestModel:
    try:
        return await service.respond_friend_request(payload)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.get("/friends/requests", response_model=FriendRequestListResponse)
async def list_friend_requests(
    user_id: UUID = Query(..., description="当前用户 ID"),
    role: FriendRequestRole = Query(..., description="incoming/outgoing"),
    service: SocialService = Depends(get_social_service),
) -> FriendRequestListResponse:
    return await service.list_friend_requests(user_id, role)


@router.get("/friends/list", response_model=FriendsListResponse)
async def list_friends(
    user_id: UUID = Query(..., description="当前用户 ID"),
    service: SocialService = Depends(get_social_service),
) -> FriendsListResponse:
    return await service.list_friends(user_id)


@router.post("/chats", response_model=ChatCreateResponse)
async def create_chat(
    payload: ChatCreatePayload,
    service: SocialService = Depends(get_social_service),
) -> ChatCreateResponse:
    chat = await service.create_chat(payload)
    return ChatCreateResponse(chat=chat)


@router.post("/chats/{chat_id}/messages", response_model=MessageModel)
async def send_message(
    chat_id: UUID,
    payload: SendMessagePayload,
    service: SocialService = Depends(get_social_service),
) -> MessageModel:
    return await service.send_message(chat_id, payload)


@router.get("/chats/{chat_id}/messages", response_model=MessagesResponse)
async def list_messages(
    chat_id: UUID,
    service: SocialService = Depends(get_social_service),
) -> MessagesResponse:
    return await service.list_messages(chat_id)
