from fastapi import Depends, HTTPException, Header
import jwt
from typing import Optional, Generator
from core.security import JWT_SECRET, JWT_AUD, JWT_ISS
from core.db import SessionLocal

def get_db() -> Generator:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
def get_current_user(authorization: Optional[str] = Header(None)):
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing token")
    token = authorization.split()[1]
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=["HS256"], audience=JWT_AUD, issuer=JWT_ISS)
        return payload
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid token")
def require_role(roles: list[str]):
    def inner(payload=Depends(get_current_user)):
        if payload.get("role") not in roles:
            raise HTTPException(403, "Forbidden")
        return payload
    return inner
