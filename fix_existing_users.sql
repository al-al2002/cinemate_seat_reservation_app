-- =============================================
-- FIX EXISTING AUTHENTICATED USERS
-- Run this AFTER running database_migration.sql
-- =============================================

-- This will insert any authenticated users from auth.users
-- that don't yet exist in public.users table

INSERT INTO public.users (id, email, full_name, password, role, created_at, updated_at)
SELECT
  au.id,
  au.email,
  COALESCE(au.raw_user_meta_data->>'full_name', au.email) as full_name,
  'auth_managed' as password, -- Placeholder since auth.users manages passwords
  'user' as role,
  au.created_at,
  NOW() as updated_at
FROM auth.users au
WHERE NOT EXISTS (
  SELECT 1 FROM public.users pu WHERE pu.id = au.id
);

-- Check if insert was successful
SELECT
  COUNT(*) as total_auth_users,
  (SELECT COUNT(*) FROM public.users) as total_public_users
FROM auth.users;

-- If numbers match, you're good to go!
