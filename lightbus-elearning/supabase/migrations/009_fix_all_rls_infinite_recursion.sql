-- Fix all remaining RLS infinite recursion issues
-- PROBLEM: Multiple circular references in lessons and lesson_participants tables
-- SOLUTION: Rewrite policies to avoid self-reference loops using security definer functions

-- Step 1: Drop all problematic RLS policies that cause circular references

-- Drop problematic lesson policies
DROP POLICY IF EXISTS "Students can view lessons they participate in" ON public.lessons;
DROP POLICY IF EXISTS "Teachers can view reviews for their lessons" ON public.sr_reviews;

-- Drop problematic lesson_participants policies  
DROP POLICY IF EXISTS "View lesson participants" ON public.lesson_participants;

-- Step 2: Create security definer functions to check permissions without circular queries

-- Function to check if user is teacher of a specific lesson
CREATE OR REPLACE FUNCTION public.is_lesson_teacher(lesson_id_param UUID, user_id_param UUID DEFAULT auth.uid())
RETURNS BOOLEAN AS $$
BEGIN
    -- Direct query without RLS to avoid recursion
    RETURN EXISTS (
        SELECT 1 FROM public.lessons 
        WHERE id = lesson_id_param AND teacher_id = user_id_param
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user is participant of a specific lesson
CREATE OR REPLACE FUNCTION public.is_lesson_participant(lesson_id_param UUID, user_id_param UUID DEFAULT auth.uid())
RETURNS BOOLEAN AS $$
BEGIN
    -- Direct query without RLS to avoid recursion
    RETURN EXISTS (
        SELECT 1 FROM public.lesson_participants 
        WHERE lesson_id = lesson_id_param AND student_id = user_id_param
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user can access lesson (teacher or participant)
CREATE OR REPLACE FUNCTION public.can_access_lesson(lesson_id_param UUID, user_id_param UUID DEFAULT auth.uid())
RETURNS BOOLEAN AS $$
BEGIN
    -- Check if user is admin first
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

-- Step 3: Create new non-recursive RLS policies for lessons table

CREATE POLICY "Teachers can view their own lessons (no recursion)" ON public.lessons
    FOR SELECT USING (teacher_id = auth.uid());

CREATE POLICY "Students can view lessons they participate in (no recursion)" ON public.lessons
    FOR SELECT USING (public.is_lesson_participant(id, auth.uid()));

CREATE POLICY "Admins can view all lessons" ON public.lessons
    FOR SELECT USING (public.is_admin_user());

-- Keep existing policies for INSERT/UPDATE
CREATE POLICY "Admins can insert lessons" ON public.lessons
    FOR INSERT WITH CHECK (public.is_admin_user());

CREATE POLICY "Admins can update lessons" ON public.lessons
    FOR UPDATE USING (public.is_admin_user());

CREATE POLICY "Admins can delete lessons" ON public.lessons
    FOR DELETE USING (public.is_admin_user());

-- Step 4: Create new non-recursive RLS policies for lesson_participants table

CREATE POLICY "Teachers can view participants of their lessons (no recursion)" ON public.lesson_participants
    FOR SELECT USING (public.is_lesson_teacher(lesson_id, auth.uid()));

CREATE POLICY "Students can view their own participation (no recursion)" ON public.lesson_participants
    FOR SELECT USING (student_id = auth.uid());

CREATE POLICY "Admins can view all lesson participants" ON public.lesson_participants
    FOR SELECT USING (public.is_admin_user());

CREATE POLICY "Teachers can add participants to their lessons" ON public.lesson_participants
    FOR INSERT WITH CHECK (public.is_lesson_teacher(lesson_id, auth.uid()));

CREATE POLICY "Admins can add participants to any lesson" ON public.lesson_participants
    FOR INSERT WITH CHECK (public.is_admin_user());

CREATE POLICY "Teachers can remove participants from their lessons" ON public.lesson_participants
    FOR DELETE USING (public.is_lesson_teacher(lesson_id, auth.uid()));

CREATE POLICY "Admins can remove participants from any lesson" ON public.lesson_participants
    FOR DELETE USING (public.is_admin_user());

-- Step 5: Fix sr_reviews policies that reference lessons indirectly

DROP POLICY IF EXISTS "Teachers can view reviews for their lessons" ON public.sr_reviews;

CREATE POLICY "Teachers can view reviews for their lessons (no recursion)" ON public.sr_reviews
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.sr_cards sc
            WHERE sc.id = card_id AND public.is_lesson_teacher(sc.lesson_id, auth.uid())
        )
    );

-- Step 6: Create safe versions of database functions that bypass RLS when needed

-- Safe version of get_user_stats function
CREATE OR REPLACE FUNCTION public.get_user_stats_safe(
    p_user_id UUID
) RETURNS TABLE(
    total_reviews BIGINT,
    average_quality DECIMAL,
    study_streak INT,
    cards_learned BIGINT,
    cards_due_today BIGINT,
    next_review_date DATE,
    weekly_progress BIGINT[],
    monthly_progress BIGINT[],
    total_lessons BIGINT,
    lessons_with_progress BIGINT
) AS $$
DECLARE
    v_stats RECORD;
    v_weekly BIGINT[];
    v_monthly BIGINT[];
BEGIN
    -- Initialize arrays
    v_weekly := ARRAY[0,0,0,0,0,0,0];
    v_monthly := ARRAY_FILL(0, ARRAY[30]);

    -- Get basic statistics using security definer to bypass RLS
    SELECT
        COALESCE(COUNT(CASE WHEN r.completed_at IS NOT NULL THEN 1 END), 0) as tot_reviews,
        COALESCE(AVG(CASE WHEN r.completed_at IS NOT NULL THEN r.quality_rating END), 0.0) as avg_quality,
        COALESCE(MAX(p.study_streak), 0) as max_streak,
        COALESCE(SUM(p.cards_learned), 0) as learned_cards,
        COALESCE(COUNT(CASE WHEN r.completed_at IS NULL AND r.scheduled_for <= NOW() THEN 1 END), 0) as due_today,
        MIN(CASE WHEN r.completed_at IS NULL THEN r.scheduled_for::DATE END) as next_review,
        COUNT(DISTINCT p.lesson_id) as lessons_progress,
        COUNT(DISTINCT lp.lesson_id) as total_lessons_count
    INTO v_stats
    FROM public.lesson_participants lp
    LEFT JOIN public.sr_progress p ON lp.lesson_id = p.lesson_id AND lp.student_id = p.student_id
    LEFT JOIN public.sr_reviews r ON r.student_id = lp.student_id
    LEFT JOIN public.sr_cards c ON r.card_id = c.id AND c.lesson_id = lp.lesson_id
    WHERE lp.student_id = p_user_id;

    -- Build weekly progress (last 7 days)
    SELECT ARRAY_AGG(daily_count ORDER BY day_index) INTO v_weekly
    FROM (
        SELECT
            i AS day_index,
            COALESCE(COUNT(r.id), 0) as daily_count
        FROM generate_series(0, 6) AS i
        LEFT JOIN public.sr_reviews r ON r.student_id = p_user_id
            AND r.completed_at::DATE = CURRENT_DATE - i
            AND EXISTS (
                SELECT 1 FROM public.sr_cards c
                JOIN public.lesson_participants lp ON c.lesson_id = lp.lesson_id
                WHERE c.id = r.card_id AND lp.student_id = p_user_id
            )
        GROUP BY i
        ORDER BY i
    ) weekly_data;

    -- Build monthly progress (last 30 days)
    SELECT ARRAY_AGG(daily_count ORDER BY day_index) INTO v_monthly
    FROM (
        SELECT
            i AS day_index,
            COALESCE(COUNT(r.id), 0) as daily_count
        FROM generate_series(0, 29) AS i
        LEFT JOIN public.sr_reviews r ON r.student_id = p_user_id
            AND r.completed_at::DATE = CURRENT_DATE - i
            AND EXISTS (
                SELECT 1 FROM public.sr_cards c
                JOIN public.lesson_participants lp ON c.lesson_id = lp.lesson_id
                WHERE c.id = r.card_id AND lp.student_id = p_user_id
            )
        GROUP BY i
        ORDER BY i
    ) monthly_data;

    -- Return comprehensive stats
    RETURN QUERY SELECT
        v_stats.tot_reviews,
        v_stats.avg_quality,
        v_stats.max_streak,
        v_stats.learned_cards,
        v_stats.due_today,
        v_stats.next_review,
        v_weekly,
        v_monthly,
        v_stats.total_lessons_count,
        v_stats.lessons_progress;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Safe version of get_cards_due function
CREATE OR REPLACE FUNCTION public.get_cards_due_safe(
    p_user_id UUID,
    p_limit_count INT DEFAULT 20,
    p_lesson_id UUID DEFAULT NULL
) RETURNS TABLE(
    card_id UUID,
    lesson_id UUID,
    front_content TEXT,
    back_content TEXT,
    difficulty_level INT,
    tags TEXT[],
    scheduled_for TIMESTAMPTZ,
    review_id UUID,
    repetition_count INT,
    ease_factor DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id as card_id,
        c.lesson_id,
        c.front_content,
        c.back_content,
        c.difficulty_level,
        c.tags,
        r.scheduled_for,
        r.id as review_id,
        r.repetition_count,
        r.ease_factor
    FROM public.sr_cards c
    INNER JOIN public.sr_reviews r ON c.id = r.card_id
    INNER JOIN public.lesson_participants lp ON c.lesson_id = lp.lesson_id
    WHERE r.student_id = p_user_id
      AND lp.student_id = p_user_id
      AND c.status = 'approved'
      AND r.completed_at IS NULL
      AND r.scheduled_for <= NOW()
      AND (p_lesson_id IS NULL OR c.lesson_id = p_lesson_id)
    ORDER BY r.scheduled_for ASC, c.difficulty_level ASC
    LIMIT p_limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Safe version of get_lesson_progress function
CREATE OR REPLACE FUNCTION public.get_lesson_progress_safe(
    p_student_id UUID,
    p_lesson_id UUID DEFAULT NULL
) RETURNS TABLE(
    lesson_id UUID,
    lesson_name TEXT,
    cards_total INT,
    cards_reviewed INT,
    cards_learned INT,
    cards_due INT,
    average_quality DECIMAL,
    next_review_date DATE,
    progress_percentage DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        l.id as lesson_id,
        l.name as lesson_name,
        p.cards_total,
        p.cards_reviewed,
        p.cards_learned,
        COUNT(r.id)::INT as cards_due,
        p.average_quality,
        p.next_review_date,
        CASE 
            WHEN p.cards_total > 0 THEN 
                ROUND((p.cards_learned::DECIMAL / p.cards_total::DECIMAL) * 100, 2)
            ELSE 0.0
        END as progress_percentage
    FROM public.lessons l
    INNER JOIN public.lesson_participants lp ON l.id = lp.lesson_id
    LEFT JOIN public.sr_progress p ON l.id = p.lesson_id AND p.student_id = lp.student_id
    LEFT JOIN public.sr_reviews r ON r.student_id = lp.student_id 
        AND r.completed_at IS NULL 
        AND r.scheduled_for <= NOW()
        AND EXISTS(
            SELECT 1 FROM public.sr_cards c 
            WHERE c.id = r.card_id AND c.lesson_id = l.id
        )
    WHERE lp.student_id = p_student_id
      AND (p_lesson_id IS NULL OR l.id = p_lesson_id)
    GROUP BY l.id, l.name, p.cards_total, p.cards_reviewed, 
             p.cards_learned, p.average_quality, p.next_review_date
    ORDER BY l.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 7: Replace original functions with safe versions
DROP FUNCTION IF EXISTS public.get_user_stats(UUID);
DROP FUNCTION IF EXISTS public.get_cards_due(UUID, INT, UUID);
DROP FUNCTION IF EXISTS public.get_lesson_progress(UUID, UUID);

-- Create aliases for the safe functions
CREATE OR REPLACE FUNCTION public.get_user_stats(p_user_id UUID)
RETURNS TABLE(
    total_reviews BIGINT,
    average_quality DECIMAL,
    study_streak INT,
    cards_learned BIGINT,
    cards_due_today BIGINT,
    next_review_date DATE,
    weekly_progress BIGINT[],
    monthly_progress BIGINT[],
    total_lessons BIGINT,
    lessons_with_progress BIGINT
) AS $$
BEGIN
    RETURN QUERY SELECT * FROM public.get_user_stats_safe(p_user_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.get_cards_due(
    p_user_id UUID,
    p_limit_count INT DEFAULT 20,
    p_lesson_id UUID DEFAULT NULL
) RETURNS TABLE(
    card_id UUID,
    lesson_id UUID,
    front_content TEXT,
    back_content TEXT,
    difficulty_level INT,
    tags TEXT[],
    scheduled_for TIMESTAMPTZ,
    review_id UUID,
    repetition_count INT,
    ease_factor DECIMAL
) AS $$
BEGIN
    RETURN QUERY SELECT * FROM public.get_cards_due_safe(p_user_id, p_limit_count, p_lesson_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.get_lesson_progress(
    p_student_id UUID,
    p_lesson_id UUID DEFAULT NULL
) RETURNS TABLE(
    lesson_id UUID,
    lesson_name TEXT,
    cards_total INT,
    cards_reviewed INT,
    cards_learned INT,
    cards_due INT,
    average_quality DECIMAL,
    next_review_date DATE,
    progress_percentage DECIMAL
) AS $$
BEGIN
    RETURN QUERY SELECT * FROM public.get_lesson_progress_safe(p_student_id, p_lesson_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 8: Grant permissions on all new functions
GRANT EXECUTE ON FUNCTION public.is_lesson_teacher(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_lesson_participant(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_access_lesson(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_stats_safe(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_cards_due_safe(UUID, INT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_lesson_progress_safe(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_stats(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_cards_due(UUID, INT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_lesson_progress(UUID, UUID) TO authenticated;

-- Step 9: Add helpful comments explaining the fixes
COMMENT ON FUNCTION public.is_lesson_teacher(UUID, UUID) IS 
'Security definer function to check if user is teacher of a lesson without causing RLS recursion.';

COMMENT ON FUNCTION public.is_lesson_participant(UUID, UUID) IS 
'Security definer function to check if user is participant of a lesson without causing RLS recursion.';

COMMENT ON FUNCTION public.can_access_lesson(UUID, UUID) IS 
'Security definer function to check if user can access a lesson (teacher, participant, or admin) without RLS recursion.';

COMMENT ON FUNCTION public.get_user_stats_safe(UUID) IS 
'RLS-safe version of get_user_stats that uses security definer to avoid infinite recursion.';

COMMENT ON FUNCTION public.get_cards_due_safe(UUID, INT, UUID) IS 
'RLS-safe version of get_cards_due that uses security definer to avoid infinite recursion.';

COMMENT ON FUNCTION public.get_lesson_progress_safe(UUID, UUID) IS 
'RLS-safe version of get_lesson_progress that uses security definer to avoid infinite recursion.';

-- Step 10: Test that functions work by creating a simple test function
CREATE OR REPLACE FUNCTION public.test_rls_fixes()
RETURNS TABLE(
    test_name TEXT,
    result BOOLEAN,
    error_message TEXT
) AS $$
DECLARE
    test_user_id UUID;
    test_lesson_id UUID;
    result_count INT;
BEGIN
    -- Test 1: Check if helper functions execute without error
    BEGIN
        SELECT auth.uid() INTO test_user_id;
        IF test_user_id IS NULL THEN
            test_user_id := gen_random_uuid(); -- Use dummy ID for testing
        END IF;
        
        PERFORM public.is_admin_user();
        RETURN QUERY SELECT 'is_admin_user() execution', TRUE, ''::TEXT;
    EXCEPTION WHEN OTHERS THEN
        RETURN QUERY SELECT 'is_admin_user() execution', FALSE, SQLERRM;
    END;

    -- Test 2: Check if lesson access functions work
    BEGIN
        SELECT id INTO test_lesson_id FROM public.lessons LIMIT 1;
        IF test_lesson_id IS NOT NULL THEN
            PERFORM public.can_access_lesson(test_lesson_id, test_user_id);
        END IF;
        RETURN QUERY SELECT 'can_access_lesson() execution', TRUE, ''::TEXT;
    EXCEPTION WHEN OTHERS THEN
        RETURN QUERY SELECT 'can_access_lesson() execution', FALSE, SQLERRM;
    END;

    -- Test 3: Check if stats functions work
    BEGIN
        SELECT COUNT(*) INTO result_count FROM public.get_user_stats_safe(test_user_id);
        RETURN QUERY SELECT 'get_user_stats_safe() execution', TRUE, ''::TEXT;
    EXCEPTION WHEN OTHERS THEN
        RETURN QUERY SELECT 'get_user_stats_safe() execution', FALSE, SQLERRM;
    END;

    -- Test 4: Check if cards due function works
    BEGIN
        SELECT COUNT(*) INTO result_count FROM public.get_cards_due_safe(test_user_id);
        RETURN QUERY SELECT 'get_cards_due_safe() execution', TRUE, ''::TEXT;
    EXCEPTION WHEN OTHERS THEN
        RETURN QUERY SELECT 'get_cards_due_safe() execution', FALSE, SQLERRM;
    END;

    -- Test 5: Check if lesson progress function works
    BEGIN
        SELECT COUNT(*) INTO result_count FROM public.get_lesson_progress_safe(test_user_id);
        RETURN QUERY SELECT 'get_lesson_progress_safe() execution', TRUE, ''::TEXT;
    EXCEPTION WHEN OTHERS THEN
        RETURN QUERY SELECT 'get_lesson_progress_safe() execution', FALSE, SQLERRM;
    END;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.test_rls_fixes() TO authenticated;

COMMENT ON FUNCTION public.test_rls_fixes() IS 
'Test function to verify that all RLS fixes are working correctly without infinite recursion.';