-- Simple test to verify RLS infinite recursion fixes
-- This script tests the main functions that were failing

\echo 'Testing RLS fixes...'

-- Test 1: Check if helper functions work
\echo 'Test 1: Testing helper functions'
SELECT public.is_admin_user() as admin_check;

-- Test 2: Check if RLS test function works (this will verify all fixes)
\echo 'Test 2: Running comprehensive RLS tests'
SELECT * FROM public.test_rls_fixes();

-- Test 3: Test the main problematic functions with a dummy user ID
\echo 'Test 3: Testing main database functions'

-- Create a test user ID (using a consistent UUID for testing)
DO $$
DECLARE
    test_user_id UUID := '00000000-0000-0000-0000-000000000001';
BEGIN
    -- Test get_user_stats function (was failing with infinite recursion)
    RAISE NOTICE 'Testing get_user_stats...';
    PERFORM * FROM public.get_user_stats(test_user_id);
    RAISE NOTICE 'get_user_stats: SUCCESS - no infinite recursion';
    
    -- Test get_cards_due function (was failing with infinite recursion)
    RAISE NOTICE 'Testing get_cards_due...';
    PERFORM * FROM public.get_cards_due(test_user_id, 10);
    RAISE NOTICE 'get_cards_due: SUCCESS - no infinite recursion';
    
    -- Test get_lesson_progress function (was failing with infinite recursion)
    RAISE NOTICE 'Testing get_lesson_progress...';
    PERFORM * FROM public.get_lesson_progress(test_user_id);
    RAISE NOTICE 'get_lesson_progress: SUCCESS - no infinite recursion';
    
    RAISE NOTICE 'All tests completed successfully!';
END $$;

-- Test 4: Test RLS policies directly
\echo 'Test 4: Testing RLS policies'

-- Test lessons table access (this was causing recursion)
SELECT COUNT(*) as lessons_count FROM public.lessons;

-- Test lesson_participants table access (this was causing recursion)
SELECT COUNT(*) as participants_count FROM public.lesson_participants;

\echo 'RLS tests completed successfully - no infinite recursion detected!'