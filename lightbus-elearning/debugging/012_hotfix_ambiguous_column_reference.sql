-- =============================================================================
-- DEBUGGING SESSION 012: HOTFIX FOR AMBIGUOUS COLUMN REFERENCE
-- =============================================================================
-- 
-- Date: 2025-06-07
-- Purpose: Fix ambiguous column reference "i" in get_user_stats function
-- Error: column reference "i" is ambiguous - could refer to PL/pgSQL variable or table column
-- =============================================================================

-- Fix the ambiguous column reference in get_user_stats function
CREATE OR REPLACE FUNCTION public.get_user_stats(
    p_user_id UUID,
    p_client_timezone TEXT DEFAULT 'Europe/Warsaw'
)
RETURNS TABLE(
    total_reviews BIGINT,
    average_quality NUMERIC,
    study_streak INTEGER,
    cards_learned BIGINT,
    cards_due_today BIGINT,
    next_review_date DATE,
    weekly_progress BIGINT[],
    monthly_progress BIGINT[],
    total_lessons BIGINT,
    lessons_with_progress BIGINT
) LANGUAGE plpgsql AS $$
DECLARE
    v_client_today DATE;
    v_weekly_progress BIGINT[];
    v_monthly_progress BIGINT[];
BEGIN
    -- Get current date in client timezone
    v_client_today := get_current_client_date(p_client_timezone);
    
    -- Calculate weekly progress (last 7 days)
    SELECT ARRAY_AGG(daily_count ORDER BY day_index)
    INTO v_weekly_progress
    FROM (
        SELECT
            series_day AS day_index,  -- FIXED: Use explicit alias instead of ambiguous "i"
            COALESCE(COUNT(r.id), 0) as daily_count
        FROM generate_series(0, 6) AS series_day  -- FIXED: Use explicit alias
        LEFT JOIN public.sr_reviews r ON r.student_id = p_user_id
            AND get_client_date(r.completed_at, p_client_timezone) = v_client_today - series_day  -- FIXED: Use series_day
            AND r.completed_at IS NOT NULL
        GROUP BY series_day  -- FIXED: Use series_day
    ) weekly_data;

    -- Calculate monthly progress (last 30 days)
    SELECT ARRAY_AGG(daily_count ORDER BY day_index)
    INTO v_monthly_progress
    FROM (
        SELECT
            series_day AS day_index,  -- FIXED: Use explicit alias instead of ambiguous "i"
            COALESCE(COUNT(r.id), 0) as daily_count
        FROM generate_series(0, 29) AS series_day  -- FIXED: Use explicit alias
        LEFT JOIN public.sr_reviews r ON r.student_id = p_user_id
            AND get_client_date(r.completed_at, p_client_timezone) = v_client_today - series_day  -- FIXED: Use series_day
            AND r.completed_at IS NOT NULL
        GROUP BY series_day  -- FIXED: Use series_day
    ) monthly_data;

    -- Return main query with calculated arrays
    RETURN QUERY
    SELECT 
        COALESCE(COUNT(r.id), 0) as total_reviews,
        COALESCE(AVG(r.quality_rating), 0.0) as average_quality,
        COALESCE(MAX(sp.study_streak), 0) as study_streak,
        COALESCE(COUNT(r.id) FILTER (WHERE r.card_status = 'learned'), 0) as cards_learned,
        COALESCE(COUNT(pending.id), 0) as cards_due_today,
        (
            SELECT MIN(pending_reviews.scheduled_for)::DATE
            FROM public.sr_reviews pending_reviews
            WHERE pending_reviews.student_id = p_user_id
              AND pending_reviews.completed_at IS NULL
              AND get_client_date(pending_reviews.scheduled_for, p_client_timezone) >= v_client_today
        ) as next_review_date,
        v_weekly_progress as weekly_progress,
        v_monthly_progress as monthly_progress,
        COALESCE(COUNT(DISTINCT lp.lesson_id), 0) as total_lessons,
        COALESCE(COUNT(DISTINCT sp.lesson_id), 0) as lessons_with_progress
    FROM public.lesson_participants lp
    LEFT JOIN public.sr_progress sp ON lp.lesson_id = sp.lesson_id AND sp.student_id = p_user_id
    LEFT JOIN public.sr_reviews r ON r.student_id = p_user_id AND r.completed_at IS NOT NULL
    LEFT JOIN public.sr_reviews pending ON pending.student_id = p_user_id 
        AND pending.completed_at IS NULL
        AND get_client_date(pending.scheduled_for, p_client_timezone) <= v_client_today
    WHERE lp.student_id = p_user_id;
END;
$$;

-- Also fix the same issue in get_user_stats_with_timezone if it exists
CREATE OR REPLACE FUNCTION public.get_user_stats_with_timezone(
    p_user_id UUID,
    p_client_timezone TEXT
)
RETURNS TABLE(
    total_reviews BIGINT,
    average_quality NUMERIC,
    study_streak INTEGER,
    cards_learned BIGINT,
    cards_due_today BIGINT,
    next_review_date DATE,
    weekly_progress BIGINT[],
    monthly_progress BIGINT[],
    total_lessons BIGINT,
    lessons_with_progress BIGINT
) LANGUAGE plpgsql AS $$
BEGIN
    -- Simply call the fixed get_user_stats function
    RETURN QUERY
    SELECT * FROM public.get_user_stats(p_user_id, p_client_timezone);
END;
$$;

-- Test the fixed function
SELECT 'Fixed ambiguous column reference in get_user_stats functions' as status;