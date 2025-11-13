"""add premium fields to family and user tables

Revision ID: 0005
Revises: 0004
Create Date: 2025-11-11

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic
revision = '0005'
down_revision = '0004'
branch_labels = None
depends_on = None

def upgrade():
    """Add premium monetization fields to Family and User tables"""

    # Add premium fields to families table
    op.add_column('families', sa.Column('familyUnlock', sa.Boolean(), nullable=False, server_default='false'))
    op.add_column('families', sa.Column('familyUnlockPurchasedAt', sa.DateTime(), nullable=True))
    op.add_column('families', sa.Column('familyUnlockPurchasedById', sa.String(), nullable=True))

    # Add foreign key for familyUnlockPurchasedById
    op.create_foreign_key(
        'fk_families_unlock_purchased_by',
        'families', 'users',
        ['familyUnlockPurchasedById'], ['id']
    )

    # Add premium subscription fields to users table
    op.add_column('users', sa.Column('premiumUntil', sa.DateTime(), nullable=True))
    op.add_column('users', sa.Column('premiumPlan', sa.String(), nullable=True))
    op.add_column('users', sa.Column('premiumPaymentId', sa.String(), nullable=True))

    # Add indexes for premium queries
    op.create_index('idx_users_premium_until', 'users', ['premiumUntil'])
    op.create_index('idx_families_family_unlock', 'families', ['familyUnlock'])

def downgrade():
    """Remove premium fields"""

    # Drop indexes
    op.drop_index('idx_families_family_unlock', 'families')
    op.drop_index('idx_users_premium_until', 'users')

    # Drop foreign key
    op.drop_constraint('fk_families_unlock_purchased_by', 'families', type_='foreignkey')

    # Drop columns from users
    op.drop_column('users', 'premiumPaymentId')
    op.drop_column('users', 'premiumPlan')
    op.drop_column('users', 'premiumUntil')

    # Drop columns from families
    op.drop_column('families', 'familyUnlockPurchasedById')
    op.drop_column('families', 'familyUnlockPurchasedAt')
    op.drop_column('families', 'familyUnlock')
