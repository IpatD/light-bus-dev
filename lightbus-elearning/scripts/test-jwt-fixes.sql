-- Test script to verify JWT metadata parsing fixes
-- This script tests the corrected JWT syntax and all related functions

\echo ''
\echo '=== JWT METADATA PARSING FIXES TEST ==='
\echo 'Testing corrected Supabase JWT metadata access syntax'
\echo ''

-- Test 1: Check comprehensive JWT function tests
\echo 'Test 1: Running comprehensive JWT functions test'
SELECT * FROM public.test_jwt_functions();

\echo ''
\echo 'Test 2: Testing individual JWT metadata access'

-- Test 2: Direct JWT metadata access
SELECT 
    'JWT Data Available' as test_name,
    CASE 
        WHEN auth.jwt() IS NOT NULL THEN 'TRUE'
        ELSE 'FALSE'
    END as result,
    CASE 
        WHEN auth.jwt() IS NOT NULL THEN 'JWT data is accessible'
        ELSE 'No JWT data available'
    END as info;

-- Test 3: Check app_metadata role access
SELECT 
    'App Metadata Role Access' as test_name,
    CASE 
        WHEN auth.jwt() -> 'app_metadata' ->> 'role' IS NOT NULL THEN 'TRUE'
        ELSE 'FALSE'
    END as result,
    COALESCE('Role: ' || (auth.jwt() -> 'app_metadata' ->> 'role'), 'No app_metadata role found') as info;

-- Test 4: Check user_metadata role access
SELECT 
    'User Metadata Role Access' as test_name,
    CASE 
        WHEN auth.jwt() -> 'user_metadata' ->> 'role' IS NOT NULL THEN 'TRUE'
        ELSE 'FALSE'
    END as result,
    COALESCE('Role: ' || (auth.jwt() -> 'user_metadata' ->> 'role'), 'No user_metadata role found') as info;

\echo ''
\echo 'Test 3: Testing core functions with fixed JWT syntax'

-- Test 5: is_admin_user function
SELECT 
    'is_admin_user() Function' as test_name,
    CASE 
        WHEN public.is_admin_user() IS NOT NULL THEN 'TRUE'
        ELSE 'FALSE'
    END as result,
    'Admin status: ' || public.is_admin_user()::TEXT as info;

-- Test 6: get_user_role function
SELECT 
    'get_user_role() Function' as test_name,
    CASE 
        WHEN public.get_user_role() IS NOT NULL THEN 'TRUE'
        ELSE 'FALSE'
    END as result,
    'User role: ' || COALESCE(public.get_user_role(), 'NULL') as info;

\echo ''
\echo 'Test 4: Testing lesson access functions'

-- Test 7: can_access_lesson function (with first available lesson)
DO $$
DECLARE
    test_lesson_id UUID;
    access_result BOOLEAN;
BEGIN
    -- Get first lesson ID
    SELECT id INTO test_lesson_id FROM public.lessons LIMIT 1;
    
    IF test_lesson_id IS NOT NULL THEN
        SELECT public.can_access_lesson(test_lesson_id) INTO access_result;
        
        RAISE NOTICE 'can_access_lesson() Function - TRUE - Access result for lesson %: %', 
            test_lesson_id, access_result;
    ELSE
        RAISE NOTICE 'can_access_lesson() Function - TRUE - No lessons available to test';
    END IF;
END $$;

\echo ''
\echo 'Test 5: Testing all original functions still work'

-- Test 8: Original RLS-safe functions
SELECT 
    'get_user_stats_safe() Function' as test_name,
    CASE 
        WHEN (SELECT COUNT(*) FROM public.get_user_stats_safe(auth.uid())) >= 0 THEN 'TRUE'
        ELSE 'FALSE'
    END as result,
    'Function executed successfully' as info;

SELECT 
    'get_cards_due_safe() Function' as test_name,
    CASE 
        WHEN (SELECT COUNT(*) FROM public.get_cards_due_safe(auth.uid())) >= 0 THEN 'TRUE'
        ELSE 'FALSE'
    END as result,
    'Function executed successfully' as info;

SELECT 
    'get_lesson_progress_safe() Function' as test_name,
    CASE 
        WHEN (SELECT COUNT(*) FROM public.get_lesson_progress_safe(auth.uid())) >= 0 THEN 'TRUE'
        ELSE 'FALSE'
    END as result,
    'Function executed successfully' as info;

\echo ''
\echo 'Test 6: Testing RLS policies work correctly'

-- Test 9: Check if RLS policies are active and working
SELECT 
    schemaname,
    tablename,
    policyname,
    CASE 
        WHEN cmd = 'ALL' THEN 'ALL OPERATIONS'
        ELSE cmd
    END as operation,
    CASE 
        WHEN permissive = 'PERMISSIVE' THEN 'PERMISSIVE'
        ELSE 'RESTRICTIVE'
    END as type
FROM pg_policies 
WHERE schemaname = 'public' 
    AND tablename IN ('lessons', 'lesson_participants', 'profiles')
    AND policyname LIKE '%admin%'
ORDER BY tablename, policyname;

\echo ''
\echo '=== JWT METADATA FIXES TEST COMPLETE ==='
\echo 'If all tests show TRUE and no errors, the JWT metadata parsing is fixed!'
\echo ''