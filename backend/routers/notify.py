from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from uuid import uuid4
from datetime import datetime
import os, json, httpx
from pywebpush import webpush, WebPushException
from core.db import SessionLocal
from core import models
from core.deps import get_current_user
router = APIRouter()
def db():
    d = SessionLocal()
    try: yield d
    finally: d.close()
@router.post("/register_device")
def register_device(platform: str, token: str, d: Session = Depends(db), payload=Depends(get_current_user)):
    rec = models.DeviceToken(id=str(uuid4()), userId=payload['sub'], platform=platform, token=token, createdAt=datetime.utcnow())
    d.add(rec); d.commit()
    return {"ok": True}
@router.post("/register_webpush")
def register_webpush(endpoint: str, p256dh: str, auth: str, d: Session = Depends(db), payload=Depends(get_current_user)):
    sub = models.WebPushSub(id=str(uuid4()), userId=payload['sub'], endpoint=endpoint, p256dh=p256dh, auth=auth)
    d.add(sub); d.commit(); return {"ok": True}
@router.post("/push")
async def send_push(title: str, body: str, d: Session = Depends(db), payload=Depends(get_current_user)):
    server_key = os.getenv("FCM_SERVER_KEY")
    if not server_key: return {"queued": False, "error":"FCM_SERVER_KEY not set"}
    tokens = [t.token for t in d.query(models.DeviceToken).filter_by(userId=payload['sub'], platform="android").all()]
    if not tokens: return {"queued": False, "error":"no tokens"}
    async with httpx.AsyncClient(timeout=20) as client:
        r = await client.post("https://fcm.googleapis.com/fcm/send",
            headers={"Authorization": f"key={server_key}", "Content-Type":"application/json"},
            json={"registration_ids": tokens, "notification":{"title":title,"body":body}})
        return {"status": r.status_code}
@router.post("/webpush")
def send_webpush(title: str, body: str, d: Session = Depends(db), payload=Depends(get_current_user)):
    subs = d.query(models.WebPushSub).filter_by(userId=payload['sub']).all()
    ok, errors = 0, []
    for s in subs:
        try:
            webpush(
                subscription_info={"endpoint":s.endpoint,"keys":{"p256dh":s.p256dh,"auth":s.auth}},
                data=json.dumps({"title":title,"body":body}),
                vapid_private_key=os.getenv("WEBPUSH_VAPID_PRIVATE"),
                vapid_claims={"sub": os.getenv("WEBPUSH_CONTACT","mailto:info@example.com")}
            ); ok += 1
        except WebPushException as e: errors.append(str(e))
    return {"ok": ok, "errors": errors}
