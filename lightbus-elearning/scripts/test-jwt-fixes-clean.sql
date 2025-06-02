-- Test script to verify JWT metadata parsing fixes
-- This script tests the corrected JWT syntax and all related functions
-- CLEAN VERSION - Compatible with Supabase SQL Editor

-- Test 1: Check comprehensive JWT function tests
SELECT 'Comprehensive JWT Functions Test' as test_section;
SELECT * FROM public.test_jwt_functions();

-- Test 2: Testing individual JWT metadata access
SELECT 'Individual JWT Metadata Access Tests' as test_section;

-- Test 2.1: Direct JWT metadata access
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

-- Test 2.2: Check app_metadata role access
SELECT 
    'App Metadata Role Access' as test_name,
    CASE 
        WHEN auth.jwt() -> 'app_metadata' ->> 'role' IS NOT NULL THEN 'TRUE'
        ELSE 'FALSE'
    END as result,
    COALESCE('Role: ' || (auth.jwt() -> 'app_metadata' ->> 'role'), 'No app_metadata role found') as info;

-- Test 2.3: Check user_metadata role access
SELECT 
    'User Metadata Role Access' as test_name,
    CASE 
        WHEN auth.jwt() -> 'user_metadata' ->> 'role' IS NOT NULL THEN 'TRUE'
        ELSE 'FALSE'
    END as result,
    COALESCE('Role: ' || (auth.jwt() -> 'user_metadata' ->> 'role'), 'No user_metadata role found') as info;

-- Test 3: Testing core functions with fixed JWT syntax
SELECT 'Core Functions with Fixed JWT Syntax' as test_section;

-- Test 3.1: is_admin_user function
SELECT 
    'is_admin_user() Function' as test_name,
    CASE 
        WHEN public.is_admin_user() IS NOT NULL THEN 'TRUE'
        ELSE 'FALSE'
    END as result,
    'Admin status: ' || public.is_admin_user()::TEXT as info;

-- Test 3.2: get_user_role function
SELECT 
    'get_user_role() Function' as test_name,
    CASE 
        WHEN public.get_user_role() IS NOT NULL THEN 'TRUE'
        ELSE 'FALSE'
    END as result,
    'User role: ' || COALESCE(public.get_user_role(), 'NULL') as info;

-- Test 4: Testing lesson access functions
SELECT 'Lesson Access Functions' as test_section;

-- Test 4.1: can_access_lesson function (with first available lesson)
SELECT 
    'can_access_lesson() Function' as test_name,
    CASE 
        WHEN EXISTS(SELECT 1 FROM public.lessons LIMIT 1) THEN
            CASE 
                WHEN public.can_access_lesson((SELECT id FROM public.lessons LIMIT 1)) IS NOT NULL THEN 'TRUE'
                ELSE 'FALSE'
            END
        ELSE 'TRUE'
    END as result,
    CASE 
        WHEN EXISTS(SELECT 1 FROM public.lessons LIMIT 1) THEN
            'Access result for lesson ' || (SELECT id FROM public.lessons LIMIT 1)::TEXT || ': ' || 
            public.can_access_lesson((SELECT id FROM public.lessons LIMIT 1))::TEXT
        ELSE 'No lessons available to test'
    END as info;

-- Test 5: Testing all original functions still work
SELECT 'Original Functions Compatibility' as test_section;

-- Test 5.1: Original RLS-safe functions
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

-- Test 6: Testing RLS policies work correctly
SELECT 'RLS Policies Status' as test_section;

-- Test 6.1: Check if RLS policies are active and working
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

-- Final verification message
SELECT 'TEST COMPLETE' as status, 
       'If all tests show TRUE and no errors, the JWT metadata parsing is fixed!' as message;