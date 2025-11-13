from alembic import op
import sqlalchemy as sa
revision = '0001_initial'
down_revision = None
def upgrade():
    op.create_table('families', sa.Column('id', sa.String(), primary_key=True), sa.Column('name', sa.String(), nullable=False))
    op.create_table('users',
        sa.Column('id', sa.String(), primary_key=True),
        sa.Column('familyId', sa.String(), index=True),
        sa.Column('email', sa.String(), unique=True, index=True),
        sa.Column('displayName', sa.String()),
        sa.Column('role', sa.String()),
        sa.Column('passwordHash', sa.String()),
        sa.Column('locale', sa.String()),
        sa.Column('theme', sa.String()),
        sa.Column('twoFAEnabled', sa.Boolean()),
        sa.Column('twoFASecret', sa.String()),
        sa.Column('createdAt', sa.DateTime()),
    )
    op.create_table('tasks',
        sa.Column('id', sa.String(), primary_key=True),
        sa.Column('familyId', sa.String(), index=True),
        sa.Column('title', sa.String()),
        sa.Column('desc', sa.String()),
        sa.Column('due', sa.String()),
        sa.Column('assignees', sa.String()),
        sa.Column('status', sa.String()),
        sa.Column('points', sa.Integer()),
        sa.Column('updatedAt', sa.DateTime()),
        sa.Column('version', sa.Integer(), server_default='0', nullable=False),
    )
    op.create_table('points_ledger',
        sa.Column('id', sa.String(), primary_key=True),
        sa.Column('userId', sa.String()),
        sa.Column('delta', sa.Integer()),
        sa.Column('reason', sa.String()),
        sa.Column('createdAt', sa.DateTime()),
    )
    op.create_table('badges',
        sa.Column('id', sa.String(), primary_key=True),
        sa.Column('userId', sa.String()),
        sa.Column('code', sa.String()),
        sa.Column('awardedAt', sa.DateTime()),
    )
    op.create_table('rewards',
        sa.Column('id', sa.String(), primary_key=True),
        sa.Column('familyId', sa.String()),
        sa.Column('name', sa.String()),
        sa.Column('cost', sa.Integer()),
    )
    op.create_table('device_tokens',
        sa.Column('id', sa.String(), primary_key=True),
        sa.Column('userId', sa.String()),
        sa.Column('platform', sa.String()),
        sa.Column('token', sa.String()),
        sa.Column('createdAt', sa.DateTime()),
    )
    op.create_table('webpush_subs',
        sa.Column('id', sa.String(), primary_key=True),
        sa.Column('userId', sa.String()),
        sa.Column('endpoint', sa.String()),
        sa.Column('p256dh', sa.String()),
        sa.Column('auth', sa.String()),
    )
    op.create_table('audit_log',
        sa.Column('id', sa.String(), primary_key=True),
        sa.Column('actorUserId', sa.String()),
        sa.Column('familyId', sa.String()),
        sa.Column('action', sa.String()),
        sa.Column('meta', sa.String()),
        sa.Column('createdAt', sa.DateTime()),
    )
def downgrade():
    for t in ['audit_log','webpush_subs','device_tokens','rewards','badges','points_ledger','tasks','users','families']:
        op.drop_table(t)
