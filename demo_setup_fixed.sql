-- ============================================
-- DEMO ACCOUNT SETUP (FIXED - CamelCase columns)
-- ============================================
-- Run in: Supabase Dashboard → SQL Editor
-- Auth User ID: a4335064-1784-441e-840b-e1a4c4a7c5e1
-- Email: demo.famquest@gmail.com
-- Password: Demo2024FamQuest

-- ============================================
-- 1. CREATE DEMO FAMILY
-- ============================================
INSERT INTO public.families (id, name, plan, "createdAt")
VALUES (
  'f0000000-0000-0000-0000-000000000001'::uuid,
  'Demo Gezin',
  'premium',
  NOW()
)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  plan = EXCLUDED.plan;

-- ============================================
-- 2. CREATE DEMO PARENT USER
-- ============================================
INSERT INTO public.users (
  id,
  "familyId",
  email,
  "displayName",
  role,
  locale,
  theme,
  avatar,
  permissions,
  sso,
  "twoFAEnabled",
  "emailVerified",
  "createdAt",
  "updatedAt"
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
  '{"childCanCreateTasks": true, "childCanCreateStudyItems": true}'::jsonb,
  '{"providers": ["email"], "emailVerified": true}'::jsonb,
  false,
  true,
  NOW(),
  NOW()
)
ON CONFLICT (id) DO UPDATE SET
  email = EXCLUDED.email,
  "displayName" = EXCLUDED."displayName",
  "familyId" = EXCLUDED."familyId",
  "updatedAt" = NOW();

-- ============================================
-- 3. VERIFY USER CREATED
-- ============================================
SELECT id, email, "displayName", role, "familyId"
FROM public.users
WHERE email = 'demo.famquest@gmail.com';
