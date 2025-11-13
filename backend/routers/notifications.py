"""
Notifications API Router

Endpoints for:
- Device token registration (push notifications)
- WebPush subscription registration
- Notification history retrieval
- Mark notifications as read
- Test notifications (development)
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from core.db import SessionLocal
from core.deps import get_current_user
from core.models import Notification, DeviceToken, WebPushSub, User
from services.notification_service import NotificationService
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from datetime import datetime

router = APIRouter()


def db():
    """Database session dependency"""
    d = SessionLocal()
    try:
        yield d
    finally:
        d.close()


class DeviceTokenCreate(BaseModel):
    """Device token registration payload"""
    token: str = Field(..., description="FCM token or device identifier")
    platform: str = Field(..., description="Platform: ios, android, or web")

    class Config:
        json_schema_extra = {
            "example": {
                "token": "fX7qR8sT9uV0wX1yZ2aB3cD4eF5gH6iJ",
                "platform": "android"
            }
        }


class WebPushSubCreate(BaseModel):
    """WebPush subscription payload"""
    endpoint: str = Field(..., description="Push endpoint URL")
    p256dh: str = Field(..., description="P256DH key")
    auth: str = Field(..., description="Auth secret")

    class Config:
        json_schema_extra = {
            "example": {
                "endpoint": "https://fcm.googleapis.com/fcm/send/...",
                "p256dh": "BNcRdreALRFXTkOOUHK1EtK2wtaz5Ry4YfYCA_0QTp...",
                "auth": "tBHItJI5svbpez7KI4CCXg"
            }
        }


class NotificationOut(BaseModel):
    """Notification response schema"""
    id: str
    userId: str
    type: str
    title: str
    body: str
    payload: Dict[str, Any]
    status: str
    sentAt: Optional[datetime]
    readAt: Optional[datetime]
    scheduledFor: Optional[datetime]
    createdAt: datetime

    class Config:
        from_attributes = True


@router.post("/register-device")
async def register_device(
    device: DeviceTokenCreate,
    d: Session = Depends(db),
    payload=Depends(get_current_user)
):
    """
    Register device token for push notifications.

    Supports:
    - iOS (APNs via Firebase)
    - Android (FCM)
    - Web (endpoint reference for WebPush)

    Returns:
        Success confirmation
    """
    user = d.query(User).filter_by(id=payload["sub"]).first()
    if not user:
        raise HTTPException(404, "User not found")

    # Check if token already exists
    existing = d.query(DeviceToken).filter(
        DeviceToken.token == device.token
    ).first()

    if existing:
        # Update existing token
        existing.userId = user.id
        existing.platform = device.platform
        existing.createdAt = datetime.utcnow()
    else:
        # Create new token
        token = DeviceToken(
            id=str(__import__('uuid').uuid4()),
            userId=user.id,
            token=device.token,
            platform=device.platform,
            createdAt=datetime.utcnow()
        )
        d.add(token)

    d.commit()

    return {
        "success": True,
        "message": "Device registered for push notifications"
    }


@router.post("/register-webpush")
async def register_webpush(
    subscription: WebPushSubCreate,
    d: Session = Depends(db),
    payload=Depends(get_current_user)
):
    """
    Register web push subscription.

    Used by browser clients to enable push notifications via WebPush API.

    Returns:
        Success confirmation
    """
    user = d.query(User).filter_by(id=payload["sub"]).first()
    if not user:
        raise HTTPException(404, "User not found")

    # Check if subscription already exists
    existing = d.query(WebPushSub).filter(
        WebPushSub.endpoint == subscription.endpoint
    ).first()

    if existing:
        # Update existing subscription
        existing.userId = user.id
        existing.p256dh = subscription.p256dh
        existing.auth = subscription.auth
        existing.createdAt = datetime.utcnow()
    else:
        # Create new subscription
        sub = WebPushSub(
            id=str(__import__('uuid').uuid4()),
            userId=user.id,
            endpoint=subscription.endpoint,
            p256dh=subscription.p256dh,
            auth=subscription.auth,
            createdAt=datetime.utcnow()
        )
        d.add(sub)

    d.commit()

    return {
        "success": True,
        "message": "WebPush subscription registered"
    }


@router.get("", response_model=List[NotificationOut])
async def get_notifications(
    unread_only: bool = Query(False, description="Show only unread notifications"),
    limit: int = Query(50, ge=1, le=100, description="Maximum notifications to return"),
    d: Session = Depends(db),
    payload=Depends(get_current_user)
):
    """
    Get user's notifications.

    Query parameters:
    - unread_only: Filter to show only unread notifications
    - limit: Maximum number of notifications (default: 50, max: 100)

    Returns:
        List of notifications ordered by creation date (newest first)
    """
    user = d.query(User).filter_by(id=payload["sub"]).first()
    if not user:
        raise HTTPException(404, "User not found")

    query = d.query(Notification).filter(
        Notification.userId == user.id
    )

    if unread_only:
        query = query.filter(Notification.readAt.is_(None))

    notifications = query.order_by(
        Notification.createdAt.desc()
    ).limit(limit).all()

    return notifications


@router.get("/unread-count")
async def get_unread_count(
    d: Session = Depends(db),
    payload=Depends(get_current_user)
):
    """
    Get count of unread notifications.

    Used for badge display in UI.

    Returns:
        Count of unread notifications
    """
    user = d.query(User).filter_by(id=payload["sub"]).first()
    if not user:
        raise HTTPException(404, "User not found")

    count = d.query(Notification).filter(
        Notification.userId == user.id,
        Notification.readAt.is_(None)
    ).count()

    return {"unread_count": count}


@router.put("/{notification_id}/read")
async def mark_read(
    notification_id: str,
    d: Session = Depends(db),
    payload=Depends(get_current_user)
):
    """
    Mark notification as read.

    Updates readAt timestamp to current time.

    Returns:
        Success confirmation
    """
    user = d.query(User).filter_by(id=payload["sub"]).first()
    if not user:
        raise HTTPException(404, "User not found")

    notification = d.query(Notification).filter(
        Notification.id == notification_id,
        Notification.userId == user.id
    ).first()

    if not notification:
        raise HTTPException(404, "Notification not found")

    notification.readAt = datetime.utcnow()
    d.commit()

    return {"success": True, "notification_id": notification_id}


@router.post("/mark-all-read")
async def mark_all_read(
    d: Session = Depends(db),
    payload=Depends(get_current_user)
):
    """
    Mark all user's notifications as read.

    Bulk operation for "clear all" functionality.

    Returns:
        Count of notifications marked as read
    """
    user = d.query(User).filter_by(id=payload["sub"]).first()
    if not user:
        raise HTTPException(404, "User not found")

    notifications = d.query(Notification).filter(
        Notification.userId == user.id,
        Notification.readAt.is_(None)
    ).all()

    count = len(notifications)
    now = datetime.utcnow()

    for notification in notifications:
        notification.readAt = now

    d.commit()

    return {
        "success": True,
        "count": count,
        "message": f"Marked {count} notifications as read"
    }


@router.delete("/{notification_id}")
async def delete_notification(
    notification_id: str,
    d: Session = Depends(db),
    payload=Depends(get_current_user)
):
    """
    Delete notification.

    Permanently removes notification from database.

    Returns:
        Success confirmation
    """
    user = d.query(User).filter_by(id=payload["sub"]).first()
    if not user:
        raise HTTPException(404, "User not found")

    notification = d.query(Notification).filter(
        Notification.id == notification_id,
        Notification.userId == user.id
    ).first()

    if not notification:
        raise HTTPException(404, "Notification not found")

    d.delete(notification)
    d.commit()

    return {"success": True, "notification_id": notification_id}


@router.post("/test")
async def send_test_notification(
    d: Session = Depends(db),
    payload=Depends(get_current_user)
):
    """
    Send test notification (development only).

    Useful for testing push notification setup and delivery.

    Returns:
        Send results with device count
    """
    user = d.query(User).filter_by(id=payload["sub"]).first()
    if not user:
        raise HTTPException(404, "User not found")

    service = NotificationService(d)
    result = await service.send_notification(
        user_id=user.id,
        notification_type='test',
        title='Test Notification',
        body='This is a test push notification from FamQuest',
        data={'test': True, 'timestamp': datetime.utcnow().isoformat()}
    )

    return {
        "success": True,
        "result": result,
        "message": f"Test notification sent to {result['push_sent']} device(s)"
    }


@router.get("/devices")
async def list_devices(
    d: Session = Depends(db),
    payload=Depends(get_current_user)
):
    """
    List all registered devices for current user.

    Useful for debugging and device management.

    Returns:
        List of registered device tokens
    """
    user = d.query(User).filter_by(id=payload["sub"]).first()
    if not user:
        raise HTTPException(404, "User not found")

    tokens = d.query(DeviceToken).filter(
        DeviceToken.userId == user.id
    ).all()

    return {
        "devices": [
            {
                "id": token.id,
                "platform": token.platform,
                "token": token.token[:20] + "...",  # Truncate for security
                "created_at": token.createdAt.isoformat()
            }
            for token in tokens
        ],
        "count": len(tokens)
    }


@router.delete("/devices/{device_id}")
async def unregister_device(
    device_id: str,
    d: Session = Depends(db),
    payload=Depends(get_current_user)
):
    """
    Unregister device from push notifications.

    Used when user logs out or device is no longer active.

    Returns:
        Success confirmation
    """
    user = d.query(User).filter_by(id=payload["sub"]).first()
    if not user:
        raise HTTPException(404, "User not found")

    token = d.query(DeviceToken).filter(
        DeviceToken.id == device_id,
        DeviceToken.userId == user.id
    ).first()

    if not token:
        raise HTTPException(404, "Device not found")

    d.delete(token)
    d.commit()

    return {
        "success": True,
        "device_id": device_id,
        "message": "Device unregistered"
    }
