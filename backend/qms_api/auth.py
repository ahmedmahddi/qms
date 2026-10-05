"""Bearer-token authentication.

Tokens are short JWTs issued by this API whose subject is the users.id. Today they are
issued by the development login (QMS_DEV_AUTH=true); the production path will exchange an
external IdP token (users.auth_subject) for the same kind of token.
"""

from datetime import UTC, datetime, timedelta
from typing import Annotated
from uuid import UUID

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from .config import get_settings

_bearer = HTTPBearer(auto_error=False)
ALGORITHM = "HS256"


def issue_token(user_id: UUID) -> str:
    s = get_settings()
    now = datetime.now(UTC)
    return jwt.encode({"sub": str(user_id), "iat": now, "exp": now + timedelta(minutes=s.jwt_ttl_minutes)},
                      s.jwt_secret, algorithm=ALGORITHM)


def current_user_id(
    creds: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)],
) -> UUID:
    if creds is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "missing bearer token",
                            headers={"WWW-Authenticate": "Bearer"})
    try:
        claims = jwt.decode(creds.credentials, get_settings().jwt_secret, algorithms=[ALGORITHM])
        return UUID(claims["sub"])
    except (jwt.PyJWTError, KeyError, ValueError):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "invalid or expired token",
                            headers={"WWW-Authenticate": "Bearer"}) from None


UserId = Annotated[UUID, Depends(current_user_id)]
