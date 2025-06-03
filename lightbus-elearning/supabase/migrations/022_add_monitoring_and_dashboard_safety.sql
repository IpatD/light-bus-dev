-- Add monitoring and extra safety measures for duplicate prevention
-- This migration adds monitoring functions and improves dashboard queries

-- Step 1: Create monitoring function to detect potential duplicate issues
CREATE OR REPLACE FUNCTION public.check_duplicate_issues()
RETURNS TABLE(
    issue_type TEXT,
    count BIGINT,
    details TEXT
) AS $$
BEGIN
    -- Check for duplicate uncompleted reviews
    RETURN QUERY
    SELECT 
        'duplicate_uncompleted_reviews'::TEXT,
        COUNT(*)::BIGINT,
        'Card-student pairs with multiple uncompleted reviews'::TEXT
    FROM (
        SELECT card_id, student_id, COUNT(*) as cnt
        FROM public.sr_reviews
        WHERE completed_at IS NULL
        GROUP BY card_id, student_id
        HAVING COUNT(*) > 1
    ) duplicates;
    
    -- Check for duplicate progress records
    RETURN QUERY
    SELECT 
        'duplicate_progress_records'::TEXT,
        COUNT(*)::BIGINT,
        'Student-lesson pairs with multiple progress records'::TEXT
    FROM (
        SELECT student_id, lesson_id, COUNT(*) as cnt
        FROM public.sr_progress
        GROUP BY student_id, lesson_id
        HAVING COUNT(*) > 1
    ) duplicates;
    
    -- Check for cards without corresponding reviews for enrolled students
    RETURN QUERY
    SELECT 
        'missing_reviews'::TEXT,
        COUNT(*)::BIGINT,
        'Approved cards missing review records for enrolled students'::TEXT
    FROM (
        SELECT DISTINCT c.id, lp.student_id
        FROM public.sr_cards c
        CROSS JOIN public.lesson_participants lp
        WHERE c.lesson_id = lp.lesson_id
          AND c.status = 'approved'
          AND NOT EXISTS (
              SELECT 1 FROM public.sr_reviews r
              WHERE r.card_id = c.id 
                AND r.student_id = lp.student_id
                AND r.completed_at IS NULL
          )
    ) missing;
    
    -- Check for orphaned reviews (reviews for non-enrolled students)
    RETURN QUERY
    SELECT 
        'orphaned_reviews'::TEXT,
        COUNT(*)::BIGINT,
        'Reviews for students not enrolled in the lesson'::TEXT
    FROM (
        SELECT DISTINCT r.id
        FROM public.sr_reviews r
        INNER JOIN public.sr_cards c ON r.card_id = c.id
        WHERE NOT EXISTS (
            SELECT 1 FROM public.lesson_participants lp
            WHERE lp.lesson_id = c.lesson_id
              AND lp.student_id = r.student_id
        )
    ) orphaned;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 2: Improve get_cards_due function to be extra safe against duplicates
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
    RETURN QUERY
    SELECT DISTINCT ON (c.id) -- DISTINCT ON to prevent any potential duplicates
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
    ORDER BY c.id, r.scheduled_for ASC, c.difficulty_level ASC -- Order for DISTINCT ON
    LIMIT p_limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 3: Create a safe card cleanup function (for admin use)
CREATE OR REPLACE FUNCTION public.cleanup_duplicate_reviews()
RETURNS TABLE(
    cleaned_reviews INT,
    cleaned_progress INT
) AS $$
DECLARE
    v_cleaned_reviews INT := 0;
    v_cleaned_progress INT := 0;
BEGIN
    -- Clean up duplicate uncompleted reviews (keep earliest)
    WITH duplicate_reviews AS (
        SELECT 
            id,
            ROW_NUMBER() OVER (
                PARTITION BY card_id, student_id 
                ORDER BY created_at ASC, id ASC
            ) as rn
        FROM public.sr_reviews
        WHERE completed_at IS NULL
    )
    DELETE FROM public.sr_reviews 
    WHERE id IN (
        SELECT id FROM duplicate_reviews WHERE rn > 1
    );
    
    GET DIAGNOSTICS v_cleaned_reviews = ROW_COUNT;
    
    -- Clean up duplicate progress records (keep earliest)
    WITH duplicate_progress AS (
        SELECT 
            id,
            ROW_NUMBER() OVER (
                PARTITION BY student_id, lesson_id 
                ORDER BY created_at ASC, id ASC
            ) as rn
        FROM public.sr_progress
    )
    DELETE FROM public.sr_progress 
    WHERE id IN (
        SELECT id FROM duplicate_progress WHERE rn > 1
    );
    
    GET DIAGNOSTICS v_cleaned_progress = ROW_COUNT;
    
    RETURN QUERY SELECT v_cleaned_reviews, v_cleaned_progress;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 4: Create function to fix missing reviews for enrolled students
CREATE OR REPLACE FUNCTION public.fix_missing_reviews()
RETURNS INT AS $$
DECLARE
    v_missing_record RECORD;
    v_fixed_count INT := 0;
BEGIN
    -- Find and fix missing reviews for enrolled students
    FOR v_missing_record IN
        SELECT DISTINCT c.id as card_id, lp.student_id
        FROM public.sr_cards c
        CROSS JOIN public.lesson_participants lp
        WHERE c.lesson_id = lp.lesson_id
          AND c.status = 'approved'
          AND NOT EXISTS (
              SELECT 1 FROM public.sr_reviews r
              WHERE r.card_id = c.id 
                AND r.student_id = lp.student_id
                AND r.completed_at IS NULL
          )
    LOOP
        -- Create missing review record
        BEGIN
            INSERT INTO public.sr_reviews (
                card_id, student_id, scheduled_for, 
                interval_days, ease_factor, repetition_count
            ) VALUES (
                v_missing_record.card_id, 
                v_missing_record.student_id, 
                NOW(),
                1, 2.5, 0
            );
            v_fixed_count := v_fixed_count + 1;
        EXCEPTION 
            WHEN unique_violation THEN
                -- Skip if somehow already exists
                CONTINUE;
        END;
    END LOOP;
    
    RETURN v_fixed_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 5: Improve get_user_stats to be extra safe
CREATE OR REPLACE FUNCTION public.get_user_stats(
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

    -- Get basic statistics with duplicate protection
    SELECT
        COALESCE(COUNT(DISTINCT r.id) FILTER (WHERE r.completed_at IS NOT NULL), 0) as tot_reviews,
        COALESCE(AVG(r.quality_rating) FILTER (WHERE r.completed_at IS NOT NULL), 0.0) as avg_quality,
        COALESCE(MAX(p.study_streak), 0) as max_streak,
        COALESCE(SUM(DISTINCT p.cards_learned), 0) as learned_cards,
        COALESCE(COUNT(DISTINCT CASE WHEN r.completed_at IS NULL AND r.scheduled_for <= NOW() THEN r.id END), 0) as due_today,
        MIN(CASE WHEN r.completed_at IS NULL THEN r.scheduled_for::DATE END) as next_review,
        COUNT(DISTINCT p.lesson_id) as lessons_progress,
        COUNT(DISTINCT lp.lesson_id) as total_lessons_count
    INTO v_stats
    FROM public.lesson_participants lp
    LEFT JOIN public.sr_progress p ON lp.lesson_id = p.lesson_id AND lp.student_id = p.student_id
    LEFT JOIN public.sr_reviews r ON r.student_id = lp.student_id
    LEFT JOIN public.sr_cards c ON r.card_id = c.id AND c.lesson_id = lp.lesson_id
    WHERE lp.student_id = p_user_id;

    -- Build weekly progress (last 7 days) with duplicate protection
    SELECT ARRAY_AGG(daily_count ORDER BY day_index) INTO v_weekly
    FROM (
        SELECT
            i AS day_index,
            COALESCE(COUNT(DISTINCT r.id), 0) as daily_count
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

    -- Build monthly progress (last 30 days) with duplicate protection
    SELECT ARRAY_AGG(daily_count ORDER BY day_index) INTO v_monthly
    FROM (
        SELECT
            i AS day_index,
            COALESCE(COUNT(DISTINCT r.id), 0) as daily_count
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

-- Step 6: Grant permissions
GRANT EXECUTE ON FUNCTION public.check_duplicate_issues() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_cards_due(UUID, INT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cleanup_duplicate_reviews() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fix_missing_reviews() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_stats(UUID) TO authenticated;

-- Step 7: Run initial health check
SELECT * FROM public.check_duplicate_issues();

-- Step 8: Add helpful comments
COMMENT ON FUNCTION public.check_duplicate_issues() IS
'Monitoring function to detect potential duplicate issues in card system';

COMMENT ON FUNCTION public.cleanup_duplicate_reviews() IS
'Admin function to clean up any duplicate reviews that might occur';

COMMENT ON FUNCTION public.fix_missing_reviews() IS
'Function to create missing review records for enrolled students';