from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from ..auth import issue_token
from ..config import get_settings
from ..db import anon_tx

router = APIRouter(prefix="/auth", tags=["auth"])


class DevLogin(BaseModel):
    email: str = Field(min_length=3, max_length=320)


@router.get("/config")
def auth_config() -> dict:
    return {"dev_auth": get_settings().dev_auth}


@router.post("/dev-login")
def dev_login(body: DevLogin) -> dict:
    if not get_settings().dev_auth:
        raise HTTPException(404, "not found")
    with anon_tx() as conn:
        row = conn.execute("SELECT * FROM app.user_for_login(%s)", (body.email,)).fetchone()
        if row is None or row["status"] != "active":
            raise HTTPException(401, "unknown or inactive user")
        conn.execute("SELECT app.record_login(%s)", (row["id"],))
    return {"access_token": issue_token(row["id"]), "token_type": "bearer"}
