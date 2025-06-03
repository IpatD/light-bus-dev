-- Enhanced Learning Analytics
-- Show lessons participated in, cards added, cards studied
-- Fix monthly view to show current month from first to last day

-- Step 1: Create enhanced analytics function
CREATE OR REPLACE FUNCTION public.get_enhanced_learning_analytics(
    p_user_id UUID
) RETURNS TABLE(
    lessons_participated INT,
    cards_added INT,
    cards_studied INT,
    weekly_study_data JSON,
    monthly_study_data JSON,
    current_month_name TEXT,
    current_month_days INT
) AS $$
DECLARE
    v_start_of_month DATE;
    v_end_of_month DATE;
    v_days_in_month INT;
    v_weekly_data JSON;
    v_monthly_data JSON;
    v_stats RECORD;
BEGIN
    -- Calculate current month boundaries
    v_start_of_month := DATE_TRUNC('month', CURRENT_DATE)::DATE;
    v_end_of_month := (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month - 1 day')::DATE;
    v_days_in_month := EXTRACT(DAY FROM v_end_of_month);

    -- Get comprehensive learning statistics
    SELECT
        -- Count of lessons student has participated in (enrolled)
        COUNT(DISTINCT lp.lesson_id)::INT as lessons_count,
        
        -- Count of cards added to student's pool (total unique cards from enrolled lessons)
        COUNT(DISTINCT CASE WHEN c.status = 'approved' THEN c.id END)::INT as cards_added_count,
        
        -- Count of cards actually studied (completed at least one review)
        COUNT(DISTINCT CASE WHEN r.completed_at IS NOT NULL THEN r.card_id END)::INT as cards_studied_count
    INTO v_stats
    FROM public.lesson_participants lp
    LEFT JOIN public.sr_cards c ON c.lesson_id = lp.lesson_id
    LEFT JOIN public.sr_reviews r ON r.card_id = c.id AND r.student_id = lp.student_id
    WHERE lp.student_id = p_user_id;

    -- Build weekly study data (last 7 days)
    SELECT json_agg(
        json_build_object(
            'day', day_name,
            'date', study_date,
            'cards_studied', daily_count
        ) ORDER BY study_date
    ) INTO v_weekly_data
    FROM (
        SELECT
            TO_CHAR(CURRENT_DATE - i, 'Dy') as day_name,
            CURRENT_DATE - i as study_date,
            COALESCE(COUNT(DISTINCT r.id), 0)::INT as daily_count
        FROM generate_series(6, 0, -1) AS i
        LEFT JOIN public.sr_reviews r ON r.student_id = p_user_id
            AND r.completed_at::DATE = CURRENT_DATE - i
            AND EXISTS (
                SELECT 1 FROM public.sr_cards c
                JOIN public.lesson_participants lp ON c.lesson_id = lp.lesson_id
                WHERE c.id = r.card_id AND lp.student_id = p_user_id
            )
        GROUP BY i, study_date, day_name
        ORDER BY study_date
    ) weekly_data;

    -- Build monthly study data (current month from day 1 to last day)
    SELECT json_agg(
        json_build_object(
            'day', day_number,
            'date', study_date,
            'cards_studied', daily_count
        ) ORDER BY study_date
    ) INTO v_monthly_data
    FROM (
        SELECT
            EXTRACT(DAY FROM study_date)::INT as day_number,
            study_date,
            COALESCE(COUNT(DISTINCT r.id), 0)::INT as daily_count
        FROM (
            SELECT v_start_of_month + i as study_date
            FROM generate_series(0, v_days_in_month - 1) AS i
        ) month_days
        LEFT JOIN public.sr_reviews r ON r.student_id = p_user_id
            AND r.completed_at::DATE = study_date
            AND EXISTS (
                SELECT 1 FROM public.sr_cards c
                JOIN public.lesson_participants lp ON c.lesson_id = lp.lesson_id
                WHERE c.id = r.card_id AND lp.student_id = p_user_id
            )
        GROUP BY study_date, day_number
        ORDER BY study_date
    ) monthly_data;

    -- Return comprehensive analytics
    RETURN QUERY SELECT
        v_stats.lessons_count,
        v_stats.cards_added_count,
        v_stats.cards_studied_count,
        v_weekly_data,
        v_monthly_data,
        TO_CHAR(CURRENT_DATE, 'Month YYYY') as month_name,
        v_days_in_month;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 2: Update the existing get_user_stats function to use enhanced analytics and fix monthly data
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
    v_start_of_month DATE;
    v_days_in_month INT;
BEGIN
    -- Calculate current month boundaries
    v_start_of_month := DATE_TRUNC('month', CURRENT_DATE)::DATE;
    v_days_in_month := EXTRACT(DAY FROM (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month - 1 day'));

    -- Get basic statistics
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
        FROM generate_series(6, 0, -1) AS i
        LEFT JOIN public.sr_reviews r ON r.student_id = p_user_id
            AND r.completed_at::DATE = CURRENT_DATE - i
            AND EXISTS (
                SELECT 1 FROM public.sr_cards c
                JOIN public.lesson_participants lp ON c.lesson_id = lp.lesson_id
                WHERE c.id = r.card_id AND lp.student_id = p_user_id
            )
        GROUP BY i
        ORDER BY i DESC
    ) weekly_data;

    -- Build monthly progress (current month from day 1 to last day)
    SELECT ARRAY_AGG(daily_count ORDER BY day_number) INTO v_monthly
    FROM (
        SELECT
            day_number,
            COALESCE(COUNT(r.id), 0) as daily_count
        FROM (
            SELECT 
                generate_series(1, v_days_in_month) as day_number,
                v_start_of_month + (generate_series(1, v_days_in_month) - 1) as study_date
        ) month_days
        LEFT JOIN public.sr_reviews r ON r.student_id = p_user_id
            AND r.completed_at::DATE = study_date
            AND EXISTS (
                SELECT 1 FROM public.sr_cards c
                JOIN public.lesson_participants lp ON c.lesson_id = lp.lesson_id
                WHERE c.id = r.card_id AND lp.student_id = p_user_id
            )
        GROUP BY day_number, study_date
        ORDER BY day_number
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

-- Step 3: Grant permissions
GRANT EXECUTE ON FUNCTION public.get_enhanced_learning_analytics(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_stats(UUID) TO authenticated;

-- Step 4: Add helpful comments
COMMENT ON FUNCTION public.get_enhanced_learning_analytics(UUID) IS
'Returns enhanced learning analytics: lessons participated, cards added, cards studied, with proper monthly view';

COMMENT ON FUNCTION public.get_user_stats(UUID) IS
'Updated user statistics function with fixed monthly view showing current month from day 1 to last day';