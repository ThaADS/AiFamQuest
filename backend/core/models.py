import os
from datetime import datetime
from typing import Optional, List
import uuid
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy import String, Integer, Boolean, DateTime, ForeignKey, Text, JSON, Index
from sqlalchemy.dialects.postgresql import UUID, JSONB as PGJSONB, ARRAY as PGARRAY
from core.db import Base

# Fallback types for SQLite so local dev works without Postgres extensions
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./famquest.db")
if DATABASE_URL.startswith("sqlite"):
    JSONB = JSON

    def ARRAY(*_args, **_kwargs):
        return JSON
else:
    JSONB = PGJSONB
    ARRAY = PGARRAY

# Helper function for UUID generation
def gen_uuid():
    return str(uuid.uuid4())

class Family(Base):
    __tablename__ = "families"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=gen_uuid)
    name: Mapped[str] = mapped_column(String, nullable=False)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updatedAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Premium / Family Unlock (one-time €9.99 purchase for family)
    familyUnlock: Mapped[bool] = mapped_column(Boolean, default=False)
    familyUnlockPurchasedAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    familyUnlockPurchasedById: Mapped[Optional[str]] = mapped_column(String, ForeignKey("users.id"), nullable=True)

    # Relationships
    users = relationship("User", back_populates="family", cascade="all, delete-orphan")
    tasks = relationship("Task", back_populates="family", cascade="all, delete-orphan")
    events = relationship("Event", back_populates="family", cascade="all, delete-orphan")
    rewards = relationship("Reward", back_populates="family", cascade="all, delete-orphan")

    def __repr__(self):
        return f"<Family(id={self.id}, name={self.name})>"

class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=gen_uuid)
    familyId: Mapped[str] = mapped_column(String, ForeignKey("families.id"), index=True)
    email: Mapped[str] = mapped_column(String, unique=True, index=True)
    displayName: Mapped[str] = mapped_column(String, default="")
    role: Mapped[str] = mapped_column(String, default="child")  # parent|teen|child|helper
    avatar: Mapped[Optional[str]] = mapped_column(String, nullable=True)  # URL or preset code
    passwordHash: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    locale: Mapped[str] = mapped_column(String, default="nl")  # nl|en|de|fr|tr|pl|ar
    theme: Mapped[str] = mapped_column(String, default="minimal")  # cartoony|minimal|classy|dark

    # SSO and Authentication
    emailVerified: Mapped[bool] = mapped_column(Boolean, default=False)
    twoFAEnabled: Mapped[bool] = mapped_column(Boolean, default=False)
    twoFASecret: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    pin: Mapped[Optional[str]] = mapped_column(String, nullable=True)  # For child accounts and kiosk exit

    # Permissions (JSONB for flexibility)
    permissions: Mapped[dict] = mapped_column(JSONB, default=dict, server_default='{}')
    # Example: {"childCanCreateTasks": true, "childCanCreateStudyItems": true}

    # SSO providers (JSONB)
    sso: Mapped[dict] = mapped_column(JSONB, default=dict, server_default='{}')
    # Example: {"providers": ["google", "apple"], "google_id": "123", "apple_id": "456"}

    # Premium subscription (individual user premium)
    premiumUntil: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)  # Subscription expiry
    premiumPlan: Mapped[Optional[str]] = mapped_column(String, nullable=True)  # 'monthly' | 'yearly'
    premiumPaymentId: Mapped[Optional[str]] = mapped_column(String, nullable=True)  # Stripe subscription ID

    # Helper-specific fields
    helperStartDate: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    helperEndDate: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    updatedAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    family = relationship("Family", back_populates="users")
    points_ledger = relationship("PointsLedger", back_populates="user", cascade="all, delete-orphan")
    badges = relationship("Badge", back_populates="user", cascade="all, delete-orphan")
    study_items = relationship("StudyItem", back_populates="user", cascade="all, delete-orphan")
    streaks = relationship("UserStreak", back_populates="user", cascade="all, delete-orphan")

    # Indexes for hot queries
    __table_args__ = (
        Index('idx_user_family_role', 'familyId', 'role'),
        Index('idx_user_email_verified', 'email', 'emailVerified'),
    )

    def __repr__(self):
        return f"<User(id={self.id}, email={self.email}, role={self.role})>"

class Event(Base):
    """Calendar events (appointments, school events, family activities)"""
    __tablename__ = "events"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=gen_uuid)
    familyId: Mapped[str] = mapped_column(String, ForeignKey("families.id"), index=True)
    title: Mapped[str] = mapped_column(String, nullable=False)
    description: Mapped[str] = mapped_column(Text, default="")
    start: Mapped[datetime] = mapped_column(DateTime, nullable=False, index=True)
    end: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    allDay: Mapped[bool] = mapped_column(Boolean, default=False)

    # Attendees (array of user IDs)
    attendees: Mapped[List[str]] = mapped_column(ARRAY(String), default=list, server_default='{}')

    # Color coding
    color: Mapped[Optional[str]] = mapped_column(String, nullable=True)  # Hex color

    # Recurrence (RRULE format)
    rrule: Mapped[Optional[str]] = mapped_column(String, nullable=True)

    # Event category
    category: Mapped[str] = mapped_column(String, default="other")  # school|sport|appointment|family|other

    createdBy: Mapped[str] = mapped_column(String, ForeignKey("users.id"))
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updatedAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    family = relationship("Family", back_populates="events")

    # Indexes for calendar queries
    __table_args__ = (
        Index('idx_event_family_start', 'familyId', 'start'),
        Index('idx_event_family_category', 'familyId', 'category'),
    )

    def __repr__(self):
        return f"<Event(id={self.id}, title={self.title}, start={self.start})>"

class Task(Base):
    __tablename__ = "tasks"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=gen_uuid)
    familyId: Mapped[str] = mapped_column(String, ForeignKey("families.id"), index=True)
    title: Mapped[str] = mapped_column(String, nullable=False)
    desc: Mapped[str] = mapped_column(Text, default="")

    # Category and metadata
    category: Mapped[str] = mapped_column(String, default="other")  # cleaning|care|pet|homework|other

    # Scheduling
    due: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True, index=True)
    frequency: Mapped[str] = mapped_column(String, default="none")  # none|daily|weekly|custom
    rrule: Mapped[Optional[str]] = mapped_column(String, nullable=True)  # RRULE for recurrence

    # Rotation for recurring tasks
    rotationStrategy: Mapped[str] = mapped_column(String, default="manual")  # round_robin|fairness|manual|random
    rotationState: Mapped[dict] = mapped_column(JSONB, default=dict, server_default='{}')  # Tracks rotation index, last rotation date

    # Assignment
    assignees: Mapped[List[str]] = mapped_column(ARRAY(String), default=list, server_default='{}')
    claimable: Mapped[bool] = mapped_column(Boolean, default=False)
    claimedBy: Mapped[Optional[str]] = mapped_column(String, nullable=True)  # User ID who claimed
    claimedAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    # Status and completion
    status: Mapped[str] = mapped_column(String, default="open", index=True)  # open|pendingApproval|done

    # Gamification
    points: Mapped[int] = mapped_column(Integer, default=10)

    # Proof and approval
    photoRequired: Mapped[bool] = mapped_column(Boolean, default=False)
    parentApproval: Mapped[bool] = mapped_column(Boolean, default=False)
    proofPhotos: Mapped[List[str]] = mapped_column(ARRAY(String), default=list, server_default='{}')

    # Priority and estimation
    priority: Mapped[str] = mapped_column(String, default="med")  # low|med|high
    estDuration: Mapped[int] = mapped_column(Integer, default=15)  # Minutes

    # Audit fields
    createdBy: Mapped[str] = mapped_column(String, ForeignKey("users.id"))
    completedBy: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    completedAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    # Optimistic locking
    version: Mapped[int] = mapped_column(Integer, default=0, server_default='0')

    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updatedAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, index=True)

    # Relationships
    family = relationship("Family", back_populates="tasks")
    task_logs = relationship("TaskLog", back_populates="task", cascade="all, delete-orphan")

    # Composite indexes for hot queries
    __table_args__ = (
        Index('idx_task_family_status', 'familyId', 'status'),
        Index('idx_task_family_due', 'familyId', 'due'),
        Index('idx_task_claimable', 'familyId', 'claimable', 'status'),
    )

    def __repr__(self):
        return f"<Task(id={self.id}, title={self.title}, status={self.status})>"

class TaskLog(Base):
    """History log for task completions, approvals, and changes"""
    __tablename__ = "task_logs"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=gen_uuid)
    taskId: Mapped[str] = mapped_column(String, ForeignKey("tasks.id"), index=True)
    userId: Mapped[str] = mapped_column(String, ForeignKey("users.id"))
    action: Mapped[str] = mapped_column(String, nullable=False)  # completed|approved|rejected|reassigned

    # Metadata (JSONB for flexibility)
    meta: Mapped[dict] = mapped_column("metadata", JSONB, default=dict, server_default='{}')
    # Example: {"photos": ["url1"], "rating": 4, "comment": "Good job!"}

    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)

    # Relationships
    task = relationship("Task", back_populates="task_logs")

    def __repr__(self):
        return f"<TaskLog(id={self.id}, taskId={self.taskId}, action={self.action})>"

class PointsLedger(Base):
    __tablename__ = "points_ledger"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=gen_uuid)
    userId: Mapped[str] = mapped_column(String, ForeignKey("users.id"), index=True)
    delta: Mapped[int] = mapped_column(Integer, nullable=False)
    reason: Mapped[str] = mapped_column(String, default="")

    # Reference to task or reward
    taskId: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    rewardId: Mapped[Optional[str]] = mapped_column(String, nullable=True)

    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)

    # Relationships
    user = relationship("User", back_populates="points_ledger")

    # Index for user points calculation
    __table_args__ = (
        Index('idx_points_user_created', 'userId', 'createdAt'),
    )

    def __repr__(self):
        return f"<PointsLedger(id={self.id}, userId={self.userId}, delta={self.delta})>"

class Badge(Base):
    __tablename__ = "badges"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=gen_uuid)
    userId: Mapped[str] = mapped_column(String, ForeignKey("users.id"), index=True)
    code: Mapped[str] = mapped_column(String, nullable=False)  # Badge type code
    awardedAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    # Relationships
    user = relationship("User", back_populates="badges")

    # Index for user badges
    __table_args__ = (
        Index('idx_badge_user_code', 'userId', 'code'),
    )

    def __repr__(self):
        return f"<Badge(id={self.id}, userId={self.userId}, code={self.code})>"

class UserStreak(Base):
    """Tracks daily completion streaks for gamification"""
    __tablename__ = "user_streaks"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=gen_uuid)
    userId: Mapped[str] = mapped_column(String, ForeignKey("users.id"), index=True, unique=True)
    currentStreak: Mapped[int] = mapped_column(Integer, default=0)
    longestStreak: Mapped[int] = mapped_column(Integer, default=0)
    lastCompletionDate: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    updatedAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    user = relationship("User", back_populates="streaks")

    def __repr__(self):
        return f"<UserStreak(userId={self.userId}, current={self.currentStreak}, longest={self.longestStreak})>"

class Reward(Base):
    __tablename__ = "rewards"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=gen_uuid)
    familyId: Mapped[str] = mapped_column(String, ForeignKey("families.id"), index=True)
    name: Mapped[str] = mapped_column(String, nullable=False)
    description: Mapped[str] = mapped_column(Text, default="")
    cost: Mapped[int] = mapped_column(Integer, default=100)
    icon: Mapped[Optional[str]] = mapped_column(String, nullable=True)  # Icon URL or code

    # Availability
    isActive: Mapped[bool] = mapped_column(Boolean, default=True)

    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    # Relationships
    family = relationship("Family", back_populates="rewards")

    def __repr__(self):
        return f"<Reward(id={self.id}, name={self.name}, cost={self.cost})>"

class StudyItem(Base):
    """Homework/study items for the Homework Coach feature"""
    __tablename__ = "study_items"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=gen_uuid)
    userId: Mapped[str] = mapped_column(String, ForeignKey("users.id"), index=True)
    subject: Mapped[str] = mapped_column(String, nullable=False)  # Math, History, etc.
    topic: Mapped[str] = mapped_column(String, nullable=False)
    testDate: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True, index=True)

    # Study plan (generated by AI)
    studyPlan: Mapped[dict] = mapped_column(JSONB, default=dict, server_default='{}')
    # Example: {"sessions": [{"date": "2025-11-12", "duration": 30, "topics": ["algebra"]}]}

    # Status
    status: Mapped[str] = mapped_column(String, default="active")  # active|completed|cancelled

    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updatedAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    user = relationship("User", back_populates="study_items")
    sessions = relationship("StudySession", back_populates="study_item", cascade="all, delete-orphan")

    def __repr__(self):
        return f"<StudyItem(id={self.id}, subject={self.subject}, topic={self.topic})>"

class StudySession(Base):
    """Individual study sessions (20-30min blocks) with micro-quiz results"""
    __tablename__ = "study_sessions"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=gen_uuid)
    studyItemId: Mapped[str] = mapped_column(String, ForeignKey("study_items.id"), index=True)
    scheduledDate: Mapped[datetime] = mapped_column(DateTime, nullable=False, index=True)
    completedAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    # Quiz results
    quizQuestions: Mapped[dict] = mapped_column(JSONB, default=dict, server_default='{}')
    # Example: {"questions": [{"q": "What is 2+2?", "a": "4", "correct": true}]}

    score: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)  # Percentage 0-100

    # Relationships
    study_item = relationship("StudyItem", back_populates="sessions")

    def __repr__(self):
        return f"<StudySession(id={self.id}, studyItemId={self.studyItemId}, score={self.score})>"

class Media(Base):
    """Media storage metadata (photos for tasks, vision tips, etc.)"""
    __tablename__ = "media"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=gen_uuid)
    familyId: Mapped[str] = mapped_column(String, ForeignKey("families.id"), index=True)
    uploadedBy: Mapped[str] = mapped_column(String, ForeignKey("users.id"))

    # Storage
    url: Mapped[str] = mapped_column(String, nullable=False)  # Presigned URL or permanent URL
    storageKey: Mapped[str] = mapped_column(String, nullable=False)  # S3 key or storage path

    # Metadata
    mimeType: Mapped[str] = mapped_column(String, nullable=False)
    sizeBytes: Mapped[int] = mapped_column(Integer, nullable=False)

    # Security
    avScanStatus: Mapped[str] = mapped_column(String, default="pending")  # pending|clean|infected

    # Context
    context: Mapped[str] = mapped_column(String, nullable=False)  # task_proof|vision_tip|avatar
    contextId: Mapped[Optional[str]] = mapped_column(String, nullable=True)  # Task ID, etc.

    # Retention policy
    expiresAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)

    # Indexes
    __table_args__ = (
        Index('idx_media_family_context', 'familyId', 'context'),
        Index('idx_media_expires', 'expiresAt'),
    )

    def __repr__(self):
        return f"<Media(id={self.id}, context={self.context}, url={self.url})>"

class Notification(Base):
    """Notification queue for push, email, and in-app notifications"""
    __tablename__ = "notifications"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=gen_uuid)
    userId: Mapped[str] = mapped_column(String, ForeignKey("users.id"), index=True)

    # Notification type
    type: Mapped[str] = mapped_column(String, nullable=False)  # push|email|in_app

    # Content
    title: Mapped[str] = mapped_column(String, nullable=False)
    body: Mapped[str] = mapped_column(Text, nullable=False)

    # Payload for deep links
    payload: Mapped[dict] = mapped_column(JSONB, default=dict, server_default='{}')
    # Example: {"taskId": "123", "route": "/tasks/123"}

    # Status
    status: Mapped[str] = mapped_column(String, default="pending")  # pending|sent|failed
    sentAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    readAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    # Scheduling
    scheduledFor: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True, index=True)

    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    # Indexes
    __table_args__ = (
        Index('idx_notification_user_status', 'userId', 'status'),
        Index('idx_notification_scheduled', 'scheduledFor', 'status'),
    )

    def __repr__(self):
        return f"<Notification(id={self.id}, userId={self.userId}, type={self.type}, status={self.status})>"

class DeviceToken(Base):
    __tablename__ = "device_tokens"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=gen_uuid)
    userId: Mapped[str] = mapped_column(String, ForeignKey("users.id"), index=True)
    platform: Mapped[str] = mapped_column(String, nullable=False)  # ios|android|web
    token: Mapped[str] = mapped_column(String, nullable=False, unique=True)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    def __repr__(self):
        return f"<DeviceToken(id={self.id}, userId={self.userId}, platform={self.platform})>"

class WebPushSub(Base):
    __tablename__ = "webpush_subs"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=gen_uuid)
    userId: Mapped[str] = mapped_column(String, ForeignKey("users.id"), index=True)
    endpoint: Mapped[str] = mapped_column(String, nullable=False)
    p256dh: Mapped[str] = mapped_column(String, nullable=False)
    auth: Mapped[str] = mapped_column(String, nullable=False)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    def __repr__(self):
        return f"<WebPushSub(id={self.id}, userId={self.userId})>"

class AuditLog(Base):
    __tablename__ = "audit_log"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=gen_uuid)
    actorUserId: Mapped[str] = mapped_column(String, ForeignKey("users.id"), index=True)
    familyId: Mapped[str] = mapped_column(String, ForeignKey("families.id"), index=True)
    action: Mapped[str] = mapped_column(String, nullable=False)

    # Metadata (JSONB for flexibility)
    meta: Mapped[dict] = mapped_column(JSONB, default=dict, server_default='{}')

    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)

    # Indexes for audit queries
    __table_args__ = (
        Index('idx_audit_family_created', 'familyId', 'createdAt'),
        Index('idx_audit_actor_action', 'actorUserId', 'action'),
    )

    def __repr__(self):
        return f"<AuditLog(id={self.id}, action={self.action}, actorUserId={self.actorUserId})>"

class HelperInvite(Base):
    """Helper invite system for temporary access (babysitters, grandparents, etc.)"""
    __tablename__ = "helper_invites"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=gen_uuid)
    familyId: Mapped[str] = mapped_column(String, ForeignKey("families.id"), index=True)
    createdById: Mapped[str] = mapped_column(String, ForeignKey("users.id"), nullable=False)

    # 6-digit PIN code
    code: Mapped[str] = mapped_column(String(6), unique=True, nullable=False, index=True)

    # Invitee details
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    email: Mapped[str] = mapped_column(String(255), nullable=False)

    # Access period
    startDate: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    endDate: Mapped[datetime] = mapped_column(DateTime, nullable=False)

    # Permissions (JSONB)
    permissions: Mapped[dict] = mapped_column(JSONB, nullable=False, default=dict, server_default='{}')
    # Example: {"can_view": true, "can_complete": true, "can_upload_photos": false}

    # Expiration (code expires after 7 days)
    expiresAt: Mapped[datetime] = mapped_column(DateTime, nullable=False)

    # Usage tracking
    used: Mapped[bool] = mapped_column(Boolean, default=False)
    usedAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    usedById: Mapped[Optional[str]] = mapped_column(String, ForeignKey("users.id"), nullable=True)

    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    # Indexes
    __table_args__ = (
        Index('idx_helper_invite_code', 'code'),
        Index('idx_helper_invite_family', 'familyId'),
    )

    def __repr__(self):
        return f"<HelperInvite(id={self.id}, code={self.code}, used={self.used})>"

class AIUsageLog(Base):
    """Track AI planning usage for premium limit enforcement"""
    __tablename__ = "ai_usage_log"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=gen_uuid)
    userId: Mapped[str] = mapped_column(String, ForeignKey("users.id"), index=True)
    action: Mapped[str] = mapped_column(String, nullable=False)  # 'plan_week' | 'generate_tasks' | 'study_plan'

    # Metadata
    meta: Mapped[dict] = mapped_column("metadata", JSONB, default=dict, server_default='{}')
    # Example: {"tasks_generated": 5, "model": "gpt-4", "tokens": 1200}

    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)

    # Indexes for daily limit queries
    __table_args__ = (
        Index('idx_ai_usage_user_created', 'userId', 'createdAt'),
    )

    def __repr__(self):
        return f"<AIUsageLog(id={self.id}, userId={self.userId}, action={self.action})>"
