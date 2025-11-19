-- FamQuest - Supabase Security Hardening
-- Fixes for database linter warnings

-- ==============================================
-- 1. Fix Function Search Path (Security Warning)
-- ==============================================
-- PostgreSQL functions should have immutable search_path to prevent
-- privilege escalation attacks via schema manipulation

-- Drop existing functions first (to avoid parameter name conflicts)
DROP FUNCTION IF EXISTS public.get_user_family_id(uuid);
DROP FUNCTION IF EXISTS public.is_user_parent(uuid);
DROP FUNCTION IF EXISTS public.update_updated_at_column() CASCADE;  -- CASCADE: drops dependent triggers too
DROP FUNCTION IF EXISTS public.get_user_total_points(uuid);

-- Fix: get_user_family_id
CREATE FUNCTION public.get_user_family_id(user_uuid uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public  -- ✅ FIXED: Immutable search path
AS $$
DECLARE
  v_family_id uuid;
BEGIN
  SELECT family_id INTO v_family_id
  FROM public.users
  WHERE id = user_uuid;

  RETURN v_family_id;
END;
$$;

-- Fix: is_user_parent
CREATE FUNCTION public.is_user_parent(user_uuid uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public  -- ✅ FIXED: Immutable search path
AS $$
DECLARE
  v_role text;
BEGIN
  SELECT role INTO v_role
  FROM public.users
  WHERE id = user_uuid;

  RETURN v_role = 'parent';
END;
$$;

-- Fix: update_updated_at_column (trigger function)
CREATE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public  -- ✅ FIXED: Immutable search path
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- Recreate triggers that were dropped by CASCADE
CREATE TRIGGER update_families_updated_at
  BEFORE UPDATE ON public.families
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_users_updated_at
  BEFORE UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_tasks_updated_at
  BEFORE UPDATE ON public.tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_events_updated_at
  BEFORE UPDATE ON public.events
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_study_items_updated_at
  BEFORE UPDATE ON public.study_items
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- Fix: get_user_total_points
CREATE FUNCTION public.get_user_total_points(user_uuid uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public  -- ✅ FIXED: Immutable search path
AS $$
DECLARE
  v_total integer;
BEGIN
  SELECT COALESCE(SUM(delta), 0) INTO v_total
  FROM public.points_ledger
  WHERE user_id = user_uuid;

  RETURN v_total;
END;
$$;

-- ==============================================
-- 2. Enable Leaked Password Protection (Auth Warning)
-- ==============================================
-- This prevents users from using compromised passwords from HaveIBeenPwned.org
-- IMPORTANT: This must be enabled in Supabase Dashboard → Authentication → Providers
-- Go to: https://supabase.com/dashboard/project/[YOUR_PROJECT]/auth/providers
-- Enable: "Leaked Password Protection"

-- Alternative: Via SQL (if you have direct database access)
-- UPDATE auth.config
-- SET leaked_password_check = true
-- WHERE id = 'auth';

COMMENT ON SCHEMA public IS 'FamQuest Security Hardening Complete - 2025-11-19';
