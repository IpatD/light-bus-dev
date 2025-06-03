-- Add Daily Study Tracking Function
-- This function provides real-time statistics for today's study session

-- Function to get today's study statistics for a student
CREATE OR REPLACE FUNCTION public.get_today_study_stats(
    p_user_id UUID
) RETURNS TABLE(
    cards_studied_today INT,
    total_cards_ready INT,
    study_time_minutes INT,
    sessions_completed INT,
    new_cards_accepted_today INT,
    cards_mastered_today INT
) AS $$
DECLARE
    v_today DATE := CURRENT_DATE;
BEGIN
    RETURN QUERY
    SELECT 
        -- Cards studied today (completed reviews)
        COUNT(CASE 
            WHEN r.completed_at::DATE = v_today 
            THEN 1 
        END)::INT as cards_studied_today,
        
        -- Total cards currently ready for study
        (
            SELECT COUNT(*)::INT 
            FROM public.get_cards_for_study(p_user_id, 'both', 100, 100)
        ) as total_cards_ready,
        
        -- Approximate study time today (based on response times)
        COALESCE(
            ROUND(
                SUM(
                    CASE 
                        WHEN r.completed_at::DATE = v_today AND r.response_time_ms IS NOT NULL
                        THEN r.response_time_ms / 60000.0  -- Convert to minutes
                    END
                )
            )::INT, 
            0
        ) as study_time_minutes,
        
        -- Study sessions completed today (grouped by hour)
        COUNT(DISTINCT 
            CASE 
                WHEN r.completed_at::DATE = v_today 
                THEN DATE_TRUNC('hour', r.completed_at)
            END
        )::INT as sessions_completed,
        
        -- New cards accepted today (cards that changed from 'new' to 'accepted')
        COUNT(CASE 
            WHEN r.accepted_at::DATE = v_today 
            THEN 1 
        END)::INT as new_cards_accepted_today,
        
        -- Cards mastered today (quality rating >= 4 on first-time success)
        COUNT(CASE 
            WHEN r.completed_at::DATE = v_today 
            AND r.quality_rating >= 4 
            AND NOT EXISTS (
                SELECT 1 FROM public.sr_reviews r2 
                WHERE r2.card_id = r.card_id 
                AND r2.student_id = r.student_id 
                AND r2.completed_at < r.completed_at
                AND r2.quality_rating >= 3
            )
            THEN 1 
        END)::INT as cards_mastered_today
        
    FROM public.sr_reviews r
    INNER JOIN public.sr_cards c ON r.card_id = c.id
    INNER JOIN public.lesson_participants lp ON c.lesson_id = lp.lesson_id
    WHERE r.student_id = p_user_id
      AND lp.student_id = p_user_id
      AND c.status = 'approved';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get cards ready count with breakdown
CREATE OR REPLACE FUNCTION public.get_cards_ready_breakdown(
    p_user_id UUID
) RETURNS TABLE(
    new_cards_count INT,
    due_cards_count INT,
    total_ready INT,
    next_due_time TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    WITH card_counts AS (
        SELECT 
            card_pool,
            COUNT(*) as count
        FROM public.get_cards_for_study(p_user_id, 'both', 100, 100)
        GROUP BY card_pool
    ),
    next_due AS (
        SELECT MIN(scheduled_for) as next_time
        FROM public.sr_reviews r
        INNER JOIN public.sr_cards c ON r.card_id = c.id
        INNER JOIN public.lesson_participants lp ON c.lesson_id = lp.lesson_id
        WHERE r.student_id = p_user_id
          AND lp.student_id = p_user_id
          AND c.status = 'approved'
          AND r.completed_at IS NULL
          AND r.scheduled_for > NOW()
    )
    SELECT 
        COALESCE((SELECT count FROM card_counts WHERE card_pool = 'new'), 0)::INT as new_cards_count,
        COALESCE((SELECT count FROM card_counts WHERE card_pool = 'due'), 0)::INT as due_cards_count,
        COALESCE(SUM(count), 0)::INT as total_ready,
        (SELECT next_time FROM next_due) as next_due_time
    FROM card_counts;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.get_today_study_stats(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_cards_ready_breakdown(UUID) TO authenticated;

-- Add helpful comments
COMMENT ON FUNCTION public.get_today_study_stats(UUID) IS
'Get comprehensive statistics for today''s study session including cards studied, time spent, and progress made';

COMMENT ON FUNCTION public.get_cards_ready_breakdown(UUID) IS
'Get breakdown of cards ready for study with new/due counts and next due time';