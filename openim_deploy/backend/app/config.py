from functools import lru_cache
from typing import Union

from pydantic import HttpUrl
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application configuration sourced from env / .env."""

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    openim_base_url: Union[HttpUrl, str] = "https://api.guanqunhuang.com"
    openim_secret: str = "openIM123"
    openim_operation_prefix: str = "ios-bridge"
    openim_ws_url: str = "wss://api.guanqunhuang.com/msg_gateway"

    request_timeout_seconds: float = 10.0
    default_platform_id: int = 1

    supabase_jwt_secret: Union[str, None] = None

    im_admin_user_id: str = "imAdmin"

    listen_host: str = "0.0.0.0"
    listen_port: int = 8080


@lru_cache
def get_settings() -> Settings:
    return Settings()
