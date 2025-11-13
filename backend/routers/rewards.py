from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from uuid import uuid4
from core.db import SessionLocal
from core import models
from core.deps import get_current_user
from core.schemas import RewardIn, RewardOut
from routers.util import audit
router = APIRouter()
def db():
    d = SessionLocal()
    try: yield d
    finally: d.close()
@router.get("", response_model=list[RewardOut])
def list_rewards(d: Session = Depends(db), payload=Depends(get_current_user)):
    familyId = d.query(models.User).filter_by(id=payload["sub"]).first().familyId
    rewards = d.query(models.Reward).filter_by(familyId=familyId).all()
    return [RewardOut(id=r.id, name=r.name, cost=r.cost) for r in rewards]
@router.post("", response_model=RewardOut)
def create_reward(body: RewardIn, d: Session = Depends(db), payload=Depends(get_current_user)):
    familyId = d.query(models.User).filter_by(id=payload["sub"]).first().familyId
    r = models.Reward(id=str(uuid4()), familyId=familyId, name=body.name, cost=body.cost)
    d.add(r); d.commit()
    audit(d, actorUserId=payload['sub'], familyId=familyId, action="reward.create", meta=r.name)
    return RewardOut(id=r.id, name=r.name, cost=r.cost)
