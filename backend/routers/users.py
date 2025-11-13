from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from core.db import SessionLocal
from core import models
from core.schemas import UserOut
from core.deps import get_current_user
router = APIRouter()
def db():
    d = SessionLocal()
    try: yield d
    finally: d.close()
@router.get("/me", response_model=UserOut)
def me(d: Session = Depends(db), payload=Depends(get_current_user)):
    uid = payload.get("sub"); user = d.query(models.User).filter_by(id=uid).first()
    if not user: raise HTTPException(404,"User not found")
    return UserOut(id=user.id,familyId=user.familyId,email=user.email,displayName=user.displayName,role=user.role,locale=user.locale,theme=user.theme)
