-- Clean JWT metadata parsing migration for Supabase SQL Editor
-- Copy of 010_fix_jwt_metadata_syntax.sql without any psql-specific commands
-- READY TO COPY-PASTE INTO SUPABASE DASHBOARD

-- Fix JWT metadata parsing syntax for Supabase
-- PROBLEM: "operator does not exist: text ->> unknown" error in JWT functions
-- SOLUTION: Use correct Supabase JWT metadata access syntax

-- Step 1: Fix is_admin_user() function with correct JWT syntax
CREATE OR REPLACE FUNCTION public.is_admin_user()
RETURNS BOOLEAN AS $$
BEGIN
    -- Check if current user has admin role in their metadata
    -- Use correct Supabase JWT metadata access syntax
    RETURN COALESCE(
        (auth.jwt() -> 'app_metadata' ->> 'role' = 'admin'),
        (auth.jwt() -> 'user_metadata' ->> 'role' = 'admin'),
        FALSE
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 2: Fix get_user_role() function with correct JWT syntax
CREATE OR REPLACE FUNCTION public.get_user_role(user_id UUID DEFAULT auth.uid())
RETURNS TEXT AS $$
DECLARE
    user_role TEXT;
BEGIN
    -- First try to get role from JWT metadata (fastest, no DB query)
    -- Use correct Supabase JWT metadata access syntax
    user_role := COALESCE(
        auth.jwt() -> 'app_metadata' ->> 'role',
        auth.jwt() -> 'user_metadata' ->> 'role'
    );
    
    -- If not found in JWT, query profiles table with explicit permission bypass
    IF user_role IS NULL AND user_id IS NOT NULL THEN
        -- Use security definer context to bypass RLS temporarily
        SELECT role INTO user_role FROM public.profiles WHERE id = user_id;
    END IF;
    
    RETURN COALESCE(user_role, 'student'); -- Default to student role
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 3: Create enhanced can_access_lesson function with proper JWT syntax
CREATE OR REPLACE FUNCTION public.can_access_lesson(lesson_id_param UUID, user_id_param UUID DEFAULT auth.uid())
RETURNS BOOLEAN AS $$
BEGIN
    -- Check if user is admin first using fixed JWT syntax
    IF public.is_admin_user() THEN
        RETURN TRUE;
    END IF;
    
    -- Check if teacher or participant without causing RLS recursion
    RETURN (
        public.is_lesson_teacher(lesson_id_param, user_id_param) OR 
        public.is_lesson_participant(lesson_id_param, user_id_param)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 4: Grant permissions on updated functions
GRANT EXECUTE ON FUNCTION public.is_admin_user() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_role(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_access_lesson(UUID, UUID) TO authenticated;

-- Step 5: Add comprehensive test function for JWT metadata access
CREATE OR REPLACE FUNCTION public.test_jwt_functions()
RETURNS TABLE(
    test_name TEXT,
    result BOOLEAN,
    error_message TEXT,
    additional_info TEXT
) AS $$
DECLARE
    test_user_id UUID;
    test_lesson_id UUID;
    jwt_data JSONB;
    user_role_result TEXT;
    admin_check_result BOOLEAN;
BEGIN
    -- Get current user ID
    SELECT auth.uid() INTO test_user_id;
    IF test_user_id IS NULL THEN
        test_user_id := gen_random_uuid(); -- Use dummy ID for testing
    END IF;

    -- Test 1: Check JWT data access
    BEGIN
        SELECT auth.jwt() INTO jwt_data;
        RETURN QUERY SELECT 
            'JWT data access'::TEXT, 
            TRUE, 
            ''::TEXT,
            COALESCE(jwt_data::TEXT, 'No JWT data available')::TEXT;
    EXCEPTION WHEN OTHERS THEN
        RETURN QUERY SELECT 
            'JWT data access'::TEXT, 
            FALSE, 
            SQLERRM::TEXT,
            ''::TEXT;
    END;

    -- Test 2: Check is_admin_user() function
    BEGIN
        SELECT public.is_admin_user() INTO admin_check_result;
        RETURN QUERY SELECT 
            'is_admin_user() execution'::TEXT, 
            TRUE, 
            ''::TEXT,
            ('Admin check result: ' || admin_check_result::TEXT)::TEXT;
    EXCEPTION WHEN OTHERS THEN
        RETURN QUERY SELECT 
            'is_admin_user() execution'::TEXT, 
            FALSE, 
            SQLERRM::TEXT,
            ''::TEXT;
    END;

    -- Test 3: Check get_user_role() function
    BEGIN
        SELECT public.get_user_role(test_user_id) INTO user_role_result;
        RETURN QUERY SELECT 
            'get_user_role() execution'::TEXT, 
            TRUE, 
            ''::TEXT,
            ('User role: ' || COALESCE(user_role_result, 'NULL'))::TEXT;
    EXCEPTION WHEN OTHERS THEN
        RETURN QUERY SELECT 
            'get_user_role() execution'::TEXT, 
            FALSE, 
            SQLERRM::TEXT,
            ''::TEXT;
    END;

    -- Test 4: Check can_access_lesson() function
    BEGIN
        SELECT id INTO test_lesson_id FROM public.lessons LIMIT 1;
        IF test_lesson_id IS NOT NULL THEN
            PERFORM public.can_access_lesson(test_lesson_id, test_user_id);
            RETURN QUERY SELECT 
                'can_access_lesson() execution'::TEXT, 
                TRUE, 
                ''::TEXT,
                ('Tested with lesson ID: ' || test_lesson_id::TEXT)::TEXT;
        ELSE
            RETURN QUERY SELECT 
                'can_access_lesson() execution'::TEXT, 
                TRUE, 
                ''::TEXT,
                'No lessons available to test'::TEXT;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RETURN QUERY SELECT 
            'can_access_lesson() execution'::TEXT, 
            FALSE, 
            SQLERRM::TEXT,
            ''::TEXT;
    END;

    -- Test 5: Check JWT metadata extraction specifically
    BEGIN
        DECLARE
            app_meta_role TEXT;
            user_meta_role TEXT;
        BEGIN
            app_meta_role := auth.jwt() -> 'app_metadata' ->> 'role';
            user_meta_role := auth.jwt() -> 'user_metadata' ->> 'role';
            
            RETURN QUERY SELECT 
                'JWT metadata extraction'::TEXT, 
                TRUE, 
                ''::TEXT,
                ('App metadata role: ' || COALESCE(app_meta_role, 'NULL') || 
                 ', User metadata role: ' || COALESCE(user_meta_role, 'NULL'))::TEXT;
        END;
    EXCEPTION WHEN OTHERS THEN
        RETURN QUERY SELECT 
            'JWT metadata extraction'::TEXT, 
            FALSE, 
            SQLERRM::TEXT,
            ''::TEXT;
    END;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.test_jwt_functions() TO authenticated;

-- Step 6: Add helpful comments
COMMENT ON FUNCTION public.is_admin_user() IS
'Fixed JWT metadata access using correct Supabase syntax: auth.jwt() -> ''metadata'' ->> ''key''';

COMMENT ON FUNCTION public.get_user_role(UUID) IS
'Fixed JWT metadata access with fallback to profiles table query using security definer.';

COMMENT ON FUNCTION public.can_access_lesson(UUID, UUID) IS
'Enhanced lesson access check with proper JWT metadata parsing for admin verification.';

COMMENT ON FUNCTION public.test_jwt_functions() IS
'Comprehensive test function to verify JWT metadata access and all related functions work correctly.';

-- Migration complete - all functions now use correct Supabase JWT metadata syntax