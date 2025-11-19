-- Create demo user directly in Supabase via Dashboard SQL Editor
-- Run this in: Supabase Dashboard → SQL Editor → New Query

-- Step 1: Create auth user with auto-confirmation
-- NOTE: You MUST do this via Dashboard UI (Authentication → Users → Add User)
-- because auth.users is protected and requires service_role key

-- After creating user in Dashboard UI, run this to create family + user record:

-- Insert demo family
INSERT INTO public.families (id, name, plan, created_at)
VALUES (
  'f0000000-0000-0000-0000-000000000001'::uuid,
  'Demo Gezin',
  'premium',
  NOW()
)
ON CONFLICT (id) DO NOTHING;

-- Insert demo parent user (link to auth user ID from Dashboard)
INSERT INTO public.users (
  id,
  family_id,
  email,
  display_name,
  role,
  locale,
  theme,
  avatar,
  permissions,
  sso,
  two_fa_enabled,
  created_at,
  updated_at
)
VALUES (
  'a4335064-1784-441e-840b-e1a4c4a7c5e1'::uuid,
  'f0000000-0000-0000-0000-000000000001'::uuid,
  'demo.famquest@gmail.com',
  'Demo Ouder',
  'parent',
  'nl',
  'minimal',
  '👨‍👩‍👧‍👦',
  '{
    "childCanCreateTasks": true,
    "childCanCreateStudyItems": true
  }'::jsonb,
  '{
    "providers": [],
    "emailVerified": true,
    "2faEnabled": false
  }'::jsonb,
  false,
  NOW(),
  NOW()
)
ON CONFLICT (id) DO UPDATE SET
  email = EXCLUDED.email,
  display_name = EXCLUDED.display_name,
  updated_at = NOW();

-- Verify user was created
SELECT id, email, display_name, role, family_id
FROM public.users
WHERE email = 'demo.famquest@gmail.com';
