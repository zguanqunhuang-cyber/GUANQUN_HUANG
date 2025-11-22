from datetime import datetime, timezone
from enum import Enum
from typing import List

from pydantic import BaseModel, Field, field_validator


class OfflineMessagePayload(BaseModel):
    chat_id: str
    recipient_ids: List[str]
    preview: str

    @field_validator("recipient_ids")
    @classmethod
    def ensure_non_empty(cls, value: List[str]) -> List[str]:
        if not value:
            raise ValueError("recipient_ids cannot be empty")
        return value


class NotificationRecord(BaseModel):
    chat_id: str
    recipient_id: str
    preview: str
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class NotificationResponse(BaseModel):
    delivered: int
    queued: int


class ProfileSummary(BaseModel):
    id: str
    display_name: str
    phone: str | None = None
    avatar_url: str | None = None
    status_message: str | None = None


class FriendRequestStatus(str, Enum):
    pending = "pending"
    accepted = "accepted"
    rejected = "rejected"


class FriendRequestModel(BaseModel):
    id: str
    requester_id: str
    addressee_id: str
    status: FriendRequestStatus
    created_at: datetime
    requester: ProfileSummary | None = None
    addressee: ProfileSummary | None = None


class FriendRequestCreatePayload(BaseModel):
    phone: str
    requester_id: str


class FriendRequestRespondPayload(BaseModel):
    request_id: str
    accept: bool = Field(..., description="True 表示同意，False 表示拒绝")
    responder_id: str


class FriendRequestRole(str, Enum):
    incoming = "incoming"
    outgoing = "outgoing"


class FriendRequestListResponse(BaseModel):
    requests: List[FriendRequestModel]


class FriendsListResponse(BaseModel):
    friends: List[ProfileSummary]


class ChatCreatePayload(BaseModel):
    initiator_id: str
    participant_id: str


class ChatSummaryModel(BaseModel):
    id: str
    title: str
    last_message_preview: str | None = None
    last_message_at: datetime | None = None
    unread_count: int = 0
    participant_ids: List[str]


class ChatCreateResponse(BaseModel):
    chat: ChatSummaryModel


class SendMessagePayload(BaseModel):
    sender_id: str
    content: str


class MessageModel(BaseModel):
    id: str
    chat_id: str
    sender_id: str
    sender_name: str | None = None
    content: str
    created_at: datetime


class MessagesResponse(BaseModel):
    messages: List[MessageModel]
