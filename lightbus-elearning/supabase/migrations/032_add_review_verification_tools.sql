-- Add Review Verification Tools
-- Tools to verify what data is actually being recorded during study sessions

-- Function to check recent review activity for a user
CREATE OR REPLACE FUNCTION public.verify_recent_reviews(
    p_user_id UUID,
    p_hours_back INT DEFAULT 2
) RETURNS TABLE(
    review_id UUID,
    card_id UUID,
    lesson_id UUID,
    lesson_name TEXT,
    quality_rating INT,
    response_time_ms INT,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ,
    card_status TEXT,
    front_content TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.id as review_id,
        r.card_id,
        c.lesson_id,
        l.name as lesson_name,
        r.quality_rating,
        r.response_time_ms,
        r.completed_at,
        r.created_at,
        r.card_status,
        LEFT(c.front_content, 100) as front_content
    FROM public.sr_reviews r
    INNER JOIN public.sr_cards c ON r.card_id = c.id
    INNER JOIN public.lessons l ON c.lesson_id = l.id
    WHERE r.student_id = p_user_id
      AND r.completed_at IS NOT NULL
      AND r.completed_at >= NOW() - (p_hours_back || ' hours')::INTERVAL
    ORDER BY r.completed_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check what cards are currently available for study
CREATE OR REPLACE FUNCTION public.verify_available_cards(
    p_user_id UUID
) RETURNS TABLE(
    card_id UUID,
    lesson_id UUID,
    lesson_name TEXT,
    card_pool TEXT,
    review_id UUID,
    scheduled_for TIMESTAMPTZ,
    front_content TEXT,
    can_accept BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        gcs.card_id,
        gcs.lesson_id,
        gcs.lesson_name,
        gcs.card_pool,
        gcs.review_id,
        gcs.scheduled_for,
        LEFT(gcs.front_content, 100) as front_content,
        gcs.can_accept
    FROM public.get_cards_for_study(p_user_id, 'both', 50, 50) gcs
    ORDER BY gcs.card_pool, gcs.scheduled_for;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to verify progress tracking state
CREATE OR REPLACE FUNCTION public.verify_progress_state(
    p_user_id UUID
) RETURNS TABLE(
    lesson_id UUID,
    lesson_name TEXT,
    cards_total INT,
    cards_reviewed INT,
    cards_learned INT,
    average_quality DECIMAL,
    last_review_date DATE,
    actual_completed_reviews INT,
    actual_learned_cards INT,
    progress_matches_reality BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.lesson_id,
        l.name as lesson_name,
        p.cards_total,
        p.cards_reviewed,
        p.cards_learned,
        p.average_quality,
        p.last_review_date,
        -- Count actual completed reviews
        (
            SELECT COUNT(*)::INT
            FROM public.sr_reviews r
            INNER JOIN public.sr_cards c ON r.card_id = c.id
            WHERE r.student_id = p_user_id
              AND c.lesson_id = p.lesson_id
              AND r.completed_at IS NOT NULL
        ) as actual_completed_reviews,
        -- Count actual learned cards (first-time quality >= 4)
        (
            SELECT COUNT(*)::INT
            FROM public.sr_reviews r
            INNER JOIN public.sr_cards c ON r.card_id = c.id
            WHERE r.student_id = p_user_id
              AND c.lesson_id = p.lesson_id
              AND r.completed_at IS NOT NULL
              AND r.quality_rating >= 4
              AND NOT EXISTS (
                  SELECT 1 FROM public.sr_reviews r2
                  WHERE r2.card_id = r.card_id
                    AND r2.student_id = r.student_id
                    AND r2.completed_at < r.completed_at
                    AND r2.quality_rating >= 3
              )
        ) as actual_learned_cards,
        -- Check if progress matches reality
        (
            p.cards_reviewed = (
                SELECT COUNT(*)
                FROM public.sr_reviews r
                INNER JOIN public.sr_cards c ON r.card_id = c.id
                WHERE r.student_id = p_user_id
                  AND c.lesson_id = p.lesson_id
                  AND r.completed_at IS NOT NULL
            )
        ) as progress_matches_reality
    FROM public.sr_progress p
    INNER JOIN public.lessons l ON p.lesson_id = l.id
    WHERE p.student_id = p_user_id
    ORDER BY l.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check today's study statistics calculation step by step
CREATE OR REPLACE FUNCTION public.debug_today_stats_calculation(
    p_user_id UUID
) RETURNS TABLE(
    step_name TEXT,
    count_value INT,
    details JSONB
) AS $$
DECLARE
    v_today DATE := CURRENT_DATE;
BEGIN
    -- Step 1: Raw completed reviews today
    RETURN QUERY
    SELECT 
        'Raw Completed Reviews Today'::TEXT,
        COUNT(*)::INT,
        jsonb_build_object(
            'date_filter', v_today,
            'current_timestamp', NOW(),
            'sample_review', (
                SELECT jsonb_build_object(
                    'review_id', r.id,
                    'completed_at', r.completed_at,
                    'quality_rating', r.quality_rating,
                    'card_id', r.card_id
                )
                FROM public.sr_reviews r
                WHERE r.student_id = p_user_id
                  AND r.completed_at IS NOT NULL
                  AND r.completed_at::DATE = v_today
                ORDER BY r.completed_at DESC
                LIMIT 1
            )
        )
    FROM public.sr_reviews r
    WHERE r.student_id = p_user_id
      AND r.completed_at IS NOT NULL
      AND r.completed_at::DATE = v_today;

    -- Step 2: Reviews with lesson participation
    RETURN QUERY
    SELECT 
        'Reviews With Lesson Participation'::TEXT,
        COUNT(*)::INT,
        jsonb_build_object(
            'joins_applied', 'sr_reviews -> sr_cards -> lesson_participants',
            'filters', 'student_id, lesson participation, approved cards, today date'
        )
    FROM public.sr_reviews r
    INNER JOIN public.sr_cards c ON r.card_id = c.id
    INNER JOIN public.lesson_participants lp ON c.lesson_id = lp.lesson_id
    WHERE r.student_id = p_user_id
      AND lp.student_id = p_user_id
      AND c.status = 'approved'
      AND r.completed_at IS NOT NULL
      AND r.completed_at::DATE = v_today;

    -- Step 3: What get_today_study_stats returns
    RETURN QUERY
    SELECT 
        'get_today_study_stats Result'::TEXT,
        COALESCE(stats.cards_studied_today, 0),
        jsonb_build_object(
            'total_cards_ready', COALESCE(stats.total_cards_ready, 0),
            'study_time_minutes', COALESCE(stats.study_time_minutes, 0),
            'cards_mastered_today', COALESCE(stats.cards_mastered_today, 0)
        )
    FROM public.get_today_study_stats(p_user_id) stats;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.verify_recent_reviews(UUID, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_available_cards(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_progress_state(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.debug_today_stats_calculation(UUID) TO authenticated;

-- Add helpful comments
COMMENT ON FUNCTION public.verify_recent_reviews(UUID, INT) IS
'Check what reviews have actually been recorded for a user in recent hours';

COMMENT ON FUNCTION public.verify_available_cards(UUID) IS
'Verify what cards are currently available for study for a user';

COMMENT ON FUNCTION public.verify_progress_state(UUID) IS
'Compare progress tracking records with actual completed reviews to find discrepancies';

COMMENT ON FUNCTION public.debug_today_stats_calculation(UUID) IS
'Step-by-step debugging of today statistics calculation to identify where the count goes wrong';