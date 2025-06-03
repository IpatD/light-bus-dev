-- Fix Cards Studied Tracking
-- Problem: Analytics only counts completed reviews, not cards that have been studied/accepted
-- Solution: Count cards that have been accepted or had any study interaction

-- Step 1: Fix the enhanced analytics function
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
        
        -- Count of cards actually studied (accepted by student OR had any review interaction)
        COUNT(DISTINCT CASE 
            WHEN r.card_status = 'accepted' OR r.completed_at IS NOT NULL 
            THEN r.card_id 
        END)::INT as cards_studied_count
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

-- Step 2: Create a debug function to investigate card status
CREATE OR REPLACE FUNCTION public.debug_student_cards(
    p_user_id UUID
) RETURNS TABLE(
    lesson_name TEXT,
    card_id UUID,
    card_front TEXT,
    card_status TEXT,
    accepted_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    review_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        l.name as lesson_name,
        c.id as card_id,
        LEFT(c.front_content, 50) as card_front,
        r.card_status,
        r.accepted_at,
        r.completed_at,
        COUNT(r.id) OVER (PARTITION BY c.id) as review_count
    FROM public.lesson_participants lp
    JOIN public.sr_cards c ON c.lesson_id = lp.lesson_id
    JOIN public.lessons l ON l.id = lp.lesson_id
    LEFT JOIN public.sr_reviews r ON r.card_id = c.id AND r.student_id = lp.student_id
    WHERE lp.student_id = p_user_id
      AND c.status = 'approved'
    ORDER BY l.name, c.created_at;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 3: Grant permissions
GRANT EXECUTE ON FUNCTION public.get_enhanced_learning_analytics(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.debug_student_cards(UUID) TO authenticated;

-- Step 4: Add helpful comments
COMMENT ON FUNCTION public.get_enhanced_learning_analytics(UUID) IS
'Fixed: Now counts cards that have been accepted OR completed as "cards studied"';

COMMENT ON FUNCTION public.debug_student_cards(UUID) IS
'Debug function to investigate student card status and review tracking';