from __future__ import annotations

import asyncio
from datetime import datetime, timezone
from typing import List
from uuid import UUID, uuid4

from supabase import Client

from ..realtime import message_hub
from ..schemas import (
    ChatCreatePayload,
    ChatCreateResponse,
    ChatSummaryModel,
    FriendRequestCreatePayload,
    FriendRequestListResponse,
    FriendRequestModel,
    FriendRequestRespondPayload,
    FriendRequestRole,
    FriendsListResponse,
    MessageModel,
    MessagesResponse,
    ProfileSummary,
    SendMessagePayload,
)

_SELECT_FRIEND_REQUEST = (
    "*,requester:requester_id(id,display_name,phone,avatar_url,status_message),"
    "addressee:addressee_id(id,display_name,phone,avatar_url,status_message)"
)
PROFILE_FIELDS = "id,display_name,phone,avatar_url,status_message,friend_ids"
CHAT_SUMMARY_FIELDS = "id,title,last_message_preview,last_message_at,unread_count,participant_ids"
MESSAGE_FIELDS = "id,chat_id,sender_id,content,created_at"


class SocialService:
    def __init__(self, client: Client) -> None:
        self.client = client

    async def create_friend_request(self, payload: FriendRequestCreatePayload) -> FriendRequestModel:
        requester_id = str(payload.requester_id).lower()
        target_profile = await self._profile_by_phone(payload.phone)
        if target_profile is None:
            raise ValueError("用户不存在")
        target_id = target_profile["id"].lower()

        if target_id == requester_id:
            raise ValueError("不能添加自己为好友")

        def _upsert() -> dict:
            response = (
                self.client.table("friend_requests")
                .upsert(
                    {
                        "requester_id": requester_id,
                        "addressee_id": target_id,
                        "status": "pending",
                    },
                    on_conflict="requester_id,addressee_id",
                )
                .execute()
            )
            return response.data[0]

        row = await asyncio.to_thread(_upsert)
        return await self._fetch_request_by_id(row["id"])

    async def respond_friend_request(self, payload: FriendRequestRespondPayload) -> FriendRequestModel:
        request = await self._fetch_request_by_id(payload.request_id)
        if request.addressee_id.lower() != payload.responder_id.lower():
            raise ValueError("只有被邀请人才能处理请求")

        def _update_request() -> dict:
            response = (
                self.client.table("friend_requests")
                .update({"status": "accepted" if payload.accept else "rejected"})
                .eq("id", str(payload.request_id))
                .execute()
            )
            return response.data[0]

        _ = await asyncio.to_thread(_update_request)
        if payload.accept:
            await self._link_profiles(UUID(request.requester_id), UUID(request.addressee_id))
        return await self._fetch_request_by_id(payload.request_id)

    async def list_friend_requests(self, user_id: UUID, role: FriendRequestRole) -> FriendRequestListResponse:
        def _query() -> List[dict]:
            query = self.client.table("friend_requests").select(_SELECT_FRIEND_REQUEST)
            if role == FriendRequestRole.incoming:
                query = query.eq("addressee_id", str(user_id))
            else:
                query = query.eq("requester_id", str(user_id))
            return (
                query
                .eq("status", "pending")
                .order("created_at", desc=True)
                .execute()
                .data
            )

        rows = await asyncio.to_thread(_query)
        requests = [FriendRequestModel.model_validate(row) for row in rows]
        return FriendRequestListResponse(requests=requests)

    async def list_friends(self, user_id: UUID) -> FriendsListResponse:
        def _query() -> List[dict]:
            return (
                self.client.table("profiles")
                .select(PROFILE_FIELDS)
                .contains("friend_ids", [str(user_id)])
                .execute()
                .data
            )

        rows = await asyncio.to_thread(_query)
        friends = [ProfileSummary.model_validate(row) for row in rows]
        return FriendsListResponse(friends=friends)

    async def create_chat(self, payload: ChatCreatePayload) -> ChatSummaryModel:
        initiator_id = UUID(payload.initiator_id)
        participant_id = UUID(payload.participant_id)
        chat_id = uuid4()

        participant_profile = await self._profile_by_id(participant_id)
        title = self._display_name_or_phone(participant_profile) if participant_profile else "Chat"

        def _insert_chat() -> None:
            self.client.table("chats").insert(
                {
                    "id": str(chat_id),
                    "owner_id": str(initiator_id),
                    "title": title,
                    "is_group": False,
                }
            ).execute()

        await asyncio.to_thread(_insert_chat)

        members = [
            {"chat_id": str(chat_id), "user_id": str(initiator_id)},
            {"chat_id": str(chat_id), "user_id": str(participant_id)},
        ]

        def _insert_members() -> None:
            self.client.table("chat_members").insert(members).execute()

        await asyncio.to_thread(_insert_members)

        return await self._fetch_chat_summary(chat_id)

    async def send_message(self, chat_id: UUID, payload: SendMessagePayload) -> MessageModel:
        sender_profile = await self._profile_by_id(UUID(payload.sender_id))
        sender_name = sender_profile.get("display_name") if sender_profile else None
        message_id = uuid4()

        def _insert() -> dict:
            response = (
                self.client.table("messages")
                .insert(
                    {
                        "id": str(message_id),
                        "chat_id": str(chat_id),
                        "sender_id": payload.sender_id,
                        "content": payload.content,
                    }
                )
                .execute()
            )
            return response.data[0]

        _ = await asyncio.to_thread(_insert)
        message = MessageModel(
            id=str(message_id),
            chat_id=str(chat_id),
            sender_id=payload.sender_id,
            sender_name=sender_name,
            content=payload.content,
            created_at=datetime.now(timezone.utc),
        )
        recipients = await self._chat_member_ids(chat_id)
        await message_hub.broadcast(recipients, message.model_dump(mode="json"))
        return message

    async def list_messages(self, chat_id: UUID) -> MessagesResponse:
        def _query() -> List[dict]:
            return (
                self.client.table("messages")
                .select("id,chat_id,sender_id,content,created_at,sender:sender_id(display_name)")
                .eq("chat_id", str(chat_id))
                .order("created_at", desc=False)
                .execute()
                .data
            )

        rows = await asyncio.to_thread(_query)
        messages: List[MessageModel] = []
        for row in rows:
            sender = row.pop("sender", None)
            if sender:
                row["sender_name"] = sender.get("display_name")
            messages.append(MessageModel.model_validate(row))
        return MessagesResponse(messages=messages)

    async def _chat_member_ids(self, chat_id: UUID) -> list[str]:
        def _query() -> list[str]:
            response = (
                self.client.table("chat_members")
                .select("user_id")
                .eq("chat_id", str(chat_id))
                .execute()
            )
            return [row["user_id"] for row in response.data]

        return await asyncio.to_thread(_query)

    async def _fetch_request_by_id(self, request_id: str | UUID) -> FriendRequestModel:
        def _query() -> dict:
            response = (
                self.client.table("friend_requests")
                .select(_SELECT_FRIEND_REQUEST)
                .eq("id", str(request_id))
                .single()
                .execute()
            )
            return response.data

        row = await asyncio.to_thread(_query)
        if not row:
            raise ValueError("请求不存在")
        return FriendRequestModel.model_validate(row)

    async def _fetch_chat_summary(self, chat_id: UUID) -> ChatSummaryModel:
        def _query() -> dict:
            response = (
                self.client.table("chat_summaries")
                .select(CHAT_SUMMARY_FIELDS)
                .eq("id", str(chat_id))
                .single()
                .execute()
            )
            return response.data

        row = await asyncio.to_thread(_query)
        participant_ids = [str(pid) for pid in row.get("participant_ids", [])]
        row["participant_ids"] = participant_ids
        return ChatSummaryModel.model_validate(row)

    async def _profile_by_phone(self, phone: str) -> dict | None:
        def _query() -> dict | None:
            try:
                response = (
                    self.client.table("profiles")
                    .select(PROFILE_FIELDS)
                    .eq("phone", phone)
                    .single()
                    .execute()
                )
                return response.data
            except Exception:
                return None

        return await asyncio.to_thread(_query)

    async def _link_profiles(self, requester_id: UUID, addressee_id: UUID) -> None:
        requester = await self._profile_by_id(requester_id)
        addressee = await self._profile_by_id(addressee_id)
        if requester is None or addressee is None:
            return

        requester_friends = set((requester.get("friend_ids") or []))
        addressee_friends = set((addressee.get("friend_ids") or []))

        requester_friends.add(str(addressee_id))
        addressee_friends.add(str(requester_id))

        await asyncio.to_thread(
            lambda: self.client.table("profiles")
            .update({"friend_ids": list(requester_friends)})
            .eq("id", str(requester_id))
            .execute()
        )

        await asyncio.to_thread(
            lambda: self.client.table("profiles")
            .update({"friend_ids": list(addressee_friends)})
            .eq("id", str(addressee_id))
            .execute()
        )

    async def _profile_by_id(self, user_id: UUID) -> dict | None:
        def _query() -> dict | None:
            try:
                response = (
                    self.client.table("profiles")
                    .select(PROFILE_FIELDS)
                    .eq("id", str(user_id))
                    .single()
                    .execute()
                )
                return response.data
            except Exception:
                return None

        return await asyncio.to_thread(_query)

    @staticmethod
    def _display_name_or_phone(profile: dict | None) -> str:
        if not profile:
            return "Chat"
        raw_name = (profile.get("display_name") or "").strip()
        if raw_name and raw_name.lower() != "user":
            return raw_name
        phone = (profile.get("phone") or "").strip()
        return phone or "Chat"
