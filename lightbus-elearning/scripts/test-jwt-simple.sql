-- Simple JWT metadata test for Supabase SQL Editor
-- Quick verification that JWT functions work without errors

-- Quick Test 1: Basic JWT function execution
SELECT 'JWT Functions Quick Test' as test_type;

-- Test if functions execute without syntax errors
SELECT 
    'is_admin_user()' as function_name,
    public.is_admin_user() as result,
    'SUCCESS' as status;

SELECT 
    'get_user_role()' as function_name,
    public.get_user_role() as result,
    'SUCCESS' as status;

-- Quick Test 2: JWT metadata access
SELECT 
    'JWT Metadata Access' as test_type,
    CASE 
        WHEN auth.jwt() IS NOT NULL THEN 'Available'
        ELSE 'Not Available'
    END as jwt_status,
    COALESCE(auth.jwt() -> 'app_metadata' ->> 'role', 'No app_metadata role') as app_role,
    COALESCE(auth.jwt() -> 'user_metadata' ->> 'role', 'No user_metadata role') as user_role;

-- Quick Test 3: Comprehensive test function
SELECT 'Comprehensive Test Results' as test_type;
SELECT * FROM public.test_jwt_functions();

-- Status message
SELECT 'QUICK TEST COMPLETE' as status, 
       'No syntax errors = JWT fixes are working!' as message;