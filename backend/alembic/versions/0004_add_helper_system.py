"""add helper system

Revision ID: 0004
Revises: 0003
Create Date: 2025-11-11

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = '0004'
down_revision = '0003'
branch_labels = None
depends_on = None


def upgrade():
    """
    Add helper invite system and helper-specific user fields.

    Changes:
    1. Add helperStartDate and helperEndDate to users table
    2. Create helper_invites table
    """

    # Add helper fields to users table
    op.add_column('users', sa.Column('helperStartDate', sa.DateTime(timezone=True), nullable=True))
    op.add_column('users', sa.Column('helperEndDate', sa.DateTime(timezone=True), nullable=True))

    # Create helper_invites table
    op.create_table(
        'helper_invites',
        sa.Column('id', sa.String(), nullable=False),
        sa.Column('familyId', sa.String(), nullable=False),
        sa.Column('createdById', sa.String(), nullable=False),
        sa.Column('code', sa.String(length=6), nullable=False),
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('email', sa.String(length=255), nullable=False),
        sa.Column('startDate', sa.DateTime(timezone=True), nullable=False),
        sa.Column('endDate', sa.DateTime(timezone=True), nullable=False),
        sa.Column('permissions', postgresql.JSONB, nullable=False, server_default='{}'),
        sa.Column('expiresAt', sa.DateTime(timezone=True), nullable=False),
        sa.Column('used', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('usedAt', sa.DateTime(timezone=True), nullable=True),
        sa.Column('usedById', sa.String(), nullable=True),
        sa.Column('createdAt', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.ForeignKeyConstraint(['familyId'], ['families.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['createdById'], ['users.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['usedById'], ['users.id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('code')
    )

    # Create indexes
    op.create_index('idx_helper_invite_code', 'helper_invites', ['code'])
    op.create_index('idx_helper_invite_family', 'helper_invites', ['familyId'])


def downgrade():
    """
    Rollback helper system changes.
    """
    # Drop helper_invites table
    op.drop_index('idx_helper_invite_family', table_name='helper_invites')
    op.drop_index('idx_helper_invite_code', table_name='helper_invites')
    op.drop_table('helper_invites')

    # Remove helper fields from users table
    op.drop_column('users', 'helperEndDate')
    op.drop_column('users', 'helperStartDate')
