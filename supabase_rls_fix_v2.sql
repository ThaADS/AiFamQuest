-- ============================================
-- FIX: Infinite recursion in RLS policies (v2 - PUBLIC SCHEMA)
-- ============================================
-- Run this in: Supabase Dashboard → SQL Editor → New Query
-- Problem: users table policy references itself, causing infinite loop
-- Solution: Use helper functions in PUBLIC schema (not auth)

-- ============================================
-- 1. DROP PROBLEMATIC POLICIES
-- ============================================

DROP POLICY IF EXISTS "Users can view family members" ON public.users;
DROP POLICY IF EXISTS "Users can view own family" ON public.families;
DROP POLICY IF EXISTS "Parents can update family" ON public.families;
DROP POLICY IF EXISTS "Family members can view tasks" ON public.tasks;
DROP POLICY IF EXISTS "Assignees can complete tasks" ON public.tasks;
DROP POLICY IF EXISTS "Family members can view events" ON public.events;
DROP POLICY IF EXISTS "Parents can manage events" ON public.events;
DROP POLICY IF EXISTS "Family members can view media" ON public.media;

-- ============================================
-- 2. CREATE HELPER FUNCTIONS IN PUBLIC SCHEMA
-- ============================================

-- Function to get user's family_id directly from auth.uid()
CREATE OR REPLACE FUNCTION public.get_user_family_id()
RETURNS UUID AS $$
  SELECT family_id FROM public.users WHERE id = auth.uid();
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

-- Function to check if user is parent
CREATE OR REPLACE FUNCTION public.is_user_parent()
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
  ON public.users FOR SELECT
  USING (id = auth.uid());

-- Allow users to view family members (using helper function)
CREATE POLICY "Users can view family members via function"
  ON public.users FOR SELECT
  USING (family_id = public.get_user_family_id());

-- Allow users to update own profile
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
CREATE POLICY "Users can update own profile"
  ON public.users FOR UPDATE
  USING (id = auth.uid());

-- ============================================
-- FAMILIES TABLE POLICIES (Fixed)
-- ============================================

-- Users can view their own family (using helper function)
CREATE POLICY "Users can view own family via function"
  ON public.families FOR SELECT
  USING (id = public.get_user_family_id());

-- Parents can update family (using helper function)
CREATE POLICY "Parents can update family via function"
  ON public.families FOR UPDATE
  USING (id = public.get_user_family_id() AND public.is_user_parent());

-- ============================================
-- TASKS TABLE POLICIES (Fixed)
-- ============================================

-- Family members can view tasks (using helper function)
CREATE POLICY "Family members can view tasks via function"
  ON public.tasks FOR SELECT
  USING (family_id = public.get_user_family_id());

-- Parents can create tasks
DROP POLICY IF EXISTS "Parents can create tasks" ON public.tasks;
CREATE POLICY "Parents can create tasks"
  ON public.tasks FOR INSERT
  WITH CHECK (
    family_id = public.get_user_family_id() AND public.is_user_parent()
  );

-- Assignees can complete tasks (using helper function)
CREATE POLICY "Assignees can complete tasks via function"
  ON public.tasks FOR UPDATE
  USING (
    auth.uid() = ANY(assignees) OR
    (family_id = public.get_user_family_id() AND public.is_user_parent())
  );

-- ============================================
-- EVENTS TABLE POLICIES (Fixed)
-- ============================================

-- Family members can view events (using helper function)
CREATE POLICY "Family members can view events via function"
  ON public.events FOR SELECT
  USING (family_id = public.get_user_family_id());

-- Parents can manage events (using helper function)
CREATE POLICY "Parents can manage events via function"
  ON public.events FOR ALL
  USING (family_id = public.get_user_family_id() AND public.is_user_parent());

-- ============================================
-- MEDIA TABLE POLICIES (Fixed)
-- ============================================

-- Family members can view media (using helper function)
CREATE POLICY "Family members can view media via function"
  ON public.media FOR SELECT
  USING (family_id = public.get_user_family_id());

-- ============================================
-- 4. GRANT PERMISSIONS FOR ANON/AUTHENTICATED ROLES
-- ============================================

-- Allow anon role to read users/families for demo account verification
GRANT SELECT ON public.users TO anon;
GRANT SELECT ON public.families TO anon;
GRANT SELECT ON public.tasks TO anon;
GRANT SELECT ON public.events TO anon;

-- Allow authenticated users full access (RLS controls what they see)
GRANT ALL ON public.users TO authenticated;
GRANT ALL ON public.families TO authenticated;
GRANT ALL ON public.tasks TO authenticated;
GRANT ALL ON public.events TO authenticated;
GRANT ALL ON public.points_ledger TO authenticated;
GRANT ALL ON public.badges TO authenticated;
GRANT ALL ON public.rewards TO authenticated;
GRANT ALL ON public.user_streaks TO authenticated;
GRANT ALL ON public.study_items TO authenticated;
GRANT ALL ON public.study_sessions TO authenticated;
GRANT ALL ON public.media TO authenticated;
GRANT ALL ON public.device_tokens TO authenticated;
GRANT ALL ON public.webpush_subs TO authenticated;
GRANT ALL ON public.audit_log TO authenticated;
GRANT ALL ON public.helpers TO authenticated;
GRANT ALL ON public.task_logs TO authenticated;

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
WHERE routine_schema = 'public'
AND routine_name IN ('get_user_family_id', 'is_user_parent');

-- ============================================
-- MIGRATION COMPLETE
-- ============================================
-- Now run this in Supabase Dashboard SQL Editor.
-- After running, test demo account with curl (replace YOUR_ANON_KEY):
--
-- curl "https://vtjtmaajygckpguzceuc.supabase.co/rest/v1/users?email=eq.demo@famquest.app" \
--   -H "apikey: YOUR_ANON_KEY" \
--   -H "Authorization: Bearer YOUR_ANON_KEY"
