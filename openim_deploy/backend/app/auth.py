from typing import Optional, Dict, Any

from fastapi import Depends, Header, HTTPException, status
from jose import JWTError, jwt
from pydantic import BaseModel

from .config import Settings, get_settings


class AuthContext(BaseModel):
    user_id: Optional[str] = None
    raw_token: Optional[str] = None
    claims: Optional[Dict[str, Any]] = None


async def get_auth_context(
    authorization: Optional[str] = Header(default=None),
    x_debug_user: Optional[str] = Header(default=None, alias="X-Debug-User"),
    settings: Settings = Depends(get_settings),
) -> AuthContext:
    """
    Resolve caller identity.

    - If SUPABASE_JWT_SECRET is set, require `Authorization: Bearer <jwt>` and validate.
    - Otherwise allow caller to pass `X-Debug-User`, falling back to None.
    """

    if settings.supabase_jwt_secret:
        if not authorization:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Authorization header required",
            )
        scheme, _, token = authorization.partition(" ")
        if scheme.lower() != "bearer" or not token:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Authorization header must be Bearer token",
            )
        try:
            claims = jwt.decode(token, settings.supabase_jwt_secret, algorithms=["HS256"])
        except JWTError as exc:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Invalid Supabase token: {exc}",
            ) from exc

        user_id = claims.get("sub")
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Supabase token missing sub claim",
            )
        return AuthContext(user_id=user_id, raw_token=token, claims=claims)

    # Supabase not enforced -> allow debug header.
    if x_debug_user:
        return AuthContext(user_id=x_debug_user, raw_token=None, claims=None)
    return AuthContext(user_id=None, raw_token=None, claims=None)
