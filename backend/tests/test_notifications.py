"""
Tests for Notification System

Covers:
- Device token registration
- WebPush subscription
- Notification sending (push, email)
- Notification retrieval and filtering
- Mark as read functionality
- Scheduled notifications
"""

import pytest
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from core.models import User, Family, Notification, DeviceToken, WebPushSub, Task
from services.notification_service import NotificationService


@pytest.fixture
def test_family(db: Session):
    """Create test family"""
    family = Family(
        id="test-family-1",
        name="Test Family",
        createdAt=datetime.utcnow(),
        updatedAt=datetime.utcnow()
    )
    db.add(family)
    db.commit()
    return family


@pytest.fixture
def test_parent(db: Session, test_family):
    """Create test parent user"""
    user = User(
        id="parent-1",
        familyId=test_family.id,
        email="parent@test.com",
        displayName="Parent User",
        role="parent",
        createdAt=datetime.utcnow(),
        updatedAt=datetime.utcnow()
    )
    db.add(user)
    db.commit()
    return user


@pytest.fixture
def test_child(db: Session, test_family):
    """Create test child user"""
    user = User(
        id="child-1",
        familyId=test_family.id,
        email="child@test.com",
        displayName="Child User",
        role="child",
        createdAt=datetime.utcnow(),
        updatedAt=datetime.utcnow()
    )
    db.add(user)
    db.commit()
    return user


class TestNotificationService:
    """Test notification service functionality"""

    @pytest.mark.asyncio
    async def test_send_notification_basic(self, db: Session, test_child):
        """Test basic notification sending"""
        service = NotificationService(db)

        result = await service.send_notification(
            user_id=test_child.id,
            notification_type='test',
            title='Test Notification',
            body='This is a test',
            data={'test': True}
        )

        assert result['notification_id'] is not None
        assert result['push_sent'] >= 0  # May be 0 if no devices

        # Verify notification was saved to database
        notification = db.query(Notification).filter(
            Notification.id == result['notification_id']
        ).first()

        assert notification is not None
        assert notification.userId == test_child.id
        assert notification.type == 'test'
        assert notification.title == 'Test Notification'
        assert notification.body == 'This is a test'
        assert notification.status == 'sent'

    @pytest.mark.asyncio
    async def test_send_notification_with_device_token(self, db: Session, test_child):
        """Test notification sending with registered device"""
        # Register device token
        token = DeviceToken(
            id="token-1",
            userId=test_child.id,
            platform='android',
            token='test-fcm-token-123',
            createdAt=datetime.utcnow()
        )
        db.add(token)
        db.commit()

        service = NotificationService(db)

        result = await service.send_notification(
            user_id=test_child.id,
            notification_type='task_due',
            title='Task Due Soon',
            body='Your task is due in 60 minutes',
            data={'task_id': 'task-123'}
        )

        assert result['notification_id'] is not None
        # Push sending may fail in test environment (no Firebase), but should not error
        assert 'push_sent' in result

    @pytest.mark.asyncio
    async def test_schedule_task_reminder(self, db: Session, test_child, test_family):
        """Test scheduling task reminder"""
        # Create task with due date
        task = Task(
            id="task-123",
            familyId=test_family.id,
            title="Clean room",
            desc="",
            assignees=[test_child.id],
            due=datetime.utcnow() + timedelta(hours=2),
            status='open',
            points=10,
            createdBy=test_child.id,
            createdAt=datetime.utcnow(),
            updatedAt=datetime.utcnow()
        )
        db.add(task)
        db.commit()

        service = NotificationService(db)
        await service.schedule_task_reminder(task.id)

        # Verify scheduled notification was created
        scheduled = db.query(Notification).filter(
            Notification.type == 'task_due',
            Notification.userId == test_child.id,
            Notification.status == 'pending'
        ).first()

        assert scheduled is not None
        assert scheduled.scheduledFor is not None
        # Should be scheduled 60 min before due time
        expected_time = task.due - timedelta(minutes=60)
        assert abs((scheduled.scheduledFor - expected_time).total_seconds()) < 10

    @pytest.mark.asyncio
    async def test_check_streak_guard(self, db: Session, test_child):
        """Test streak guard notification"""
        from core.models import UserStreak

        # Create streak for user
        streak = UserStreak(
            id="streak-1",
            userId=test_child.id,
            currentStreak=5,
            longestStreak=5,
            lastCompletionDate=datetime.utcnow() - timedelta(days=1),
            updatedAt=datetime.utcnow()
        )
        db.add(streak)
        db.commit()

        service = NotificationService(db)
        await service.check_streak_guard()

        # Verify streak guard notification was sent
        notification = db.query(Notification).filter(
            Notification.type == 'streak_guard',
            Notification.userId == test_child.id
        ).first()

        assert notification is not None
        assert 'streak' in notification.body.lower()


class TestNotificationAPI:
    """Test notification API endpoints"""

    def test_register_device_token(self, client, test_child, auth_headers):
        """Test device token registration"""
        response = client.post(
            "/notifications/register-device",
            json={
                "token": "test-fcm-token-456",
                "platform": "ios"
            },
            headers=auth_headers(test_child.id)
        )

        assert response.status_code == 200
        data = response.json()
        assert data['success'] is True

    def test_register_webpush_subscription(self, client, test_child, auth_headers, db: Session):
        """Test WebPush subscription registration"""
        response = client.post(
            "/notifications/register-webpush",
            json={
                "endpoint": "https://fcm.googleapis.com/fcm/send/test",
                "p256dh": "BNcRdreALRFXTkOOUHK1EtK2wtaz5Ry4YfYCA_0QTp",
                "auth": "tBHItJI5svbpez7KI4CCXg"
            },
            headers=auth_headers(test_child.id)
        )

        assert response.status_code == 200
        data = response.json()
        assert data['success'] is True

        # Verify subscription was saved
        sub = db.query(WebPushSub).filter(
            WebPushSub.userId == test_child.id
        ).first()
        assert sub is not None

    def test_get_notifications(self, client, test_child, auth_headers, db: Session):
        """Test retrieving notifications"""
        # Create test notifications
        for i in range(3):
            notification = Notification(
                id=f"notif-{i}",
                userId=test_child.id,
                type='test',
                title=f'Test {i}',
                body=f'Body {i}',
                payload={},
                status='sent',
                createdAt=datetime.utcnow()
            )
            db.add(notification)
        db.commit()

        response = client.get(
            "/notifications",
            headers=auth_headers(test_child.id)
        )

        assert response.status_code == 200
        data = response.json()
        assert len(data) == 3
        assert data[0]['title'] == 'Test 2'  # Newest first

    def test_get_unread_count(self, client, test_child, auth_headers, db: Session):
        """Test unread notification count"""
        # Create unread notifications
        for i in range(5):
            notification = Notification(
                id=f"unread-{i}",
                userId=test_child.id,
                type='test',
                title=f'Unread {i}',
                body='Body',
                payload={},
                status='sent',
                readAt=None if i < 3 else datetime.utcnow(),
                createdAt=datetime.utcnow()
            )
            db.add(notification)
        db.commit()

        response = client.get(
            "/notifications/unread-count",
            headers=auth_headers(test_child.id)
        )

        assert response.status_code == 200
        data = response.json()
        assert data['unread_count'] == 3

    def test_mark_notification_read(self, client, test_child, auth_headers, db: Session):
        """Test marking notification as read"""
        notification = Notification(
            id="notif-mark-read",
            userId=test_child.id,
            type='test',
            title='Test',
            body='Body',
            payload={},
            status='sent',
            readAt=None,
            createdAt=datetime.utcnow()
        )
        db.add(notification)
        db.commit()

        response = client.put(
            f"/notifications/{notification.id}/read",
            headers=auth_headers(test_child.id)
        )

        assert response.status_code == 200
        data = response.json()
        assert data['success'] is True

        # Verify readAt was set
        db.refresh(notification)
        assert notification.readAt is not None

    def test_mark_all_read(self, client, test_child, auth_headers, db: Session):
        """Test marking all notifications as read"""
        # Create multiple unread notifications
        for i in range(4):
            notification = Notification(
                id=f"bulk-{i}",
                userId=test_child.id,
                type='test',
                title=f'Bulk {i}',
                body='Body',
                payload={},
                status='sent',
                readAt=None,
                createdAt=datetime.utcnow()
            )
            db.add(notification)
        db.commit()

        response = client.post(
            "/notifications/mark-all-read",
            headers=auth_headers(test_child.id)
        )

        assert response.status_code == 200
        data = response.json()
        assert data['count'] == 4

        # Verify all marked as read
        unread_count = db.query(Notification).filter(
            Notification.userId == test_child.id,
            Notification.readAt.is_(None)
        ).count()
        assert unread_count == 0

    def test_delete_notification(self, client, test_child, auth_headers, db: Session):
        """Test deleting notification"""
        notification = Notification(
            id="notif-delete",
            userId=test_child.id,
            type='test',
            title='Test',
            body='Body',
            payload={},
            status='sent',
            createdAt=datetime.utcnow()
        )
        db.add(notification)
        db.commit()

        response = client.delete(
            f"/notifications/{notification.id}",
            headers=auth_headers(test_child.id)
        )

        assert response.status_code == 200

        # Verify notification was deleted
        deleted = db.query(Notification).filter(
            Notification.id == notification.id
        ).first()
        assert deleted is None

    def test_cannot_access_other_user_notification(self, client, test_child, test_parent, auth_headers, db: Session):
        """Test that users cannot access other users' notifications"""
        notification = Notification(
            id="notif-private",
            userId=test_parent.id,
            type='test',
            title='Test',
            body='Body',
            payload={},
            status='sent',
            createdAt=datetime.utcnow()
        )
        db.add(notification)
        db.commit()

        # Child tries to mark parent's notification as read
        response = client.put(
            f"/notifications/{notification.id}/read",
            headers=auth_headers(test_child.id)
        )

        assert response.status_code == 404
