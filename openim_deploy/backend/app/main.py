from contextlib import asynccontextmanager

import httpx
from typing import Optional, Any

from fastapi import Depends, FastAPI, HTTPException, Request, Response
import json

from .auth import AuthContext, get_auth_context
from .config import Settings, get_settings
from .models import (
    AccountLoginRequest,
    ActionResult,
    BaseResponse,
    FriendRequestBody,
    FriendResponseBody,
    HealthResponse,
    MessageSendBody,
    TokenRequest,
    TokenResponse,
)
from .openim import OpenIMClient


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    http_client = httpx.AsyncClient(timeout=settings.request_timeout_seconds)
    app.state.settings = settings
    app.state.http_client = http_client
    app.state.openim = OpenIMClient(settings, http_client)
    try:
        yield
    finally:
        await http_client.aclose()


app = FastAPI(title="OpenIM Bridge", lifespan=lifespan)


def get_openim_client() -> OpenIMClient:
    return app.state.openim


def resolve_user_id(body_user_id: Optional[str], auth_ctx: AuthContext) -> str:
    user_id = body_user_id or auth_ctx.user_id
    if not user_id:
        raise HTTPException(status_code=400, detail="userID missing (body or auth)")
    return user_id


@app.get("/healthz", response_model=HealthResponse)
async def health() -> HealthResponse:
    return HealthResponse()


async def _parse_account_body(request: Request) -> AccountLoginRequest:
    try:
        payload: Any = await request.json()
    except json.JSONDecodeError:
        body_bytes = await request.body()
        payload = body_bytes.decode() if body_bytes else {}
    if isinstance(payload, str):
        try:
            payload = json.loads(payload)
        except json.JSONDecodeError:
            payload = {}
    if not isinstance(payload, dict):
        payload = {}
    return AccountLoginRequest(**payload)


@app.post("/account/login", response_model=BaseResponse)
async def account_login(
    request: Request,
    auth_ctx: AuthContext = Depends(get_auth_context),
    openim: OpenIMClient = Depends(get_openim_client),
) -> BaseResponse:
    body = await _parse_account_body(request)
    user_id = body.account or body.phoneNumber or body.email or auth_ctx.user_id
    if not user_id:
        raise HTTPException(status_code=400, detail="account/phone/email required")
    token_data = await openim.get_user_token(user_id, None)
    return BaseResponse(
        errCode=0,
        errMsg="",
        data={
            "userID": user_id,
            "imToken": token_data["token"],
            "chatToken": token_data["token"],
            "expiredTime": token_data.get("expireTimeSeconds"),
        },
    )


async def proxy_openim_post(
    request: Request,
    openim: OpenIMClient,
    path: str,
) -> Response:
    body = await request.body()
    headers = {}
    for header in ["Content-Type", "operationID", "token"]:
        if header_value := request.headers.get(header):
            headers[header] = header_value
    resp = await openim._http.post(
        f"{openim._base}{path}",
        content=body,
        headers=headers,
    )
    return Response(
        content=resp.content,
        status_code=resp.status_code,
        media_type=resp.headers.get("content-type"),
    )


@app.post("/user/{subpath:path}")
async def proxy_user_routes(
    subpath: str,
    request: Request,
    openim: OpenIMClient = Depends(get_openim_client),
):
    path = f"/user/{subpath}" if subpath else "/user"
    return await proxy_openim_post(request, openim, path)


@app.post("/friend/{subpath:path}")
async def proxy_friend_routes(
    subpath: str,
    request: Request,
    openim: OpenIMClient = Depends(get_openim_client),
):
    path = f"/friend/{subpath}" if subpath else "/friend"
    return await proxy_openim_post(request, openim, path)


@app.post("/group/{subpath:path}")
async def proxy_group_routes(
    subpath: str,
    request: Request,
    openim: OpenIMClient = Depends(get_openim_client),
):
    path = f"/group/{subpath}" if subpath else "/group"
    return await proxy_openim_post(request, openim, path)


@app.post("/api/v1/token", response_model=TokenResponse)
async def issue_token(
    body: TokenRequest,
    auth_ctx: AuthContext = Depends(get_auth_context),
    openim: OpenIMClient = Depends(get_openim_client),
    settings: Settings = Depends(get_settings),
) -> TokenResponse:
    user_id = resolve_user_id(body.userID, auth_ctx)
    token_data = await openim.get_user_token(user_id, body.platformID)
    return TokenResponse(
        userID=user_id,
        token=token_data["token"],
        expireTimeSeconds=token_data.get("expireTimeSeconds", 0),
        apiAddr=settings.openim_base_url,
        wsAddr=settings.openim_ws_url,
    )


@app.post("/api/v1/friend/request", response_model=ActionResult)
async def send_friend_request(
    body: FriendRequestBody,
    auth_ctx: AuthContext = Depends(get_auth_context),
    openim: OpenIMClient = Depends(get_openim_client),
) -> ActionResult:
    from_user = resolve_user_id(body.fromUserID, auth_ctx)
    token_data = await openim.get_user_token(from_user, None)
    payload = {
        "fromUserID": from_user,
        "toUserID": body.toUserID,
        "reqMsg": body.reqMsg or "",
    }
    await openim.post_with_token("/friend/add_friend", token_data["token"], payload)
    return ActionResult()


@app.post("/api/v1/friend/accept", response_model=ActionResult)
async def respond_friend_request(
    body: FriendResponseBody,
    auth_ctx: AuthContext = Depends(get_auth_context),
    openim: OpenIMClient = Depends(get_openim_client),
) -> ActionResult:
    to_user = resolve_user_id(body.toUserID, auth_ctx)
    token_data = await openim.get_user_token(to_user, None)
    payload = {
        "fromUserID": body.fromUserID,
        "toUserID": to_user,
        "handleResult": 1 if body.accept else -1,
        "handleMsg": body.handleMsg or "",
    }
    await openim.post_with_token("/friend/add_friend_response", token_data["token"], payload)
    return ActionResult()


@app.post("/api/v1/message/send", response_model=ActionResult)
async def send_message(
    body: MessageSendBody,
    auth_ctx: AuthContext = Depends(get_auth_context),
    openim: OpenIMClient = Depends(get_openim_client),
) -> ActionResult:
    sender = resolve_user_id(body.sendID, auth_ctx)
    admin_token = await openim.get_admin_token()
    payload = {
        "recvID": body.toUserID,
        "sendID": sender,
        "senderPlatformID": 1,
        "contentType": 101,
        "sessionType": 1,
        "content": {"content": body.text},
        "clientMsgID": body.clientMsgID or "",
    }
    await openim.post_with_token("/msg/send_msg", admin_token["token"], payload)
    return ActionResult()
