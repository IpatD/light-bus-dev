-- Fix Daily Study Statistics Calculation
-- The previous function had incorrect field references and query logic

-- Drop and recreate the get_today_study_stats function with fixes
DROP FUNCTION IF EXISTS public.get_today_study_stats(UUID);

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
    WITH today_reviews AS (
        -- Get all completed reviews from today with lesson participation check
        SELECT 
            r.id,
            r.card_id,
            r.student_id,
            r.completed_at,
            r.quality_rating,
            r.response_time_ms,
            r.created_at,
            c.lesson_id
        FROM public.sr_reviews r
        INNER JOIN public.sr_cards c ON r.card_id = c.id
        INNER JOIN public.lesson_participants lp ON c.lesson_id = lp.lesson_id
        WHERE r.student_id = p_user_id
          AND lp.student_id = p_user_id
          AND c.status = 'approved'
          AND r.completed_at IS NOT NULL
          AND r.completed_at::DATE = v_today
    ),
    new_cards_today AS (
        -- Cards that were first completed today (moved from new status)
        SELECT 
            tr.card_id,
            tr.completed_at,
            tr.quality_rating
        FROM today_reviews tr
        WHERE NOT EXISTS (
            SELECT 1 FROM public.sr_reviews r2
            WHERE r2.card_id = tr.card_id
              AND r2.student_id = tr.student_id
              AND r2.completed_at IS NOT NULL
              AND r2.completed_at::DATE < v_today
        )
    ),
    study_stats AS (
        SELECT 
            -- Cards studied today (completed reviews)
            COUNT(*)::INT as cards_studied_today,
            
            -- Approximate study time today (based on response times)
            COALESCE(
                ROUND(
                    SUM(
                        CASE 
                            WHEN response_time_ms IS NOT NULL
                            THEN response_time_ms / 60000.0  -- Convert to minutes
                            ELSE 0
                        END
                    )
                )::INT, 
                0
            ) as study_time_minutes,
            
            -- Study sessions completed today (grouped by hour)
            COUNT(DISTINCT DATE_TRUNC('hour', completed_at))::INT as sessions_completed,
            
            -- Cards mastered today (quality rating >= 4 on first completion)
            (
                SELECT COUNT(*)::INT 
                FROM new_cards_today 
                WHERE quality_rating >= 4
            ) as cards_mastered_today
            
        FROM today_reviews
    ),
    ready_cards AS (
        -- Total cards currently ready for study
        SELECT COUNT(*)::INT as total_ready
        FROM public.get_cards_for_study(p_user_id, 'both', 100, 100)
    )
    SELECT 
        COALESCE(ss.cards_studied_today, 0),
        COALESCE(rc.total_ready, 0),
        COALESCE(ss.study_time_minutes, 0),
        COALESCE(ss.sessions_completed, 0),
        (SELECT COUNT(*)::INT FROM new_cards_today) as new_cards_accepted_today,
        COALESCE(ss.cards_mastered_today, 0)
    FROM study_stats ss
    CROSS JOIN ready_cards rc;
    
    -- If no data found, return zeros
    IF NOT FOUND THEN
        RETURN QUERY
        SELECT 
            0::INT, -- cards_studied_today
            (SELECT COUNT(*)::INT FROM public.get_cards_for_study(p_user_id, 'both', 100, 100)), -- total_cards_ready
            0::INT, -- study_time_minutes
            0::INT, -- sessions_completed
            0::INT, -- new_cards_accepted_today
            0::INT; -- cards_mastered_today
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Test function to verify the fix
CREATE OR REPLACE FUNCTION public.test_today_study_stats(
    p_user_id UUID
) RETURNS TABLE(
    test_name TEXT,
    result TEXT,
    details JSONB
) AS $$
DECLARE
    v_stats RECORD;
    v_today DATE := CURRENT_DATE;
BEGIN
    -- Get today's stats
    SELECT * INTO v_stats FROM public.get_today_study_stats(p_user_id);
    
    -- Test 1: Check if function returns data
    RETURN QUERY SELECT 
        'Stats Function Execution'::TEXT,
        CASE WHEN v_stats IS NOT NULL THEN 'PASS' ELSE 'FAIL' END::TEXT,
        jsonb_build_object(
            'cards_studied_today', COALESCE(v_stats.cards_studied_today, 0),
            'total_cards_ready', COALESCE(v_stats.total_cards_ready, 0),
            'study_time_minutes', COALESCE(v_stats.study_time_minutes, 0),
            'cards_mastered_today', COALESCE(v_stats.cards_mastered_today, 0)
        );
    
    -- Test 2: Check completed reviews from today
    RETURN QUERY
    SELECT 
        'Today Completed Reviews'::TEXT,
        'INFO'::TEXT,
        jsonb_build_object(
            'count', (
                SELECT COUNT(*)
                FROM public.sr_reviews r
                INNER JOIN public.sr_cards c ON r.card_id = c.id
                INNER JOIN public.lesson_participants lp ON c.lesson_id = lp.lesson_id
                WHERE r.student_id = p_user_id
                  AND lp.student_id = p_user_id
                  AND r.completed_at IS NOT NULL
                  AND r.completed_at::DATE = v_today
            ),
            'today_date', v_today
        );
    
    -- Test 3: Check available cards
    RETURN QUERY
    SELECT 
        'Available Cards'::TEXT,
        'INFO'::TEXT,
        jsonb_build_object(
            'count', (SELECT COUNT(*) FROM public.get_cards_for_study(p_user_id, 'both', 100, 100))
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.get_today_study_stats(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.test_today_study_stats(UUID) TO authenticated;

-- Add helpful comments
COMMENT ON FUNCTION public.get_today_study_stats(UUID) IS
'Fixed version: Get comprehensive statistics for today''s study session with proper field references and logic';

COMMENT ON FUNCTION public.test_today_study_stats(UUID) IS
'Test function to verify that daily study statistics are calculating correctly';