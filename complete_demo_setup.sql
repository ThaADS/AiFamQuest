-- ============================================
-- COMPLETE DEMO ACCOUNT SETUP
-- ============================================
-- Run in: Supabase Dashboard → SQL Editor
-- User ID: a4335064-1784-441e-840b-e1a4c4a7c5e1
-- Email: demo.famquest@gmail.com
-- Password: Demo2024FamQuest

-- ============================================
-- 1. CREATE DEMO FAMILY
-- ============================================
INSERT INTO public.families (id, name, plan, created_at)
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
    "providers": ["email"],
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
  family_id = EXCLUDED.family_id,
  updated_at = NOW();

-- ============================================
-- 3. CREATE DEMO CHILD USERS
-- ============================================
INSERT INTO public.users (id, family_id, email, display_name, role, locale, theme, avatar, permissions, sso, two_fa_enabled, created_at, updated_at)
VALUES
  -- Noah (10 jaar)
  (gen_random_uuid(), 'f0000000-0000-0000-0000-000000000001'::uuid, 'noah@demo.local', 'Noah', 'child', 'nl', 'cartoony', '🧒', '{"childCanCreateTasks": false}', '{}', false, NOW(), NOW()),
  -- Luna (8 jaar)
  (gen_random_uuid(), 'f0000000-0000-0000-0000-000000000001'::uuid, 'luna@demo.local', 'Luna', 'child', 'nl', 'cartoony', '👧', '{"childCanCreateTasks": false}', '{}', false, NOW(), NOW()),
  -- Sam (14 jaar - teen)
  (gen_random_uuid(), 'f0000000-0000-0000-0000-000000000001'::uuid, 'sam@demo.local', 'Sam', 'teen', 'nl', 'minimal', '🧑', '{"childCanCreateTasks": true}', '{}', false, NOW(), NOW())
ON CONFLICT (email) DO NOTHING;

-- ============================================
-- 4. CREATE DEMO TASKS
-- ============================================
DO $$
DECLARE
  noah_id uuid;
  luna_id uuid;
  sam_id uuid;
BEGIN
  -- Get user IDs
  SELECT id INTO noah_id FROM public.users WHERE email = 'noah@demo.local';
  SELECT id INTO luna_id FROM public.users WHERE email = 'luna@demo.local';
  SELECT id INTO sam_id FROM public.users WHERE email = 'sam@demo.local';

  -- Insert tasks
  INSERT INTO public.tasks (id, family_id, title, description, category, frequency, rrule, due, assignees, points, photo_required, parent_approval, status, priority, est_duration, created_by, created_at, updated_at, version)
  VALUES
    -- Daily tasks
    (gen_random_uuid(), 'f0000000-0000-0000-0000-000000000001'::uuid, 'Vaatwasser uitruimen', 'Alle schone vaat opbergen in de kasten', 'cleaning', 'daily', 'FREQ=DAILY', NOW() + interval '2 hours', ARRAY[noah_id], 10, false, false, 'open', 'med', 15, 'a4335064-1784-441e-840b-e1a4c4a7c5e1'::uuid, NOW(), NOW(), 1),

    (gen_random_uuid(), 'f0000000-0000-0000-0000-000000000001'::uuid, 'Speelgoed opruimen', 'Alle speelgoed terug in de speelgoedkist', 'cleaning', 'daily', 'FREQ=DAILY', NOW() + interval '1 hour', ARRAY[luna_id], 5, false, false, 'open', 'low', 10, 'a4335064-1784-441e-840b-e1a4c4a7c5e1'::uuid, NOW(), NOW(), 1),

    (gen_random_uuid(), 'f0000000-0000-0000-0000-000000000001'::uuid, 'Hond uitlaten', 'Max 20 minuten uitlaten in het park', 'pet', 'daily', 'FREQ=DAILY', NOW() + interval '3 hours', ARRAY[sam_id], 15, true, false, 'open', 'high', 20, 'a4335064-1784-441e-840b-e1a4c4a7c5e1'::uuid, NOW(), NOW(), 1),

    -- Weekly tasks
    (gen_random_uuid(), 'f0000000-0000-0000-0000-000000000001'::uuid, 'Kamer stofzuigen', 'Hele kamer inclusief onder het bed', 'cleaning', 'weekly', 'FREQ=WEEKLY;BYDAY=SA', NOW() + interval '2 days', ARRAY[noah_id], 20, false, true, 'open', 'med', 30, 'a4335064-1784-441e-840b-e1a4c4a7c5e1'::uuid, NOW(), NOW(), 1),

    (gen_random_uuid(), 'f0000000-0000-0000-0000-000000000001'::uuid, 'Planten water geven', 'Alle planten in huis water geven', 'care', 'weekly', 'FREQ=WEEKLY;BYDAY=SU', NOW() + interval '3 days', ARRAY[luna_id], 10, false, false, 'open', 'low', 15, 'a4335064-1784-441e-840b-e1a4c4a7c5e1'::uuid, NOW(), NOW(), 1);
END $$;

-- ============================================
-- 5. CREATE DEMO EVENTS (Calendar)
-- ============================================
DO $$
DECLARE
  noah_id uuid;
  luna_id uuid;
  sam_id uuid;
  parent_id uuid := 'a4335064-1784-441e-840b-e1a4c4a7c5e1'::uuid;
BEGIN
  SELECT id INTO noah_id FROM public.users WHERE email = 'noah@demo.local';
  SELECT id INTO luna_id FROM public.users WHERE email = 'luna@demo.local';
  SELECT id INTO sam_id FROM public.users WHERE email = 'sam@demo.local';

  INSERT INTO public.events (id, family_id, title, description, start_time, end_time, all_day, attendees, color, location, created_by, created_at, updated_at)
  VALUES
    -- Today
    (gen_random_uuid(), 'f0000000-0000-0000-0000-000000000001'::uuid, 'Voetbaltraining Noah', 'Training op het sportveld', NOW() + interval '5 hours', NOW() + interval '6 hours 30 minutes', false, ARRAY[noah_id, parent_id], '#4CAF50', 'Sportpark De Eendracht', parent_id, NOW(), NOW()),

    -- Tomorrow
    (gen_random_uuid(), 'f0000000-0000-0000-0000-000000000001'::uuid, 'Muziekles Luna', 'Piano les bij mevrouw Jansen', NOW() + interval '1 day 4 hours', NOW() + interval '1 day 5 hours', false, ARRAY[luna_id, parent_id], '#FF9800', 'Muziekschool', parent_id, NOW(), NOW()),

    (gen_random_uuid(), 'f0000000-0000-0000-0000-000000000001'::uuid, 'Gezinsavond', 'Film kijken en popcorn maken!', NOW() + interval '1 day 8 hours', NOW() + interval '1 day 10 hours', false, ARRAY[noah_id, luna_id, sam_id, parent_id], '#9C27B0', 'Thuis', parent_id, NOW(), NOW()),

    -- This weekend
    (gen_random_uuid(), 'f0000000-0000-0000-0000-000000000001'::uuid, 'Oma bezoeken', 'Koffie bij oma in het verzorgingstehuis', NOW() + interval '4 days 2 hours', NOW() + interval '4 days 4 hours', false, ARRAY[noah_id, luna_id, parent_id], '#2196F3', 'Verzorgingstehuis De Wilgen', parent_id, NOW(), NOW());
END $$;

-- ============================================
-- 6. AWARD DEMO POINTS & BADGES
-- ============================================
DO $$
DECLARE
  noah_id uuid;
  luna_id uuid;
  sam_id uuid;
BEGIN
  SELECT id INTO noah_id FROM public.users WHERE email = 'noah@demo.local';
  SELECT id INTO luna_id FROM public.users WHERE email = 'luna@demo.local';
  SELECT id INTO sam_id FROM public.users WHERE email = 'sam@demo.local';

  -- Award initial points
  INSERT INTO public.points_ledger (id, user_id, family_id, delta, reason, multiplier, created_at)
  VALUES
    (gen_random_uuid(), noah_id, 'f0000000-0000-0000-0000-000000000001'::uuid, 50, 'Welcome bonus!', 1.0, NOW()),
    (gen_random_uuid(), luna_id, 'f0000000-0000-0000-0000-000000000001'::uuid, 50, 'Welcome bonus!', 1.0, NOW()),
    (gen_random_uuid(), sam_id, 'f0000000-0000-0000-0000-000000000001'::uuid, 75, 'Welcome bonus (teen)', 1.0, NOW());

  -- Award first task badge
  INSERT INTO public.badges (id, user_id, code, metadata, awarded_at)
  VALUES
    (gen_random_uuid(), noah_id, 'first_task', '{"tier": 1}'::jsonb, NOW()),
    (gen_random_uuid(), luna_id, 'first_task', '{"tier": 1}'::jsonb, NOW());
END $$;

-- ============================================
-- 7. CREATE DEMO REWARDS (Shop)
-- ============================================
INSERT INTO public.rewards (id, family_id, name, description, cost, icon, category, active, created_at)
VALUES
  (gen_random_uuid(), 'f0000000-0000-0000-0000-000000000001'::uuid, '30 min extra schermtijd', 'Extra tijd op iPad of TV', 50, '📺', 'perk', true, NOW()),
  (gen_random_uuid(), 'f0000000-0000-0000-0000-000000000001'::uuid, 'Kies het avondeten', 'Jij mag kiezen wat we eten!', 100, '🍕', 'perk', true, NOW()),
  (gen_random_uuid(), 'f0000000-0000-0000-0000-000000000001'::uuid, 'Superhelden avatar', 'Cool superheld avatar unlock', 75, '🦸', 'avatar', true, NOW()),
  (gen_random_uuid(), 'f0000000-0000-0000-0000-000000000001'::uuid, 'Uitslapen op zaterdag', 'Geen vroeg opstaan dit weekend!', 150, '😴', 'perk', true, NOW()),
  (gen_random_uuid(), 'f0000000-0000-0000-0000-000000000001'::uuid, 'Space theme unlock', 'Ruimte thema voor je profiel', 200, '🚀', 'theme', true, NOW());

-- ============================================
-- 8. VERIFICATION QUERIES
-- ============================================

-- Check family
SELECT * FROM public.families WHERE id = 'f0000000-0000-0000-0000-000000000001'::uuid;

-- Check users
SELECT id, email, display_name, role, family_id
FROM public.users
WHERE family_id = 'f0000000-0000-0000-0000-000000000001'::uuid
ORDER BY role, display_name;

-- Check tasks
SELECT id, title, category, frequency, assignees, points, status
FROM public.tasks
WHERE family_id = 'f0000000-0000-0000-0000-000000000001'::uuid
ORDER BY due;

-- Check events
SELECT id, title, start_time, attendees
FROM public.events
WHERE family_id = 'f0000000-0000-0000-0000-000000000001'::uuid
ORDER BY start_time;

-- Check points
SELECT u.display_name, SUM(pl.delta) as total_points
FROM public.points_ledger pl
JOIN public.users u ON pl.user_id = u.id
WHERE pl.family_id = 'f0000000-0000-0000-0000-000000000001'::uuid
GROUP BY u.display_name
ORDER BY total_points DESC;

-- Check rewards
SELECT name, cost, category FROM public.rewards
WHERE family_id = 'f0000000-0000-0000-0000-000000000001'::uuid
ORDER BY cost;

-- ============================================
-- SETUP COMPLETE!
-- ============================================
-- Login with: demo.famquest@gmail.com / Demo2024FamQuest
