-- Fix RLS infinite recursion issue in profiles table
-- PROBLEM: The "Admins can view all profiles" policy creates circular reference
-- SOLUTION: Remove circular dependency and implement proper admin access

-- Step 1: Drop the problematic policy that causes infinite recursion
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.profiles;

-- Step 2: Create a security definer function to check admin role
-- This avoids circular reference by accessing auth.users directly
CREATE OR REPLACE FUNCTION public.is_admin_user()
RETURNS BOOLEAN AS $$
BEGIN
    -- Check if current user has admin role in their metadata
    -- This avoids querying profiles table to prevent recursion
    RETURN COALESCE(
        (auth.jwt() ->> 'app_metadata' ->> 'role' = 'admin'),
        (auth.jwt() ->> 'user_metadata' ->> 'role' = 'admin'),
        FALSE
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 3: Create new admin policy using the security definer function
CREATE POLICY "Admins can view all profiles (no recursion)" ON public.profiles
    FOR SELECT USING (public.is_admin_user());

-- Step 4: Add admin policies for other operations
CREATE POLICY "Admins can update all profiles" ON public.profiles
    FOR UPDATE USING (public.is_admin_user());

CREATE POLICY "Admins can insert profiles" ON public.profiles
    FOR INSERT WITH CHECK (public.is_admin_user());

CREATE POLICY "Admins can delete profiles" ON public.profiles
    FOR DELETE USING (public.is_admin_user());

-- Step 5: Create function to safely get user role without recursion
CREATE OR REPLACE FUNCTION public.get_user_role(user_id UUID DEFAULT auth.uid())
RETURNS TEXT AS $$
DECLARE
    user_role TEXT;
BEGIN
    -- First try to get role from JWT metadata (fastest, no DB query)
    user_role := COALESCE(
        auth.jwt() ->> 'app_metadata' ->> 'role',
        auth.jwt() ->> 'user_metadata' ->> 'role'
    );
    
    -- If not found in JWT, query profiles table with explicit permission bypass
    IF user_role IS NULL AND user_id IS NOT NULL THEN
        -- Use security definer to bypass RLS for this specific query
        SELECT role INTO user_role 
        FROM public.profiles 
        WHERE id = user_id;
    END IF;
    
    RETURN COALESCE(user_role, 'student');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 6: Grant execute permissions on the helper functions
GRANT EXECUTE ON FUNCTION public.is_admin_user() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_role(UUID) TO authenticated;

-- Step 7: Update the user creation function to set proper metadata
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, name, email, role)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'name', SPLIT_PART(NEW.email, '@', 1)),
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'role', 'student')
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 8: Add helpful comment explaining the fix
COMMENT ON FUNCTION public.is_admin_user() IS 
'Security definer function to check admin role without causing RLS recursion. Uses JWT metadata instead of querying profiles table.';

COMMENT ON FUNCTION public.get_user_role(UUID) IS 
'Security definer function to safely get user role. Tries JWT metadata first, falls back to DB query with RLS bypass.';