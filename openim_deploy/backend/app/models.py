from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, Field


def utc_ts_ms() -> int:
    return int(datetime.utcnow().timestamp() * 1000)


class HealthResponse(BaseModel):
    status: str = "ok"
    timestamp: int = Field(default_factory=utc_ts_ms)


class TokenRequest(BaseModel):
    userID: Optional[str] = None
    platformID: Optional[int] = None


class TokenResponse(BaseModel):
    userID: str
    token: str
    expireTimeSeconds: int
    apiAddr: str
    wsAddr: str


class FriendRequestBody(BaseModel):
    toUserID: str
    fromUserID: Optional[str] = None
    reqMsg: Optional[str] = None


class FriendResponseBody(BaseModel):
    fromUserID: str
    toUserID: Optional[str] = None
    accept: bool = True
    handleMsg: Optional[str] = None


class MessageSendBody(BaseModel):
    toUserID: str
    text: str
    sendID: Optional[str] = None
    clientMsgID: Optional[str] = None


class ActionResult(BaseModel):
    ok: bool = True
    detail: Optional[Any] = None


class AccountLoginRequest(BaseModel):
    account: Optional[str] = None
    phoneNumber: Optional[str] = None
    email: Optional[str] = None
    password: Optional[str] = None
    areaCode: Optional[str] = None
    verifyCode: Optional[str] = None  # not used but matches client payload


class BaseResponse(BaseModel):
    errCode: int = 0
    errMsg: str = ""
    errDlt: str = ""
    data: Optional[Any] = None
