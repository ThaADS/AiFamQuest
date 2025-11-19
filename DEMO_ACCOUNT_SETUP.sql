-- ============================================
-- FamQuest Demo Account Setup
-- ============================================
-- Run this in Supabase Dashboard → SQL Editor after migration

-- 1. Create demo family
INSERT INTO families (id, name, plan)
VALUES ('550e8400-e29b-41d4-a716-446655440000', 'Demo Familie', 'free')
ON CONFLICT (id) DO NOTHING;

-- 2. Create demo user account
-- Note: This creates a user record, but they still need to sign up via Auth
-- We'll use Supabase Dashboard to create the actual auth user

-- After creating user via Dashboard Authentication → Add User:
-- Email: demo@famquest.app
-- Password: Demo2024!FamQuest
-- Auto Confirm: YES

-- Then run this to link the user to the family:
-- UPDATE users
-- SET family_id = '550e8400-e29b-41d4-a716-446655440000',
--     role = 'parent',
--     display_name = 'Demo Ouder'
-- WHERE email = 'demo@famquest.app';

-- 3. Add some demo tasks for testing
INSERT INTO tasks (id, family_id, title, description, category, status, points, created_by, created_at)
SELECT
  gen_random_uuid(),
  '550e8400-e29b-41d4-a716-446655440000',
  'Vaatwasser leegruimen',
  'Alle schone borden, kopjes en bestek opruimen',
  'cleaning',
  'open',
  15,
  (SELECT id FROM users WHERE email = 'demo@famquest.app' LIMIT 1),
  NOW()
WHERE EXISTS (SELECT 1 FROM users WHERE email = 'demo@famquest.app');

INSERT INTO tasks (id, family_id, title, description, category, status, points, created_by, created_at)
SELECT
  gen_random_uuid(),
  '550e8400-e29b-41d4-a716-446655440000',
  'Tafel dekken',
  'Tafel dekken voor het avondeten',
  'cleaning',
  'open',
  10,
  (SELECT id FROM users WHERE email = 'demo@famquest.app' LIMIT 1),
  NOW()
WHERE EXISTS (SELECT 1 FROM users WHERE email = 'demo@famquest.app');

INSERT INTO tasks (id, family_id, title, description, category, status, points, created_by, created_at)
SELECT
  gen_random_uuid(),
  '550e8400-e29b-41d4-a716-446655440000',
  'Huiswerk maken',
  'Wiskunde opdrachten afmaken',
  'homework',
  'open',
  20,
  (SELECT id FROM users WHERE email = 'demo@famquest.app' LIMIT 1),
  NOW()
WHERE EXISTS (SELECT 1 FROM users WHERE email = 'demo@famquest.app');

-- 4. Add demo calendar event
INSERT INTO events (id, family_id, title, description, start_time, end_time, created_by, created_at)
SELECT
  gen_random_uuid(),
  '550e8400-e29b-41d4-a716-446655440000',
  'Familie diner',
  'Samen eten om 18:00',
  NOW() + INTERVAL '2 hours',
  NOW() + INTERVAL '3 hours',
  (SELECT id FROM users WHERE email = 'demo@famquest.app' LIMIT 1),
  NOW()
WHERE EXISTS (SELECT 1 FROM users WHERE email = 'demo@famquest.app');

-- 5. Add some demo points
INSERT INTO points_ledger (id, user_id, family_id, delta, reason, created_at)
SELECT
  gen_random_uuid(),
  (SELECT id FROM users WHERE email = 'demo@famquest.app' LIMIT 1),
  '550e8400-e29b-41d4-a716-446655440000',
  50,
  'Welkomstbonus',
  NOW()
WHERE EXISTS (SELECT 1 FROM users WHERE email = 'demo@famquest.app');

-- 6. Add demo badge
INSERT INTO badges (id, user_id, code, awarded_at)
SELECT
  gen_random_uuid(),
  (SELECT id FROM users WHERE email = 'demo@famquest.app' LIMIT 1),
  'first_task',
  NOW()
WHERE EXISTS (SELECT 1 FROM users WHERE email = 'demo@famquest.app');

-- 7. Verify setup
SELECT
  'Demo account setup complete!' as message,
  (SELECT COUNT(*) FROM families WHERE id = '550e8400-e29b-41d4-a716-446655440000') as family_count,
  (SELECT COUNT(*) FROM users WHERE email = 'demo@famquest.app') as user_count,
  (SELECT COUNT(*) FROM tasks WHERE family_id = '550e8400-e29b-41d4-a716-446655440000') as task_count;
