from typing import Optional, Dict, Any
import uuid

import httpx
from fastapi import HTTPException, status

from .config import Settings


def new_operation_id(prefix: str) -> str:
    return f"{prefix}-{uuid.uuid4().hex}"


class OpenIMClient:
    def __init__(self, settings: Settings, http_client: httpx.AsyncClient) -> None:
        self._settings = settings
        self._http = http_client
        self._base = settings.openim_base_url.rstrip("/")

    async def _post(self, path: str, json: dict, headers: Optional[dict] = None) -> dict:
        url = f"{self._base}{path}"
        req_headers = {"Content-Type": "application/json"}
        if headers:
            req_headers.update(headers)
        resp = await self._http.post(url, json=json, headers=req_headers)
        resp.raise_for_status()
        payload = resp.json()
        err_code = payload.get("errCode", 0)
        if err_code != 0:
            err_msg = payload.get("errMsg") or "OpenIM request failed"
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"{path} -> {err_code}: {err_msg}",
            )
        return payload.get("data") or payload

    async def get_user_token(self, user_id: str, platform_id: Optional[int] = None) -> dict:
        operation_id = new_operation_id(self._settings.openim_operation_prefix)
        data = await self._post(
            "/auth/user_token",
            json={
                "secret": self._settings.openim_secret,
                "platformID": platform_id or self._settings.default_platform_id,
                "userID": user_id,
            },
            headers={"operationID": operation_id},
        )
        return data

    async def get_admin_token(self) -> dict:
        data = await self._post(
            "/auth/get_admin_token",
            json={
                "secret": self._settings.openim_secret,
                "userID": self._settings.im_admin_user_id,
            },
        )
        return data

    async def post_with_token(self, path: str, token: str, payload: dict) -> dict:
        operation_id = new_operation_id(self._settings.openim_operation_prefix)
        return await self._post(
            path,
            json=payload,
            headers={"operationID": operation_id, "token": token},
        )
