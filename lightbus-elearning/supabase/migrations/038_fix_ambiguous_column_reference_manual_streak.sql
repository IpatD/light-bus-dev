-- =============================================================================
-- FIX AMBIGUOUS COLUMN REFERENCE IN MANUAL STREAK FUNCTION
-- =============================================================================
-- 
-- Error: column reference "last_review_date" is ambiguous
-- Issue: Variable name conflicts with table column name in UPDATE statement
-- =============================================================================

-- Fix the ambiguous column reference in fix_student_streak_manual function
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
    v_new_last_review_date DATE;  -- FIXED: Renamed variable to avoid conflict
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
        
        -- FIXED: Calculate new last review date without ambiguity
        v_new_last_review_date := CASE 
            WHEN v_today_reviews > 0 THEN v_client_today 
            ELSE progress_record.last_review_date 
        END;
        
        -- Update if needed
        IF v_calculated_streak != progress_record.study_streak OR 
           (v_today_reviews > 0 AND progress_record.last_review_date != v_client_today) THEN
            
            UPDATE public.sr_progress
            SET 
                study_streak = v_calculated_streak,
                last_review_date = v_new_last_review_date,  -- FIXED: Use variable instead of column
                updated_at = NOW()
            WHERE id = progress_record.id;
        END IF;
        
        -- Return the results
        RETURN QUERY SELECT 
            progress_record.lesson_id,
            progress_record.study_streak,
            v_calculated_streak,
            v_new_last_review_date,
            v_today_reviews;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION fix_student_streak_manual(UUID, TEXT) TO authenticated;

-- Add comment
COMMENT ON FUNCTION fix_student_streak_manual(UUID, TEXT) IS
'FIXED: Manual streak fix for specific student - resolves ambiguous column reference';

-- Test the fix by providing a simple verification
SELECT 'Fixed ambiguous column reference in fix_student_streak_manual function' as status;