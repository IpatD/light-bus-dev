-- =============================================================================
-- FIX FUNCTION NAME MISMATCH AND STREAK RECALCULATION BUG
-- =============================================================================
-- 
-- Issues found:
-- 1. Frontend calls 'record_sr_review_fixed' but our fix is in 'record_sr_review'
-- 2. recalculate_all_streaks function has date arithmetic error
-- 3. Need to ensure frontend uses the correct function
-- =============================================================================

-- 1. Create an alias for the fixed function so frontend can call it
CREATE OR REPLACE FUNCTION record_sr_review_fixed(
    p_user_id UUID,
    p_card_id UUID,
    p_quality INT,
    p_response_time_ms INT,
    p_client_timezone TEXT DEFAULT 'Europe/Warsaw'
) RETURNS TABLE(
    review_id UUID,
    next_review_date TIMESTAMPTZ,
    new_interval INT,
    success BOOLEAN
) AS $$
BEGIN
    -- Simply call our fixed record_sr_review function
    RETURN QUERY
    SELECT * FROM record_sr_review(p_user_id, p_card_id, p_quality, p_response_time_ms, p_client_timezone);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Fix the recalculate_all_streaks function with proper date arithmetic
CREATE OR REPLACE FUNCTION recalculate_all_streaks(
    p_client_timezone TEXT DEFAULT 'Europe/Warsaw'
) RETURNS TABLE(
    student_id UUID,
    lesson_id UUID,
    old_streak INT,
    new_streak INT,
    last_review_date DATE
) AS $$
DECLARE
    progress_record RECORD;
    v_client_today DATE;
    v_client_yesterday DATE;
    v_new_streak INT;
    v_latest_review_date DATE;
    v_consecutive_days INT;
BEGIN
    v_client_today := get_current_client_date(p_client_timezone);
    v_client_yesterday := v_client_today - INTERVAL '1 day';
    
    -- Loop through all progress records that have reviews
    FOR progress_record IN 
        SELECT DISTINCT sp.id, sp.student_id, sp.lesson_id, sp.study_streak, sp.last_review_date
        FROM public.sr_progress sp
        INNER JOIN public.sr_reviews r ON r.student_id = sp.student_id
        INNER JOIN public.sr_cards c ON r.card_id = c.id AND c.lesson_id = sp.lesson_id
        WHERE r.completed_at IS NOT NULL
    LOOP
        -- Get the actual latest review date for this user/lesson
        SELECT get_client_date(MAX(r.completed_at), p_client_timezone)
        INTO v_latest_review_date
        FROM public.sr_reviews r
        INNER JOIN public.sr_cards c ON r.card_id = c.id
        WHERE r.student_id = progress_record.student_id
          AND c.lesson_id = progress_record.lesson_id
          AND r.completed_at IS NOT NULL;
        
        -- Calculate consecutive days from the latest review backwards
        IF v_latest_review_date IS NOT NULL THEN
            -- Count consecutive days of activity
            WITH daily_activity AS (
                SELECT DISTINCT get_client_date(r.completed_at, p_client_timezone) as review_date
                FROM public.sr_reviews r
                INNER JOIN public.sr_cards c ON r.card_id = c.id
                WHERE r.student_id = progress_record.student_id
                  AND c.lesson_id = progress_record.lesson_id
                  AND r.completed_at IS NOT NULL
                  AND get_client_date(r.completed_at, p_client_timezone) >= v_client_today - INTERVAL '100 days'
                ORDER BY review_date DESC
            ),
            consecutive_check AS (
                SELECT 
                    review_date,
                    ROW_NUMBER() OVER (ORDER BY review_date DESC) as day_rank,
                    review_date = v_latest_review_date - INTERVAL '1 day' * (ROW_NUMBER() OVER (ORDER BY review_date DESC) - 1) as is_consecutive
                FROM daily_activity
            )
            SELECT COUNT(*)::INT INTO v_consecutive_days
            FROM consecutive_check 
            WHERE is_consecutive = true;
            
            -- Set streak based on consecutive days
            v_new_streak := CASE
                WHEN v_consecutive_days = 0 AND v_latest_review_date = v_client_today THEN 1
                WHEN v_consecutive_days > 0 THEN v_consecutive_days
                ELSE 0
            END;
            
            -- Update the progress record if streak has changed
            IF v_new_streak != progress_record.study_streak THEN
                UPDATE public.sr_progress
                SET 
                    study_streak = v_new_streak,
                    last_review_date = v_latest_review_date,
                    updated_at = NOW()
                WHERE id = progress_record.id;
                
                -- Return the change information
                RETURN QUERY SELECT 
                    progress_record.student_id,
                    progress_record.lesson_id,
                    progress_record.study_streak,
                    v_new_streak,
                    v_latest_review_date;
            END IF;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Simple manual streak fix for immediate testing
CREATE OR REPLACE FUNCTION fix_student_streak_manual(
    p_student_id UUID,
    p_client_timezone TEXT DEFAULT 'Europe/Warsaw'
) RETURNS TABLE(
    lesson_id UUID,
    old_streak INT,
    new_streak INT,
    last_review_date DATE,
    today_reviews INT
) AS $$
DECLARE
    progress_record RECORD;
    v_client_today DATE;
    v_today_reviews INT;
    v_calculated_streak INT;
BEGIN
    v_client_today := get_current_client_date(p_client_timezone);
    
    -- Process each lesson for this student
    FOR progress_record IN 
        SELECT sp.id, sp.lesson_id, sp.study_streak, sp.last_review_date
        FROM public.sr_progress sp
        WHERE sp.student_id = p_student_id
    LOOP
        -- Count reviews completed today for this lesson
        SELECT COUNT(*)::INT INTO v_today_reviews
        FROM public.sr_reviews r
        INNER JOIN public.sr_cards c ON r.card_id = c.id
        WHERE r.student_id = p_student_id
          AND c.lesson_id = progress_record.lesson_id
          AND r.completed_at IS NOT NULL
          AND get_client_date(r.completed_at, p_client_timezone) = v_client_today;
        
        -- Calculate new streak
        v_calculated_streak := CASE
            WHEN v_today_reviews > 0 AND progress_record.last_review_date = v_client_today THEN 
                GREATEST(progress_record.study_streak, 1)
            WHEN v_today_reviews > 0 AND progress_record.last_review_date = v_client_today - INTERVAL '1 day' THEN 
                progress_record.study_streak + 1
            WHEN v_today_reviews > 0 THEN 
                1
            ELSE 
                progress_record.study_streak
        END;
        
        -- Update if needed
        IF v_calculated_streak != progress_record.study_streak OR 
           (v_today_reviews > 0 AND progress_record.last_review_date != v_client_today) THEN
            
            UPDATE public.sr_progress
            SET 
                study_streak = v_calculated_streak,
                last_review_date = CASE WHEN v_today_reviews > 0 THEN v_client_today ELSE last_review_date END,
                updated_at = NOW()
            WHERE id = progress_record.id;
        END IF;
        
        -- Return the results
        RETURN QUERY SELECT 
            progress_record.lesson_id,
            progress_record.study_streak,
            v_calculated_streak,
            CASE WHEN v_today_reviews > 0 THEN v_client_today ELSE progress_record.last_review_date END,
            v_today_reviews;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- GRANT PERMISSIONS
-- =============================================================================

GRANT EXECUTE ON FUNCTION record_sr_review_fixed(UUID, UUID, INT, INT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION recalculate_all_streaks(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fix_student_streak_manual(UUID, TEXT) TO authenticated;

-- =============================================================================
-- COMMENTS
-- =============================================================================

COMMENT ON FUNCTION record_sr_review_fixed(UUID, UUID, INT, INT, TEXT) IS
'Alias for record_sr_review - matches frontend function call expectations';

COMMENT ON FUNCTION recalculate_all_streaks(TEXT) IS
'FIXED: Recalculate all user streaks with proper date arithmetic';

COMMENT ON FUNCTION fix_student_streak_manual(UUID, TEXT) IS
'Manual streak fix for specific student - immediate testing utility';

-- =============================================================================
-- SUMMARY
-- =============================================================================

SELECT 'Fixed function name mismatch and streak recalculation bugs' as status,
       'Frontend can now call record_sr_review_fixed successfully' as frontend_fix,
       'Use fix_student_streak_manual() for immediate testing' as testing_recommendation;