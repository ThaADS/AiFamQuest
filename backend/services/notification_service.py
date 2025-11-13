"""
Notification Service for FamQuest

Handles all notification types:
- Push notifications (FCM for Android/iOS, WebPush for browsers)
- Email notifications (Sendgrid/Mailgun)
- In-app notifications
- Scheduled notifications

Notification Types:
- task_due (60 min before due time)
- task_overdue (missed deadline)
- task_completed (parent FYI)
- task_approval_requested (child completed task with photo)
- task_approved (child receives points)
- task_rejected (child needs to redo)
- streak_guard (20:00 reminder if no tasks done)
- badge_unlocked (achievement notification)
- points_awarded (gamification feedback)
"""

from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional
from core.models import Notification, DeviceToken, WebPushSub, User, Task
import os
import json
import logging

# Configure logging
logger = logging.getLogger(__name__)

# Push notification clients (lazy loaded)
_firebase_app = None
_firebase_messaging = None


class NotificationService:
    """
    Unified notification service for all notification types.

    Usage:
        service = NotificationService(db)
        result = await service.send_notification(
            user_id="user-uuid",
            notification_type="task_due",
            title="Task due soon",
            body="Your task is due in 60 minutes",
            data={"task_id": "task-uuid"},
            action_url="/tasks/task-uuid"
        )
    """

    def __init__(self, db: Session):
        """
        Initialize notification service.

        Args:
            db: Database session
        """
        self.db = db
        self._init_firebase()

    def _init_firebase(self):
        """Initialize Firebase for push notifications (lazy loading)."""
        global _firebase_app, _firebase_messaging

        if _firebase_app is None:
            try:
                import firebase_admin
                from firebase_admin import credentials, messaging

                firebase_creds_path = os.getenv("FIREBASE_CREDENTIALS_PATH")
                if firebase_creds_path and os.path.exists(firebase_creds_path):
                    if not firebase_admin._apps:
                        cred = credentials.Certificate(firebase_creds_path)
                        _firebase_app = firebase_admin.initialize_app(cred)
                        _firebase_messaging = messaging
                        logger.info("Firebase initialized successfully")
                else:
                    logger.warning("Firebase credentials not found, push notifications disabled")
            except ImportError:
                logger.warning("firebase-admin not installed, push notifications disabled")
            except Exception as e:
                logger.error(f"Failed to initialize Firebase: {e}")

    async def send_notification(
        self,
        user_id: str,
        notification_type: str,
        title: str,
        body: str,
        data: Dict[str, Any] = None,
        action_url: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Send notification via all enabled channels (push, email, local).

        Args:
            user_id: Target user ID
            notification_type: Type of notification (task_due, task_completed, etc.)
            title: Notification title
            body: Notification body text
            data: Additional data payload (optional)
            action_url: Deep link URL (optional)

        Returns:
            Dict with send results:
            {
                "push_sent": 3,  # Devices reached
                "email_sent": true,
                "notification_id": "uuid"
            }
        """
        # 1. Save notification to database
        notification = Notification(
            id=self._generate_id(),
            userId=user_id,
            type=notification_type,
            title=title,
            body=body,
            payload=data or {},
            status="pending",
            createdAt=datetime.utcnow()
        )

        if action_url:
            notification.payload["action_url"] = action_url

        self.db.add(notification)
        self.db.commit()
        self.db.refresh(notification)

        # 2. Send push notifications
        push_count = await self._send_push(user_id, title, body, data)

        # 3. Send email (for critical notifications)
        email_sent = False
        if notification_type in ['task_approval_requested', 'streak_guard', 'task_overdue']:
            email_sent = await self._send_email(user_id, title, body, action_url)

        # Update notification status
        notification.status = "sent"
        notification.sentAt = datetime.utcnow()
        self.db.commit()

        logger.info(f"Notification sent: type={notification_type}, user={user_id}, push={push_count}, email={email_sent}")

        return {
            "push_sent": push_count,
            "email_sent": email_sent,
            "notification_id": notification.id
        }

    async def _send_push(
        self,
        user_id: str,
        title: str,
        body: str,
        data: Dict[str, Any] = None
    ) -> int:
        """
        Send push notification to all user's devices.

        Args:
            user_id: Target user ID
            title: Notification title
            body: Notification body
            data: Additional data payload

        Returns:
            Number of devices successfully reached
        """
        # Get all active device tokens for this user
        tokens = self.db.query(DeviceToken).filter(
            DeviceToken.userId == user_id
        ).all()

        if not tokens:
            logger.debug(f"No device tokens found for user {user_id}")
            return 0

        sent_count = 0

        for token in tokens:
            try:
                if token.platform in ['android', 'ios']:
                    # Firebase Cloud Messaging (FCM) for Android/iOS
                    if _firebase_messaging:
                        message = _firebase_messaging.Message(
                            notification=_firebase_messaging.Notification(
                                title=title,
                                body=body
                            ),
                            data={k: str(v) for k, v in (data or {}).items()},  # FCM requires string values
                            token=token.token
                        )
                        response = _firebase_messaging.send(message)
                        logger.info(f"FCM push sent to {token.platform}: {response}")
                        sent_count += 1

                elif token.platform == 'web':
                    # WebPush for browsers
                    web_sub = self.db.query(WebPushSub).filter(
                        WebPushSub.userId == user_id,
                        WebPushSub.endpoint == token.token
                    ).first()

                    if web_sub:
                        try:
                            from pywebpush import webpush, WebPushException

                            webpush(
                                subscription_info={
                                    "endpoint": web_sub.endpoint,
                                    "keys": {
                                        "p256dh": web_sub.p256dh,
                                        "auth": web_sub.auth
                                    }
                                },
                                data=json.dumps({"title": title, "body": body, "data": data}),
                                vapid_private_key=os.getenv("VAPID_PRIVATE_KEY"),
                                vapid_claims={"sub": "mailto:no-reply@famquest.app"}
                            )
                            logger.info(f"WebPush sent to browser")
                            sent_count += 1
                        except WebPushException as e:
                            logger.error(f"WebPush failed: {e}")
                            # Mark subscription as inactive if expired
                            if "410" in str(e) or "404" in str(e):
                                self.db.delete(web_sub)
                                self.db.delete(token)
                                self.db.commit()

            except Exception as e:
                logger.error(f"Push notification failed for {token.platform}: {e}")
                # Mark token as inactive if invalid
                if "NotRegistered" in str(e) or "InvalidRegistration" in str(e):
                    self.db.delete(token)
                    self.db.commit()

        return sent_count

    async def _send_email(
        self,
        user_id: str,
        subject: str,
        body: str,
        action_url: Optional[str]
    ) -> bool:
        """
        Send email notification (Sendgrid/Mailgun).

        Args:
            user_id: Target user ID
            subject: Email subject
            body: Email body text
            action_url: Action URL for email button

        Returns:
            True if email sent successfully, False otherwise
        """
        user = self.db.query(User).filter(User.id == user_id).first()
        if not user or not user.email:
            logger.warning(f"No email found for user {user_id}")
            return False

        try:
            # Sendgrid implementation
            sendgrid_api_key = os.getenv("SENDGRID_API_KEY")
            if sendgrid_api_key:
                from sendgrid import SendGridAPIClient
                from sendgrid.helpers.mail import Mail

                message = Mail(
                    from_email='no-reply@famquest.app',
                    to_emails=user.email,
                    subject=subject,
                    html_content=self._format_email_html(body, action_url)
                )

                sg = SendGridAPIClient(sendgrid_api_key)
                response = sg.send(message)
                logger.info(f"Email sent to {user.email} via Sendgrid: {response.status_code}")
                return True

            # Mailgun implementation (fallback)
            mailgun_api_key = os.getenv("MAILGUN_API_KEY")
            mailgun_domain = os.getenv("MAILGUN_DOMAIN")
            if mailgun_api_key and mailgun_domain:
                import requests

                response = requests.post(
                    f"https://api.mailgun.net/v3/{mailgun_domain}/messages",
                    auth=("api", mailgun_api_key),
                    data={
                        "from": "FamQuest <no-reply@famquest.app>",
                        "to": user.email,
                        "subject": subject,
                        "html": self._format_email_html(body, action_url)
                    }
                )

                if response.status_code == 200:
                    logger.info(f"Email sent to {user.email} via Mailgun")
                    return True
                else:
                    logger.error(f"Mailgun email failed: {response.status_code}")
                    return False

            logger.warning("No email provider configured (Sendgrid or Mailgun)")
            return False

        except Exception as e:
            logger.error(f"Email send failed: {e}")
            return False

    def _format_email_html(self, body: str, action_url: Optional[str]) -> str:
        """
        Format email HTML with FamQuest branding.

        Args:
            body: Email body text
            action_url: Action URL for CTA button

        Returns:
            HTML email content
        """
        action_button = ""
        if action_url:
            action_button = f'''
            <p style="text-align: center; margin-top: 20px;">
                <a href="{action_url}"
                   style="display: inline-block; padding: 12px 24px; background-color: #4CAF50;
                          color: white; text-decoration: none; border-radius: 4px; font-weight: bold;">
                    View Details
                </a>
            </p>
            '''

        return f'''
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
        </head>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
            <div style="background-color: #f8f9fa; padding: 20px; border-radius: 8px;">
                <h2 style="color: #4CAF50; margin-top: 0;">FamQuest Notification</h2>
                <p style="font-size: 16px;">{body}</p>
                {action_button}
                <hr style="border: none; border-top: 1px solid #ddd; margin: 20px 0;">
                <p style="font-size: 12px; color: #666; text-align: center;">
                    You received this email because you're part of a FamQuest family.<br>
                    To manage your notification preferences, visit your settings.
                </p>
            </div>
        </body>
        </html>
        '''

    async def schedule_task_reminder(self, task_id: str):
        """
        Schedule task_due notification 60 min before due time.
        Uses database scheduling (Celery/Redis integration can be added later).

        Args:
            task_id: Task ID to schedule reminder for
        """
        task = self.db.query(Task).filter(Task.id == task_id).first()
        if not task or not task.due:
            logger.warning(f"Cannot schedule reminder: task {task_id} not found or has no due date")
            return

        # Calculate reminder time (60 min before due)
        reminder_time = task.due - timedelta(minutes=60)

        if reminder_time <= datetime.utcnow():
            logger.debug(f"Task {task_id} due time already passed, skipping reminder")
            return

        # Get assignee
        assignee_id = task.assignees[0] if task.assignees else task.claimedBy
        if not assignee_id:
            logger.warning(f"Task {task_id} has no assignee, skipping reminder")
            return

        # Create scheduled notification
        notification = Notification(
            id=self._generate_id(),
            userId=assignee_id,
            type='task_due',
            title=f'Task due soon: {task.title}',
            body=f'Your task "{task.title}" is due in 60 minutes',
            payload={'task_id': task_id, 'due': task.due.isoformat()},
            status='pending',
            scheduledFor=reminder_time,
            createdAt=datetime.utcnow()
        )
        self.db.add(notification)
        self.db.commit()

        logger.info(f"Task reminder scheduled: task={task_id}, scheduled_for={reminder_time}")

    async def check_streak_guard(self):
        """
        Daily cron job at 20:00: Check users with 0 tasks completed today.
        Send streak_guard notification.

        Should be called by background worker at 20:00 daily.
        """
        from services.streak_service import StreakService

        # Get all users with current streak > 0
        users = self.db.query(User).all()

        for user in users:
            # Check user's streak
            streak_service = StreakService()
            if streak_service.check_streak_guard(user.id, self.db):
                # Streak at risk, send notification
                streak_stats = streak_service.get_streak_stats(user.id, self.db)

                await self.send_notification(
                    user_id=user.id,
                    notification_type='streak_guard',
                    title='Streak at risk! 🔥',
                    body=f'Complete a task before midnight to keep your {streak_stats["current"]}-day streak',
                    data={'current_streak': streak_stats["current"]},
                    action_url='/tasks'
                )

                logger.info(f"Streak guard notification sent to user {user.id}")

    async def process_scheduled_notifications(self):
        """
        Process all pending scheduled notifications.

        Should be called periodically (e.g., every 5 minutes) by background worker.
        """
        now = datetime.utcnow()

        # Get all pending scheduled notifications due now
        notifications = self.db.query(Notification).filter(
            Notification.status == 'pending',
            Notification.scheduledFor <= now
        ).all()

        logger.info(f"Processing {len(notifications)} scheduled notifications")

        for notification in notifications:
            try:
                # Send push notifications
                push_count = await self._send_push(
                    notification.userId,
                    notification.title,
                    notification.body,
                    notification.payload
                )

                # Update status
                notification.status = 'sent'
                notification.sentAt = now
                self.db.commit()

                logger.info(f"Scheduled notification sent: id={notification.id}, push_count={push_count}")

            except Exception as e:
                logger.error(f"Failed to send scheduled notification {notification.id}: {e}")
                notification.status = 'failed'
                self.db.commit()

    def _generate_id(self) -> str:
        """Generate unique ID for database records."""
        from uuid import uuid4
        return str(uuid4())
