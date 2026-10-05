from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

REPO_ROOT = Path(__file__).resolve().parents[2]
DEV_JWT_SECRET = "dev-only-secret-change-me-0123456789abcdef"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="QMS_", env_file=".env", extra="ignore")

    # Runtime connection: a member of qms_app, never the schema owner (the owner bypasses RLS).
    database_url: str = "postgresql://qms_api:qms_api@localhost:5432/qms"
    # Owner connection, used only by migrations and seeding.
    owner_database_url: str = "postgresql://qms_owner:qms@localhost:5432/qms"

    jwt_secret: str = DEV_JWT_SECRET
    jwt_ttl_minutes: int = 60 * 12
    # Password-less login by e-mail, for local development only. Production uses the external IdP.
    dev_auth: bool = False

    cors_origins: list[str] = ["http://localhost:5173"]
    model_json: Path = REPO_ROOT / "db" / "generated" / "model.json"
    migrations_dir: Path = REPO_ROOT / "db" / "migrations"


@lru_cache
def get_settings() -> Settings:
    return Settings()
