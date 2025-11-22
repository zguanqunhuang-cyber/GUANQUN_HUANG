from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_prefix="CHAT_", case_sensitive=False)

    supabase_url: str
    supabase_service_key: str
    backend_port: int = 8080
    apns_team_id: str | None = None
    apns_key_id: str | None = None
    apns_key_path: str | None = None


settings = Settings()
