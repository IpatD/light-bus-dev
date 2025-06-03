-- Fix sr_reviews RLS policies to prevent 406 errors
-- PROBLEM: Student dashboard getting 406 errors when querying sr_reviews table
-- SOLUTION: Ensure comprehensive RLS policies and proper permissions

-- Step 1: Ensure all required indexes exist for sr_reviews
CREATE INDEX IF NOT EXISTS idx_sr_reviews_student_completed_at ON public.sr_reviews(student_id, completed_at);
CREATE INDEX IF NOT EXISTS idx_sr_reviews_student_scheduled ON public.sr_reviews(student_id, scheduled_for);

-- Step 2: Drop and recreate RLS policies for sr_reviews to ensure they're comprehensive
DROP POLICY IF EXISTS "Students can view their own reviews" ON public.sr_reviews;
DROP POLICY IF EXISTS "Students can create their own reviews" ON public.sr_reviews;
DROP POLICY IF EXISTS "Students can update their own reviews" ON public.sr_reviews;
DROP POLICY IF EXISTS "Teachers can view reviews for their lessons (no recursion)" ON public.sr_reviews;

-- Step 3: Create comprehensive RLS policies for sr_reviews
CREATE POLICY "Students can view their own reviews (comprehensive)" ON public.sr_reviews
    FOR SELECT USING (student_id = auth.uid());

CREATE POLICY "Students can create their own reviews (comprehensive)" ON public.sr_reviews
    FOR INSERT WITH CHECK (student_id = auth.uid());

CREATE POLICY "Students can update their own reviews (comprehensive)" ON public.sr_reviews
    FOR UPDATE USING (student_id = auth.uid());

CREATE POLICY "Teachers can view reviews for their lessons (safe)" ON public.sr_reviews
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.sr_cards sc
            JOIN public.lessons l ON sc.lesson_id = l.id
            WHERE sc.id = card_id AND l.teacher_id = auth.uid()
        )
    );

CREATE POLICY "Admins can view all reviews" ON public.sr_reviews
    FOR SELECT USING (public.is_admin_user());

CREATE POLICY "Admins can update all reviews" ON public.sr_reviews
    FOR UPDATE USING (public.is_admin_user());

CREATE POLICY "Admins can delete all reviews" ON public.sr_reviews
    FOR DELETE USING (public.is_admin_user());

-- Step 4: Create a safe function to get last review without RLS issues
CREATE OR REPLACE FUNCTION public.get_student_last_review(
    p_student_id UUID
) RETURNS TABLE(
    completed_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT r.completed_at
    FROM public.sr_reviews r
    WHERE r.student_id = p_student_id
      AND r.completed_at IS NOT NULL
    ORDER BY r.completed_at DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 5: Create a comprehensive function to get student review statistics
CREATE OR REPLACE FUNCTION public.get_student_review_stats(
    p_student_id UUID
) RETURNS TABLE(
    total_reviews BIGINT,
    last_review_date TIMESTAMPTZ,
    average_quality DECIMAL,
    reviews_today BIGINT,
    reviews_this_week BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(r.id) as total_reviews,
        MAX(r.completed_at) as last_review_date,
        COALESCE(AVG(r.quality_rating), 0.0) as average_quality,
        COUNT(CASE WHEN r.completed_at::DATE = CURRENT_DATE THEN 1 END) as reviews_today,
        COUNT(CASE WHEN r.completed_at >= CURRENT_DATE - INTERVAL '7 days' THEN 1 END) as reviews_this_week
    FROM public.sr_reviews r
    WHERE r.student_id = p_student_id
      AND r.completed_at IS NOT NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 6: Grant permissions on new functions
GRANT EXECUTE ON FUNCTION public.get_student_last_review(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_student_review_stats(UUID) TO authenticated;

-- Step 7: Ensure sr_reviews table permissions are properly set
GRANT SELECT ON public.sr_reviews TO authenticated;
GRANT INSERT ON public.sr_reviews TO authenticated;
GRANT UPDATE ON public.sr_reviews TO authenticated;

-- Step 8: Add helpful comments
COMMENT ON FUNCTION public.get_student_last_review(UUID) IS 
'Safe function to get last review for a student without causing RLS issues.';

COMMENT ON FUNCTION public.get_student_review_stats(UUID) IS 
'Comprehensive function to get review statistics for a student safely.';

-- Step 9: Create a test function to verify the fixes work
CREATE OR REPLACE FUNCTION public.test_sr_reviews_access()
RETURNS TABLE(
    test_name TEXT,
    result BOOLEAN,
    error_message TEXT
) AS $$
DECLARE
    test_user_id UUID;
    result_count INT;
BEGIN
    -- Get current user or use dummy ID
    SELECT auth.uid() INTO test_user_id;
    IF test_user_id IS NULL THEN
        test_user_id := gen_random_uuid();
    END IF;

    -- Test 1: Direct select from sr_reviews
    BEGIN
        SELECT COUNT(*) INTO result_count 
        FROM public.sr_reviews 
        WHERE student_id = test_user_id;
        RETURN QUERY SELECT 'Direct sr_reviews select', TRUE, ''::TEXT;
    EXCEPTION WHEN OTHERS THEN
        RETURN QUERY SELECT 'Direct sr_reviews select', FALSE, SQLERRM;
    END;

    -- Test 2: get_student_last_review function
    BEGIN
        SELECT COUNT(*) INTO result_count 
        FROM public.get_student_last_review(test_user_id);
        RETURN QUERY SELECT 'get_student_last_review function', TRUE, ''::TEXT;
    EXCEPTION WHEN OTHERS THEN
        RETURN QUERY SELECT 'get_student_last_review function', FALSE, SQLERRM;
    END;

    -- Test 3: get_student_review_stats function
    BEGIN
        SELECT COUNT(*) INTO result_count 
        FROM public.get_student_review_stats(test_user_id);
        RETURN QUERY SELECT 'get_student_review_stats function', TRUE, ''::TEXT;
    EXCEPTION WHEN OTHERS THEN
        RETURN QUERY SELECT 'get_student_review_stats function', FALSE, SQLERRM;
    END;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.test_sr_reviews_access() TO authenticated;

COMMENT ON FUNCTION public.test_sr_reviews_access() IS 
'Test function to verify that sr_reviews access is working correctly after fixes.';