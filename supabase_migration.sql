-- ============================================
-- FamQuest Complete Database Schema for Supabase
-- ============================================
-- This script creates all tables with Supabase Auth integration
-- Run this in: Supabase Dashboard → SQL Editor → New Query

-- ============================================
-- 1. CORE TABLES
-- ============================================

-- Families table
CREATE TABLE IF NOT EXISTS families (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  plan TEXT DEFAULT 'free' CHECK (plan IN ('free', 'family_unlock', 'premium')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Users table (linked to Supabase Auth)
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  family_id UUID REFERENCES families(id) ON DELETE CASCADE,
  email TEXT UNIQUE NOT NULL,
  display_name TEXT,
  role TEXT DEFAULT 'child' CHECK (role IN ('parent', 'teen', 'child', 'helper')),
  locale TEXT DEFAULT 'nl' CHECK (locale IN ('nl', 'en', 'de', 'fr', 'tr', 'pl', 'ar')),
  theme TEXT DEFAULT 'cartoony' CHECK (theme IN ('cartoony', 'minimal', 'classy', 'dark', 'custom')),
  avatar TEXT,
  pin TEXT, -- For child accounts (4-6 digits)
  email_verified BOOLEAN DEFAULT FALSE,
  permissions JSONB DEFAULT '{}'::jsonb, -- {childCanCreateTasks, childCanCreateStudyItems}
  sso JSONB DEFAULT '{}'::jsonb, -- {providers: ['google', 'apple'], emailVerified}
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_family ON users(family_id);
CREATE INDEX IF NOT EXISTS idx_user_family_role ON users(family_id, role);
CREATE INDEX IF NOT EXISTS idx_user_email ON users(email);

-- ============================================
-- 2. TASK MANAGEMENT
-- ============================================

-- Tasks table
CREATE TABLE IF NOT EXISTS tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT DEFAULT '',
  category TEXT DEFAULT 'other' CHECK (category IN ('cleaning', 'care', 'pet', 'homework', 'other')),
  frequency TEXT DEFAULT 'none' CHECK (frequency IN ('none', 'daily', 'weekly', 'cron')),
  rrule TEXT, -- iCal RRULE for recurrence
  due TIMESTAMPTZ,
  assignees UUID[] DEFAULT '{}', -- Array of user IDs
  claimable BOOLEAN DEFAULT FALSE,
  claimed_by UUID REFERENCES users(id) ON DELETE SET NULL,
  claimed_at TIMESTAMPTZ,
  points INTEGER DEFAULT 10,
  photo_required BOOLEAN DEFAULT FALSE,
  parent_approval BOOLEAN DEFAULT FALSE,
  proof_photos TEXT[] DEFAULT '{}', -- Array of S3 URLs
  priority TEXT DEFAULT 'med' CHECK (priority IN ('low', 'med', 'high')),
  est_duration INTEGER DEFAULT 15, -- minutes
  status TEXT DEFAULT 'open' CHECK (status IN ('open', 'pendingApproval', 'done')),
  created_by UUID NOT NULL REFERENCES users(id),
  completed_by UUID REFERENCES users(id),
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  version INTEGER DEFAULT 0 -- Optimistic locking
);

CREATE INDEX IF NOT EXISTS idx_task_family ON tasks(family_id);
CREATE INDEX IF NOT EXISTS idx_task_family_status ON tasks(family_id, status);
CREATE INDEX IF NOT EXISTS idx_task_due ON tasks(due);
CREATE INDEX IF NOT EXISTS idx_task_claimable ON tasks(family_id, claimable, status);
CREATE INDEX IF NOT EXISTS idx_task_updated ON tasks(updated_at);

-- Task logs (history)
CREATE TABLE IF NOT EXISTS task_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id),
  action TEXT NOT NULL, -- 'created', 'completed', 'approved', 'rejected'
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_task_log_task ON task_logs(task_id);
CREATE INDEX IF NOT EXISTS idx_task_log_created ON task_logs(created_at);

-- ============================================
-- 3. CALENDAR
-- ============================================

-- Events table
CREATE TABLE IF NOT EXISTS events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT DEFAULT '',
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ,
  all_day BOOLEAN DEFAULT FALSE,
  attendees UUID[] DEFAULT '{}', -- Array of user IDs
  color TEXT, -- Hex color per user
  rrule TEXT, -- iCal RRULE for recurring events
  category TEXT DEFAULT 'other',
  created_by UUID NOT NULL REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_event_family ON events(family_id);
CREATE INDEX IF NOT EXISTS idx_event_start ON events(start_time);
CREATE INDEX IF NOT EXISTS idx_event_family_start ON events(family_id, start_time);

-- ============================================
-- 4. GAMIFICATION
-- ============================================

-- Points ledger
CREATE TABLE IF NOT EXISTS points_ledger (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  delta INTEGER NOT NULL, -- Can be negative for penalties
  reason TEXT NOT NULL,
  task_id UUID REFERENCES tasks(id) ON DELETE SET NULL,
  reward_id UUID, -- Reference to rewards (defined below)
  multiplier FLOAT DEFAULT 1.0, -- on_time, quality, streak bonuses
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_points_user ON points_ledger(user_id);
CREATE INDEX IF NOT EXISTS idx_points_user_created ON points_ledger(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_points_family ON points_ledger(family_id);

-- Badges
CREATE TABLE IF NOT EXISTS badges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  code TEXT NOT NULL, -- 'first_task', 'week_streak', 'speed_demon', etc.
  metadata JSONB DEFAULT '{}'::jsonb, -- {tier, progress, custom_data}
  awarded_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_badge_user ON badges(user_id);
CREATE INDEX IF NOT EXISTS idx_badge_user_code ON badges(user_id, code);

-- Rewards (Shop)
CREATE TABLE IF NOT EXISTS rewards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT DEFAULT '',
  cost INTEGER NOT NULL, -- points required
  icon TEXT, -- emoji or image URL
  category TEXT DEFAULT 'custom' CHECK (category IN ('avatar', 'theme', 'perk', 'custom')),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reward_family ON rewards(family_id);

-- User streaks
CREATE TABLE IF NOT EXISTS user_streaks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  current_streak INTEGER DEFAULT 0,
  longest_streak INTEGER DEFAULT 0,
  last_completion_date DATE,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_streak_user ON user_streaks(user_id);

-- ============================================
-- 5. AI FEATURES
-- ============================================

-- Study items (Homework Coach)
CREATE TABLE IF NOT EXISTS study_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subject TEXT NOT NULL,
  topic TEXT NOT NULL,
  test_date TIMESTAMPTZ,
  study_plan JSONB DEFAULT '{}'::jsonb, -- AI-generated backward planning
  status TEXT DEFAULT 'active' CHECK (status IN ('planning', 'active', 'completed')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_study_user ON study_items(user_id);
CREATE INDEX IF NOT EXISTS idx_study_test_date ON study_items(test_date);

-- Study sessions
CREATE TABLE IF NOT EXISTS study_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  study_item_id UUID NOT NULL REFERENCES study_items(id) ON DELETE CASCADE,
  scheduled_at TIMESTAMPTZ NOT NULL,
  duration INTEGER DEFAULT 30, -- minutes
  completed BOOLEAN DEFAULT FALSE,
  quiz_results JSONB DEFAULT '{}'::jsonb, -- {score, questions, answers}
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_session_study_item ON study_sessions(study_item_id);
CREATE INDEX IF NOT EXISTS idx_session_scheduled ON study_sessions(scheduled_at);

-- ============================================
-- 6. MEDIA & STORAGE
-- ============================================

-- Media (Photos, attachments)
CREATE TABLE IF NOT EXISTS media (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  uploaded_by UUID NOT NULL REFERENCES users(id),
  type TEXT DEFAULT 'photo' CHECK (type IN ('photo', 'document', 'avatar')),
  storage_path TEXT NOT NULL, -- Supabase Storage path
  url TEXT, -- Public URL (if applicable)
  virus_scan TEXT DEFAULT 'pending' CHECK (virus_scan IN ('pending', 'clean', 'infected')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ -- Data retention policy
);

CREATE INDEX IF NOT EXISTS idx_media_family ON media(family_id);
CREATE INDEX IF NOT EXISTS idx_media_uploaded_by ON media(uploaded_by);

-- ============================================
-- 7. NOTIFICATIONS
-- ============================================

-- Device tokens (Push notifications)
CREATE TABLE IF NOT EXISTS device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  platform TEXT NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
  token TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_device_user ON device_tokens(user_id);

-- Web push subscriptions
CREATE TABLE IF NOT EXISTS webpush_subs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  endpoint TEXT NOT NULL,
  p256dh TEXT NOT NULL, -- Encryption key
  auth TEXT NOT NULL, -- Authentication secret
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_webpush_user ON webpush_subs(user_id);

-- ============================================
-- 8. AUDIT & SECURITY
-- ============================================

-- Audit log
CREATE TABLE IF NOT EXISTS audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_user_id UUID REFERENCES users(id),
  family_id UUID REFERENCES families(id),
  action TEXT NOT NULL, -- 'task_created', 'task_completed', 'user_invited', etc.
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_family_created ON audit_log(family_id, created_at);
CREATE INDEX IF NOT EXISTS idx_audit_actor_action ON audit_log(actor_user_id, action);

-- ============================================
-- 9. HELPER SYSTEM (Optional)
-- ============================================

-- Helpers (External users with limited access)
CREATE TABLE IF NOT EXISTS helpers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  invite_code TEXT UNIQUE NOT NULL,
  name TEXT,
  qr_code TEXT, -- Base64 QR code image
  accepted_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_helper_family ON helpers(family_id);
CREATE INDEX IF NOT EXISTS idx_helper_invite_code ON helpers(invite_code);

-- ============================================
-- 10. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================

-- Enable RLS on all tables
ALTER TABLE families ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE points_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_streaks ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE media ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE webpush_subs ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE helpers ENABLE ROW LEVEL SECURITY;

-- Family policies: Users can view their own family
DROP POLICY IF EXISTS "Users can view own family" ON families;
CREATE POLICY "Users can view own family"
  ON families FOR SELECT
  USING (id IN (
    SELECT family_id FROM users WHERE id = auth.uid()
  ));

DROP POLICY IF EXISTS "Parents can update family" ON families;
CREATE POLICY "Parents can update family"
  ON families FOR UPDATE
  USING (id IN (
    SELECT family_id FROM users WHERE id = auth.uid() AND role = 'parent'
  ));

-- User policies: Users can view family members
DROP POLICY IF EXISTS "Users can view family members" ON users;
CREATE POLICY "Users can view family members"
  ON users FOR SELECT
  USING (family_id IN (
    SELECT family_id FROM users WHERE id = auth.uid()
  ));

DROP POLICY IF EXISTS "Users can update own profile" ON users;
CREATE POLICY "Users can update own profile"
  ON users FOR UPDATE
  USING (id = auth.uid());

-- Task policies: Family members can view family tasks
DROP POLICY IF EXISTS "Family members can view tasks" ON tasks;
CREATE POLICY "Family members can view tasks"
  ON tasks FOR SELECT
  USING (family_id IN (
    SELECT family_id FROM users WHERE id = auth.uid()
  ));

DROP POLICY IF EXISTS "Parents can create tasks" ON tasks;
CREATE POLICY "Parents can create tasks"
  ON tasks FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
      AND role = 'parent'
      AND family_id = tasks.family_id
    )
  );

DROP POLICY IF EXISTS "Assignees can complete tasks" ON tasks;
CREATE POLICY "Assignees can complete tasks"
  ON tasks FOR UPDATE
  USING (
    auth.uid() = ANY(assignees) OR
    auth.uid() IN (
      SELECT id FROM users WHERE role = 'parent' AND family_id = tasks.family_id
    )
  );

-- Event policies: Family members can view events
DROP POLICY IF EXISTS "Family members can view events" ON events;
CREATE POLICY "Family members can view events"
  ON events FOR SELECT
  USING (family_id IN (
    SELECT family_id FROM users WHERE id = auth.uid()
  ));

DROP POLICY IF EXISTS "Parents can manage events" ON events;
CREATE POLICY "Parents can manage events"
  ON events FOR ALL
  USING (family_id IN (
    SELECT family_id FROM users WHERE id = auth.uid() AND role = 'parent'
  ));

-- Points/Badges policies: Users can view own points/badges
DROP POLICY IF EXISTS "Users can view own points" ON points_ledger;
CREATE POLICY "Users can view own points"
  ON points_ledger FOR SELECT
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can view own badges" ON badges;
CREATE POLICY "Users can view own badges"
  ON badges FOR SELECT
  USING (user_id = auth.uid());

-- Study items: Students own their study items
DROP POLICY IF EXISTS "Users can manage own study items" ON study_items;
CREATE POLICY "Users can manage own study items"
  ON study_items FOR ALL
  USING (user_id = auth.uid());

-- Media: Family members can view family media
DROP POLICY IF EXISTS "Family members can view media" ON media;
CREATE POLICY "Family members can view media"
  ON media FOR SELECT
  USING (family_id IN (
    SELECT family_id FROM users WHERE id = auth.uid()
  ));

-- ============================================
-- 11. FUNCTIONS & TRIGGERS
-- ============================================

-- Function: Update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger to all relevant tables
DROP TRIGGER IF EXISTS update_families_updated_at ON families;
CREATE TRIGGER update_families_updated_at BEFORE UPDATE ON families
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_tasks_updated_at ON tasks;
CREATE TRIGGER update_tasks_updated_at BEFORE UPDATE ON tasks
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_events_updated_at ON events;
CREATE TRIGGER update_events_updated_at BEFORE UPDATE ON events
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_study_items_updated_at ON study_items;
CREATE TRIGGER update_study_items_updated_at BEFORE UPDATE ON study_items
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function: Calculate user total points
CREATE OR REPLACE FUNCTION get_user_total_points(user_uuid UUID)
RETURNS INTEGER AS $$
  SELECT COALESCE(SUM(delta * multiplier), 0)::INTEGER
  FROM points_ledger
  WHERE user_id = user_uuid;
$$ LANGUAGE SQL STABLE;

-- ============================================
-- 12. INITIAL DATA (Optional)
-- ============================================

-- Insert default badge codes (for reference)
-- Badges are awarded dynamically by backend logic

-- Example family (for testing)
-- INSERT INTO families (id, name, plan) VALUES
--   ('00000000-0000-0000-0000-000000000001', 'Demo Family', 'free');

-- ============================================
-- MIGRATION COMPLETE
-- ============================================
-- Next steps:
-- 1. Configure Auth providers in Supabase Dashboard
-- 2. Set up Storage buckets for media uploads
-- 3. Configure Edge Functions for AI calls (optional)
-- 4. Test RLS policies with different user roles
