-- Verify that functions have immutable search_path configured
SELECT
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as arguments,
  p.prosecdef as security_definer,
  p.proconfig as config_settings,
  CASE
    WHEN p.proconfig IS NOT NULL AND 'search_path=public' = ANY(p.proconfig)
    THEN '✅ FIXED'
    ELSE '❌ MISSING search_path'
  END as status
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND p.proname IN ('get_user_family_id', 'is_user_parent', 'update_updated_at_column', 'get_user_total_points')
ORDER BY p.proname;

-- Also check if triggers exist
SELECT
  tgname as trigger_name,
  tgrelid::regclass as table_name,
  proname as function_name
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE tgname LIKE 'update_%_updated_at'
ORDER BY tgname;
