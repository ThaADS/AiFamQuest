-- ============================================
-- FIX: Infinite recursion in RLS policies
-- ============================================
-- Run this in: Supabase Dashboard → SQL Editor → New Query
-- Problem: users table policy references itself, causing infinite loop
-- Solution: Use direct auth.uid() checks instead of subqueries

-- ============================================
-- 1. DROP PROBLEMATIC POLICIES
-- ============================================

DROP POLICY IF EXISTS "Users can view family members" ON users;
DROP POLICY IF EXISTS "Users can view own family" ON families;
DROP POLICY IF EXISTS "Parents can update family" ON families;
DROP POLICY IF EXISTS "Family members can view tasks" ON tasks;
DROP POLICY IF EXISTS "Assignees can complete tasks" ON tasks;
DROP POLICY IF EXISTS "Family members can view events" ON events;
DROP POLICY IF EXISTS "Parents can manage events" ON events;
DROP POLICY IF EXISTS "Family members can view media" ON media;

-- ============================================
-- 2. CREATE HELPER FUNCTION (Non-recursive)
-- ============================================

-- Function to get user's family_id directly from auth.uid()
CREATE OR REPLACE FUNCTION auth.user_family_id()
RETURNS UUID AS $$
  SELECT family_id FROM public.users WHERE id = auth.uid();
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

-- Function to check if user is parent
CREATE OR REPLACE FUNCTION auth.is_parent()
RETURNS BOOLEAN AS $$
  SELECT role = 'parent' FROM public.users WHERE id = auth.uid();
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

-- ============================================
-- 3. CREATE FIXED RLS POLICIES
-- ============================================

-- ============================================
-- USERS TABLE POLICIES (Fixed)
-- ============================================

-- Allow users to view their own profile (always safe)
CREATE POLICY "Users can view own profile"
  ON users FOR SELECT
  USING (id = auth.uid());

-- Allow users to view family members (using helper function)
CREATE POLICY "Users can view family members via function"
  ON users FOR SELECT
  USING (family_id = auth.user_family_id());

-- Allow users to update own profile
-- (This policy already exists and is correct - recreating for completeness)
DROP POLICY IF EXISTS "Users can update own profile" ON users;
CREATE POLICY "Users can update own profile"
  ON users FOR UPDATE
  USING (id = auth.uid());

-- ============================================
-- FAMILIES TABLE POLICIES (Fixed)
-- ============================================

-- Users can view their own family (using helper function)
CREATE POLICY "Users can view own family via function"
  ON families FOR SELECT
  USING (id = auth.user_family_id());

-- Parents can update family (using helper function)
CREATE POLICY "Parents can update family via function"
  ON families FOR UPDATE
  USING (id = auth.user_family_id() AND auth.is_parent());

-- ============================================
-- TASKS TABLE POLICIES (Fixed)
-- ============================================

-- Family members can view tasks (using helper function)
CREATE POLICY "Family members can view tasks via function"
  ON tasks FOR SELECT
  USING (family_id = auth.user_family_id());

-- Parents can create tasks (already correct, but recreating)
DROP POLICY IF EXISTS "Parents can create tasks" ON tasks;
CREATE POLICY "Parents can create tasks"
  ON tasks FOR INSERT
  WITH CHECK (
    family_id = auth.user_family_id() AND auth.is_parent()
  );

-- Assignees can complete tasks (using helper function)
CREATE POLICY "Assignees can complete tasks via function"
  ON tasks FOR UPDATE
  USING (
    auth.uid() = ANY(assignees) OR
    (family_id = auth.user_family_id() AND auth.is_parent())
  );

-- ============================================
-- EVENTS TABLE POLICIES (Fixed)
-- ============================================

-- Family members can view events (using helper function)
CREATE POLICY "Family members can view events via function"
  ON events FOR SELECT
  USING (family_id = auth.user_family_id());

-- Parents can manage events (using helper function)
CREATE POLICY "Parents can manage events via function"
  ON events FOR ALL
  USING (family_id = auth.user_family_id() AND auth.is_parent());

-- ============================================
-- MEDIA TABLE POLICIES (Fixed)
-- ============================================

-- Family members can view media (using helper function)
CREATE POLICY "Family members can view media via function"
  ON media FOR SELECT
  USING (family_id = auth.user_family_id());

-- ============================================
-- 4. GRANT PERMISSIONS FOR ANON/AUTHENTICATED ROLES
-- ============================================

-- Allow anon role to read users/families for demo account verification
-- (Safe because RLS policies still apply)
GRANT SELECT ON users TO anon;
GRANT SELECT ON families TO anon;
GRANT SELECT ON tasks TO anon;
GRANT SELECT ON events TO anon;

-- Allow authenticated users full access (RLS controls what they see)
GRANT ALL ON users TO authenticated;
GRANT ALL ON families TO authenticated;
GRANT ALL ON tasks TO authenticated;
GRANT ALL ON events TO authenticated;
GRANT ALL ON points_ledger TO authenticated;
GRANT ALL ON badges TO authenticated;
GRANT ALL ON rewards TO authenticated;
GRANT ALL ON user_streaks TO authenticated;
GRANT ALL ON study_items TO authenticated;
GRANT ALL ON study_sessions TO authenticated;
GRANT ALL ON media TO authenticated;
GRANT ALL ON device_tokens TO authenticated;
GRANT ALL ON webpush_subs TO authenticated;
GRANT ALL ON audit_log TO authenticated;
GRANT ALL ON helpers TO authenticated;
GRANT ALL ON task_logs TO authenticated;

-- ============================================
-- 5. VERIFICATION QUERIES
-- ============================================

-- Test 1: Check if policies are created
SELECT schemaname, tablename, policyname, permissive, roles, cmd
FROM pg_policies
WHERE tablename IN ('users', 'families', 'tasks', 'events')
ORDER BY tablename, policyname;

-- Test 2: Check helper functions exist
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'auth'
AND routine_name IN ('user_family_id', 'is_parent');

-- ============================================
-- MIGRATION COMPLETE
-- ============================================
-- Expected result: No infinite recursion errors
-- Demo account test should now work with:
-- curl "https://vtjtmaajygckpguzceuc.supabase.co/rest/v1/users?email=eq.demo@famquest.app" \
--   -H "apikey: YOUR_ANON_KEY"
