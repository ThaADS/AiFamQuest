-- Add grid_layout column to users table
-- This column stores the user's custom grid layout for the home screen
-- Format: JSONB array of GridItem objects

ALTER TABLE users ADD COLUMN IF NOT EXISTS grid_layout JSONB DEFAULT '[]'::jsonb;

-- Add index for faster queries
CREATE INDEX IF NOT EXISTS idx_users_grid_layout ON users USING GIN (grid_layout);

-- Add comment for documentation
COMMENT ON COLUMN users.grid_layout IS 'User customized home screen grid layout (iPhone-style draggable icons)';
