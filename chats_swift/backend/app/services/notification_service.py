from __future__ import annotations

import asyncio
from typing import Iterable

from supabase import Client

from ..schemas import NotificationRecord, OfflineMessagePayload


class NotificationService:
    """Persist notification intents and fan out to push providers."""

    def __init__(self, client: Client) -> None:
        self.client = client

    async def handle_offline_message(self, payload: OfflineMessagePayload) -> int:
        records = [
            NotificationRecord(
                chat_id=payload.chat_id,
                recipient_id=recipient_id,
                preview=payload.preview,
            )
            for recipient_id in payload.recipient_ids
        ]
        await self._persist(records)
        # TODO: integrate APNs/FCM. For now we pretend delivery succeeds immediately.
        return len(records)

    async def _persist(self, records: Iterable[NotificationRecord]) -> None:
        def _insert() -> None:
            rows = []
            for record in records:
                payload = record.model_dump()
                created_at = payload.get("created_at")
                if hasattr(created_at, "isoformat"):
                    payload["created_at"] = created_at.isoformat()
                rows.append(payload)
            if not rows:
                return
            self.client.table("message_notifications").insert(rows).execute()

        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, _insert)
