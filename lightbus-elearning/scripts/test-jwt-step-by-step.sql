-- Step-by-Step JWT Tests for Supabase SQL Editor
-- Copy and paste each query individually to see results

-- ==================================================
-- STEP 1: Test comprehensive JWT functions
-- ==================================================
SELECT * FROM public.test_jwt_functions();

-- ==================================================
-- STEP 2: Test JWT data availability
-- ==================================================
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

-- ==================================================
-- STEP 3: Test app_metadata role access
-- ==================================================
SELECT 
    'App Metadata Role Access' as test_name,
    CASE 
        WHEN auth.jwt() -> 'app_metadata' ->> 'role' IS NOT NULL THEN 'TRUE'
        ELSE 'FALSE'
    END as result,
    COALESCE('Role: ' || (auth.jwt() -> 'app_metadata' ->> 'role'), 'No app_metadata role found') as info;

-- ==================================================
-- STEP 4: Test user_metadata role access
-- ==================================================
SELECT 
    'User Metadata Role Access' as test_name,
    CASE 
        WHEN auth.jwt() -> 'user_metadata' ->> 'role' IS NOT NULL THEN 'TRUE'
        ELSE 'FALSE'
    END as result,
    COALESCE('Role: ' || (auth.jwt() -> 'user_metadata' ->> 'role'), 'No user_metadata role found') as info;

-- ==================================================
-- STEP 5: Test is_admin_user() function
-- ==================================================
SELECT 
    'is_admin_user() Function' as test_name,
    CASE 
        WHEN public.is_admin_user() IS NOT NULL THEN 'TRUE'
        ELSE 'FALSE'
    END as result,
    'Admin status: ' || public.is_admin_user()::TEXT as info;

-- ==================================================
-- STEP 6: Test get_user_role() function
-- ==================================================
SELECT 
    'get_user_role() Function' as test_name,
    CASE 
        WHEN public.get_user_role() IS NOT NULL THEN 'TRUE'
        ELSE 'FALSE'
    END as result,
    'User role: ' || COALESCE(public.get_user_role(), 'NULL') as info;

-- ==================================================
-- STEP 7: Test can_access_lesson() function
-- ==================================================
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

-- ==================================================
-- STEP 8: Test RLS policies
-- ==================================================
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

-- ==================================================
-- STEP 9: Final verification
-- ==================================================
SELECT 'TESTS COMPLETE' as status, 
       'Check all previous results - TRUE = success, FALSE = issue' as message;