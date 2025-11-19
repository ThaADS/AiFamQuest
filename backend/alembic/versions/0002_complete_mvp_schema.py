"""Complete MVP schema with 16 tables and enhanced fields

Revision ID: 0002_complete_mvp_schema
Revises: 0001_initial
Create Date: 2025-11-11

This migration adds:
- 7 new tables: events, task_logs, user_streaks, study_items, study_sessions, media, notifications
- Enhanced existing tables with missing PRD fields
- Composite indexes for query optimization
- JSONB fields for flexibility (permissions, sso, metadata)
- ARRAY fields for assignees, attendees, proofPhotos
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB, ARRAY

# SQLite fallback for JSONB/ARRAY so local dev with sqlite works
class SQLiteJSONB(sa.types.TypeDecorator):
    impl = sa.JSON
    cache_ok = True


class SQLiteARRAY(sa.types.TypeDecorator):
    impl = sa.JSON
    cache_ok = True


def jsonb():
    bind = op.get_bind()
    return SQLiteJSONB if bind.dialect.name == "sqlite" else JSONB


def array(type_):
    bind = op.get_bind()
    return SQLiteARRAY if bind.dialect.name == "sqlite" else ARRAY(type_)

revision = '0002_complete_mvp_schema'
down_revision = '0001_initial'

def upgrade():
    # 1. Add missing columns to existing tables

    # families table enhancements
    op.add_column('families', sa.Column('createdAt', sa.DateTime(), server_default=sa.func.now()))
    op.add_column('families', sa.Column('updatedAt', sa.DateTime(), server_default=sa.func.now(), onupdate=sa.func.now()))

    # users table enhancements
    op.add_column('users', sa.Column('avatar', sa.String(), nullable=True))
    op.add_column('users', sa.Column('emailVerified', sa.Boolean(), server_default='false', nullable=False))
    op.add_column('users', sa.Column('pin', sa.String(), nullable=True))
    op.add_column('users', sa.Column('permissions', jsonb(), server_default='{}', nullable=False))
    op.add_column('users', sa.Column('sso', jsonb(), server_default='{}', nullable=False))
    op.add_column('users', sa.Column('updatedAt', sa.DateTime(), server_default=sa.func.now(), onupdate=sa.func.now()))
    op.create_index('idx_user_family_role', 'users', ['familyId', 'role'])
    op.create_index('idx_user_email_verified', 'users', ['email', 'emailVerified'])

    # tasks table enhancements - first drop assignees column, then recreate as ARRAY
    op.drop_column('tasks', 'assignees')
    op.add_column('tasks', sa.Column('assignees', array(sa.String), server_default='{}', nullable=False))

    # tasks table - change due from String to DateTime
    op.drop_column('tasks', 'due')
    op.add_column('tasks', sa.Column('due', sa.DateTime(), nullable=True))
    op.create_index('idx_task_due', 'tasks', ['due'])

    # tasks table - add all missing PRD fields
    op.add_column('tasks', sa.Column('category', sa.String(), server_default='other', nullable=False))
    op.add_column('tasks', sa.Column('frequency', sa.String(), server_default='none', nullable=False))
    op.add_column('tasks', sa.Column('rrule', sa.String(), nullable=True))
    op.add_column('tasks', sa.Column('claimable', sa.Boolean(), server_default='false', nullable=False))
    op.add_column('tasks', sa.Column('claimedBy', sa.String(), nullable=True))
    op.add_column('tasks', sa.Column('claimedAt', sa.DateTime(), nullable=True))
    op.add_column('tasks', sa.Column('photoRequired', sa.Boolean(), server_default='false', nullable=False))
    op.add_column('tasks', sa.Column('parentApproval', sa.Boolean(), server_default='false', nullable=False))
    op.add_column('tasks', sa.Column('proofPhotos', array(sa.String), server_default='{}', nullable=False))
    op.add_column('tasks', sa.Column('priority', sa.String(), server_default='med', nullable=False))
    op.add_column('tasks', sa.Column('estDuration', sa.Integer(), server_default='15', nullable=False))
    op.add_column('tasks', sa.Column('createdBy', sa.String(), nullable=False))
    op.add_column('tasks', sa.Column('completedBy', sa.String(), nullable=True))
    op.add_column('tasks', sa.Column('completedAt', sa.DateTime(), nullable=True))
    op.add_column('tasks', sa.Column('createdAt', sa.DateTime(), server_default=sa.func.now(), nullable=False))

    # tasks table - composite indexes for hot queries
    op.create_index('idx_task_family_status', 'tasks', ['familyId', 'status'])
    op.create_index('idx_task_family_due', 'tasks', ['familyId', 'due'])
    op.create_index('idx_task_claimable', 'tasks', ['familyId', 'claimable', 'status'])
    op.create_index('idx_task_status', 'tasks', ['status'])
    op.create_index('idx_task_updated', 'tasks', ['updatedAt'])

    # points_ledger enhancements
    op.add_column('points_ledger', sa.Column('taskId', sa.String(), nullable=True))
    op.add_column('points_ledger', sa.Column('rewardId', sa.String(), nullable=True))
    op.create_index('idx_points_user_created', 'points_ledger', ['userId', 'createdAt'])

    # badges enhancements
    op.create_index('idx_badge_user_code', 'badges', ['userId', 'code'])

    # rewards enhancements
    op.add_column('rewards', sa.Column('description', sa.Text(), server_default='', nullable=False))
    op.add_column('rewards', sa.Column('icon', sa.String(), nullable=True))
    op.add_column('rewards', sa.Column('isActive', sa.Boolean(), server_default='true', nullable=False))
    op.add_column('rewards', sa.Column('createdAt', sa.DateTime(), server_default=sa.func.now()))

    # audit_log enhancements - convert meta from String to JSONB
    op.drop_column('audit_log', 'meta')
    op.add_column('audit_log', sa.Column('meta', jsonb(), server_default='{}', nullable=False))
    op.create_index('idx_audit_family_created', 'audit_log', ['familyId', 'createdAt'])
    op.create_index('idx_audit_actor_action', 'audit_log', ['actorUserId', 'action'])

    # 2. Create new tables

    # events table (Calendar)
    op.create_table(
        'events',
        sa.Column('id', sa.String(), primary_key=True),
        sa.Column('familyId', sa.String(), sa.ForeignKey('families.id'), index=True, nullable=False),
        sa.Column('title', sa.String(), nullable=False),
        sa.Column('description', sa.Text(), server_default='', nullable=False),
        sa.Column('start', sa.DateTime(), nullable=False, index=True),
        sa.Column('end', sa.DateTime(), nullable=True),
        sa.Column('allDay', sa.Boolean(), server_default='false', nullable=False),
        sa.Column('attendees', array(sa.String), server_default='{}', nullable=False),
        sa.Column('color', sa.String(), nullable=True),
        sa.Column('rrule', sa.String(), nullable=True),
        sa.Column('category', sa.String(), server_default='other', nullable=False),
        sa.Column('createdBy', sa.String(), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('createdAt', sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.Column('updatedAt', sa.DateTime(), server_default=sa.func.now(), onupdate=sa.func.now(), nullable=False),
    )
    op.create_index('idx_event_family_start', 'events', ['familyId', 'start'])
    op.create_index('idx_event_family_category', 'events', ['familyId', 'category'])

    # task_logs table (Task history)
    op.create_table(
        'task_logs',
        sa.Column('id', sa.String(), primary_key=True),
        sa.Column('taskId', sa.String(), sa.ForeignKey('tasks.id'), index=True, nullable=False),
        sa.Column('userId', sa.String(), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('action', sa.String(), nullable=False),
        sa.Column('metadata', jsonb(), server_default='{}', nullable=False),
        sa.Column('createdAt', sa.DateTime(), server_default=sa.func.now(), index=True, nullable=False),
    )

    # user_streaks table (Gamification)
    op.create_table(
        'user_streaks',
        sa.Column('id', sa.String(), primary_key=True),
        sa.Column('userId', sa.String(), sa.ForeignKey('users.id'), index=True, unique=True, nullable=False),
        sa.Column('currentStreak', sa.Integer(), server_default='0', nullable=False),
        sa.Column('longestStreak', sa.Integer(), server_default='0', nullable=False),
        sa.Column('lastCompletionDate', sa.DateTime(), nullable=True),
        sa.Column('updatedAt', sa.DateTime(), server_default=sa.func.now(), onupdate=sa.func.now(), nullable=False),
    )

    # study_items table (Homework Coach)
    op.create_table(
        'study_items',
        sa.Column('id', sa.String(), primary_key=True),
        sa.Column('userId', sa.String(), sa.ForeignKey('users.id'), index=True, nullable=False),
        sa.Column('subject', sa.String(), nullable=False),
        sa.Column('topic', sa.String(), nullable=False),
        sa.Column('testDate', sa.DateTime(), nullable=True, index=True),
        sa.Column('studyPlan', jsonb(), server_default='{}', nullable=False),
        sa.Column('status', sa.String(), server_default='active', nullable=False),
        sa.Column('createdAt', sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.Column('updatedAt', sa.DateTime(), server_default=sa.func.now(), onupdate=sa.func.now(), nullable=False),
    )

    # study_sessions table (Homework Coach sessions)
    op.create_table(
        'study_sessions',
        sa.Column('id', sa.String(), primary_key=True),
        sa.Column('studyItemId', sa.String(), sa.ForeignKey('study_items.id'), index=True, nullable=False),
        sa.Column('scheduledDate', sa.DateTime(), nullable=False, index=True),
        sa.Column('completedAt', sa.DateTime(), nullable=True),
        sa.Column('quizQuestions', jsonb(), server_default='{}', nullable=False),
        sa.Column('score', sa.Integer(), nullable=True),
    )

    # media table (Photo storage metadata)
    op.create_table(
        'media',
        sa.Column('id', sa.String(), primary_key=True),
        sa.Column('familyId', sa.String(), sa.ForeignKey('families.id'), index=True, nullable=False),
        sa.Column('uploadedBy', sa.String(), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('url', sa.String(), nullable=False),
        sa.Column('storageKey', sa.String(), nullable=False),
        sa.Column('mimeType', sa.String(), nullable=False),
        sa.Column('sizeBytes', sa.Integer(), nullable=False),
        sa.Column('avScanStatus', sa.String(), server_default='pending', nullable=False),
        sa.Column('context', sa.String(), nullable=False),
        sa.Column('contextId', sa.String(), nullable=True),
        sa.Column('expiresAt', sa.DateTime(), nullable=True),
        sa.Column('createdAt', sa.DateTime(), server_default=sa.func.now(), index=True, nullable=False),
    )
    op.create_index('idx_media_family_context', 'media', ['familyId', 'context'])
    op.create_index('idx_media_expires', 'media', ['expiresAt'])

    # notifications table (Push/Email queue)
    op.create_table(
        'notifications',
        sa.Column('id', sa.String(), primary_key=True),
        sa.Column('userId', sa.String(), sa.ForeignKey('users.id'), index=True, nullable=False),
        sa.Column('type', sa.String(), nullable=False),
        sa.Column('title', sa.String(), nullable=False),
        sa.Column('body', sa.Text(), nullable=False),
        sa.Column('payload', jsonb(), server_default='{}', nullable=False),
        sa.Column('status', sa.String(), server_default='pending', nullable=False),
        sa.Column('sentAt', sa.DateTime(), nullable=True),
        sa.Column('readAt', sa.DateTime(), nullable=True),
        sa.Column('scheduledFor', sa.DateTime(), nullable=True, index=True),
        sa.Column('createdAt', sa.DateTime(), server_default=sa.func.now(), nullable=False),
    )
    op.create_index('idx_notification_user_status', 'notifications', ['userId', 'status'])
    op.create_index('idx_notification_scheduled', 'notifications', ['scheduledFor', 'status'])


def downgrade():
    # Drop new tables (in reverse order of creation)
    op.drop_table('notifications')
    op.drop_table('media')
    op.drop_table('study_sessions')
    op.drop_table('study_items')
    op.drop_table('user_streaks')
    op.drop_table('task_logs')
    op.drop_table('events')

    # Remove added indexes from existing tables
    op.drop_index('idx_audit_actor_action', 'audit_log')
    op.drop_index('idx_audit_family_created', 'audit_log')
    op.drop_index('idx_badge_user_code', 'badges')
    op.drop_index('idx_points_user_created', 'points_ledger')
    op.drop_index('idx_task_updated', 'tasks')
    op.drop_index('idx_task_status', 'tasks')
    op.drop_index('idx_task_claimable', 'tasks')
    op.drop_index('idx_task_family_due', 'tasks')
    op.drop_index('idx_task_family_status', 'tasks')
    op.drop_index('idx_task_due', 'tasks')
    op.drop_index('idx_user_email_verified', 'users')
    op.drop_index('idx_user_family_role', 'users')

    # Revert audit_log changes
    op.drop_column('audit_log', 'meta')
    op.add_column('audit_log', sa.Column('meta', sa.String(), server_default=''))

    # Revert rewards changes
    op.drop_column('rewards', 'createdAt')
    op.drop_column('rewards', 'isActive')
    op.drop_column('rewards', 'icon')
    op.drop_column('rewards', 'description')

    # Revert points_ledger changes
    op.drop_column('points_ledger', 'rewardId')
    op.drop_column('points_ledger', 'taskId')

    # Revert tasks changes
    op.drop_column('tasks', 'createdAt')
    op.drop_column('tasks', 'completedAt')
    op.drop_column('tasks', 'completedBy')
    op.drop_column('tasks', 'createdBy')
    op.drop_column('tasks', 'estDuration')
    op.drop_column('tasks', 'priority')
    op.drop_column('tasks', 'proofPhotos')
    op.drop_column('tasks', 'parentApproval')
    op.drop_column('tasks', 'photoRequired')
    op.drop_column('tasks', 'claimedAt')
    op.drop_column('tasks', 'claimedBy')
    op.drop_column('tasks', 'claimable')
    op.drop_column('tasks', 'rrule')
    op.drop_column('tasks', 'frequency')
    op.drop_column('tasks', 'category')

    # Revert due column to String
    op.drop_column('tasks', 'due')
    op.add_column('tasks', sa.Column('due', sa.String(), nullable=True))

    # Revert assignees to String
    op.drop_column('tasks', 'assignees')
    op.add_column('tasks', sa.Column('assignees', sa.String(), server_default=''))

    # Revert users changes
    op.drop_column('users', 'updatedAt')
    op.drop_column('users', 'sso')
    op.drop_column('users', 'permissions')
    op.drop_column('users', 'pin')
    op.drop_column('users', 'emailVerified')
    op.drop_column('users', 'avatar')

    # Revert families changes
    op.drop_column('families', 'updatedAt')
    op.drop_column('families', 'createdAt')
