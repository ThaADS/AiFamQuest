from uuid import uuid4
from datetime import datetime
from core import models
def audit(db, actorUserId: str, familyId: str, action: str, meta: str=""):
    entry = models.AuditLog(id=str(uuid4()), actorUserId=actorUserId, familyId=familyId, action=action, meta=meta, createdAt=datetime.utcnow())
    db.add(entry); db.commit()
