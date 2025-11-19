-- ============================================
-- ULTRA SIMPLE DEMO SETUP
-- ============================================
-- Just insert minimal data to get login working

-- Step 1: Insert family (minimal columns)
INSERT INTO families (id, name)
VALUES ('f0000000-0000-0000-0000-000000000001'::uuid, 'Demo Gezin')
ON CONFLICT (id) DO NOTHING;

-- Step 2: Insert user (minimal columns, matching auth user ID)
INSERT INTO users (id, family_id, email, display_name, role)
VALUES (
  'a4335064-1784-441e-840b-e1a4c4a7c5e1'::uuid,
  'f0000000-0000-0000-0000-000000000001'::uuid,
  'demo.famquest@gmail.com',
  'Demo Ouder',
  'parent'
)
ON CONFLICT (id) DO UPDATE SET
  family_id = EXCLUDED.family_id,
  email = EXCLUDED.email;

-- Step 3: Verify
SELECT id, email, display_name, role, family_id FROM users WHERE email = 'demo.famquest@gmail.com';
