"""add ai_usage_log table for cost monitoring

Revision ID: 0003
Revises: 0002
Create Date: 2025-11-11

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic
revision = '0003'
down_revision = '0002_complete_mvp_schema'
branch_labels = None
depends_on = None

def upgrade():
    """Add ai_usage_log table for AI cost tracking and monitoring"""
    op.create_table(
        'ai_usage_log',
        sa.Column('id', sa.String(), nullable=False),
        sa.Column('timestamp', sa.DateTime(), nullable=False, server_default=sa.text('CURRENT_TIMESTAMP')),
        sa.Column('model', sa.String(), nullable=False),
        sa.Column('endpoint', sa.String(), nullable=False),
        sa.Column('tokens_in', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('tokens_out', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('cost_usd', sa.Float(), nullable=False, server_default='0.0'),
        sa.Column('cache_hit', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('fallback_tier', sa.Integer(), nullable=False, server_default='1'),
        sa.Column('family_id', sa.String(), nullable=False),
        sa.Column('response_time_ms', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('error', sa.String(), nullable=True),
        sa.PrimaryKeyConstraint('id')
    )

    # Create indexes for efficient querying
    op.create_index('idx_ai_usage_timestamp', 'ai_usage_log', ['timestamp'])
    op.create_index('idx_ai_usage_model', 'ai_usage_log', ['model'])
    op.create_index('idx_ai_usage_family_id', 'ai_usage_log', ['family_id'])
    op.create_index('idx_ai_usage_endpoint', 'ai_usage_log', ['endpoint'])

def downgrade():
    """Remove ai_usage_log table"""
    op.drop_index('idx_ai_usage_endpoint', 'ai_usage_log')
    op.drop_index('idx_ai_usage_family_id', 'ai_usage_log')
    op.drop_index('idx_ai_usage_model', 'ai_usage_log')
    op.drop_index('idx_ai_usage_timestamp', 'ai_usage_log')
    op.drop_table('ai_usage_log')
