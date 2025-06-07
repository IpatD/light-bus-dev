-- =============================================================================
-- FIX STREAK CALCULATION FOR FIRST DAY STUDY SESSION
-- =============================================================================
-- 
-- Issue: When a user studies for the first time or after a break, the streak
-- should be set to 1, but the current logic in record_sr_review doesn't 
-- properly handle this case. The streak remains 0 or doesn't update correctly.
--
-- The current logic:
-- - WHEN last_review_date = today THEN keep current streak
-- - WHEN last_review_date = yesterday THEN increment streak  
-- - ELSE set to 1
--
-- Problem: The "ELSE 1" case should handle first-time study, but there might
-- be an issue with how the streak is being initialized or updated.
-- =============================================================================

-- Enhanced record_sr_review function with proper streak initialization
CREATE OR REPLACE FUNCTION record_sr_review(
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
DECLARE
    v_review_id UUID;
    v_current_review public.sr_reviews%ROWTYPE;
    v_card public.sr_cards%ROWTYPE;
    v_lesson_id UUID;
    v_progress public.sr_progress%ROWTYPE;
    v_calc_result RECORD;
    v_next_date TIMESTAMPTZ;
    v_is_first_success BOOLEAN := FALSE;
    v_client_today DATE;
    v_client_yesterday DATE;
    v_new_streak INT;
BEGIN
    -- Get current date in client timezone for consistent progress tracking
    v_client_today := get_current_client_date(p_client_timezone);
    v_client_yesterday := v_client_today - INTERVAL '1 day';
    
    -- Get and lock the current scheduled review
    SELECT * INTO v_current_review
    FROM public.sr_reviews
    WHERE card_id = p_card_id 
      AND student_id = p_user_id 
      AND completed_at IS NULL
    ORDER BY created_at DESC, id DESC
    LIMIT 1
    FOR UPDATE;

    -- If no pending review found, create initial review
    IF v_current_review.id IS NULL THEN
        SELECT * INTO v_card FROM public.sr_cards WHERE id = p_card_id;
        
        IF v_card.id IS NULL THEN
            RAISE EXCEPTION 'Card not found: %', p_card_id;
        END IF;

        -- Create initial review record
        INSERT INTO public.sr_reviews (
            card_id, student_id, scheduled_for, interval_days, ease_factor, repetition_count
        ) VALUES (
            p_card_id, p_user_id, NOW(), 1, 2.5, 0
        ) RETURNING * INTO v_current_review;
    END IF;

    -- Calculate new interval using SM-2 algorithm
    SELECT * INTO v_calc_result
    FROM calculate_sr_interval(
        v_current_review.interval_days,
        v_current_review.ease_factor,
        p_quality
    );

    -- Calculate next review date
    v_next_date := NOW() + (v_calc_result.new_interval || ' days')::INTERVAL;

    -- Create next review BEFORE completing current (prevents race condition)
    IF p_quality >= 3 THEN
        INSERT INTO public.sr_reviews (
            card_id,
            student_id,
            scheduled_for,
            interval_days,
            ease_factor,
            repetition_count,
            card_status
        ) VALUES (
            p_card_id,
            p_user_id,
            v_next_date,
            v_calc_result.new_interval,
            v_calc_result.new_easiness_factor,
            v_calc_result.new_repetition_count,
            CASE 
                WHEN v_current_review.card_status = 'new' THEN 'accepted'::card_status_enum
                ELSE v_current_review.card_status
            END
        );
        
        -- Check if this is first time success for accurate progress tracking
        v_is_first_success := (v_current_review.card_status = 'new' AND p_quality >= 4);
    ELSE
        -- For failures, use graduated retry intervals
        INSERT INTO public.sr_reviews (
            card_id,
            student_id,
            scheduled_for,
            interval_days,
            ease_factor,
            repetition_count,
            card_status
        ) VALUES (
            p_card_id,
            p_user_id,
            NOW() + (v_calc_result.new_interval || ' days')::INTERVAL,
            v_calc_result.new_interval,
            v_calc_result.new_easiness_factor,
            0,
            v_current_review.card_status
        );
        v_next_date := NOW() + (v_calc_result.new_interval || ' days')::INTERVAL;
    END IF;

    -- Complete current review
    UPDATE public.sr_reviews
    SET 
        completed_at = NOW(),
        quality_rating = p_quality,
        response_time_ms = p_response_time_ms
    WHERE id = v_current_review.id;

    v_review_id := v_current_review.id;

    -- FIXED: Enhanced timezone-aware progress tracking with proper streak logic
    SELECT * INTO v_card FROM public.sr_cards WHERE id = p_card_id;
    v_lesson_id := v_card.lesson_id;

    -- Get or create progress record
    SELECT * INTO v_progress
    FROM public.sr_progress
    WHERE student_id = p_user_id AND lesson_id = v_lesson_id;

    IF v_progress.id IS NULL THEN
        -- FIXED: For new progress records, always start with streak = 1
        INSERT INTO public.sr_progress (
            student_id, lesson_id, cards_total, cards_reviewed, cards_learned,
            average_quality, study_streak, last_review_date, next_review_date
        ) VALUES (
            p_user_id, v_lesson_id, 1, 1, CASE WHEN v_is_first_success THEN 1 ELSE 0 END,
            p_quality, 1, v_client_today, get_client_date(v_next_date, p_client_timezone)
        );
    ELSE
        -- FIXED: Enhanced streak calculation logic
        -- Calculate the new streak based on the last review date
        v_new_streak := CASE
            -- If already studied today, keep current streak
            WHEN v_progress.last_review_date = v_client_today THEN v_progress.study_streak
            -- If last study was yesterday, increment streak
            WHEN v_progress.last_review_date = v_client_yesterday THEN v_progress.study_streak + 1
            -- If there's a gap or this is the first study, set to 1
            ELSE 1
        END;
        
        -- Update existing progress with enhanced streak calculation
        UPDATE public.sr_progress
        SET
            cards_reviewed = cards_reviewed + 1,
            cards_learned = CASE 
                WHEN v_is_first_success THEN cards_learned + 1
                ELSE cards_learned 
            END,
            average_quality = (
                (average_quality * (cards_reviewed - 1) + p_quality) / 
                GREATEST(cards_reviewed, 1.0)
            ),
            -- FIXED: Use the calculated streak
            study_streak = v_new_streak,
            last_review_date = v_client_today,
            next_review_date = LEAST(next_review_date, get_client_date(v_next_date, p_client_timezone)),
            updated_at = NOW()
        WHERE id = v_progress.id;
        
        -- Debug logging for streak calculation
        RAISE NOTICE 'Streak calculation for user % lesson %: previous_date=%, today=%, yesterday=%, old_streak=%, new_streak=%', 
            p_user_id, v_lesson_id, v_progress.last_review_date, v_client_today, v_client_yesterday, 
            v_progress.study_streak, v_new_streak;
    END IF;

    -- Return results
    RETURN QUERY SELECT 
        v_review_id,
        v_next_date,
        v_calc_result.new_interval,
        TRUE;

EXCEPTION WHEN OTHERS THEN
    -- Return error state
    RETURN QUERY SELECT 
        NULL::UUID,
        NULL::TIMESTAMPTZ,
        NULL::INT,
        FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- ADD FUNCTION TO MANUALLY TRIGGER STREAK CALCULATION
-- =============================================================================

-- Function to manually recalculate streaks for all users (debugging purpose)
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
BEGIN
    v_client_today := get_current_client_date(p_client_timezone);
    v_client_yesterday := v_client_today - INTERVAL '1 day';
    
    -- Loop through all progress records
    FOR progress_record IN 
        SELECT sp.*, COUNT(r.id) as total_reviews
        FROM public.sr_progress sp
        LEFT JOIN public.sr_reviews r ON r.student_id = sp.student_id
        LEFT JOIN public.sr_cards c ON r.card_id = c.id AND c.lesson_id = sp.lesson_id
        WHERE r.completed_at IS NOT NULL
        GROUP BY sp.id, sp.student_id, sp.lesson_id, sp.cards_total, sp.cards_reviewed, 
                 sp.cards_learned, sp.average_quality, sp.study_streak, sp.last_review_date, 
                 sp.next_review_date, sp.created_at, sp.updated_at
        HAVING COUNT(r.id) > 0
    LOOP
        -- Get the actual latest review date for this user/lesson
        SELECT get_client_date(MAX(r.completed_at), p_client_timezone)
        INTO v_latest_review_date
        FROM public.sr_reviews r
        INNER JOIN public.sr_cards c ON r.card_id = c.id
        WHERE r.student_id = progress_record.student_id
          AND c.lesson_id = progress_record.lesson_id
          AND r.completed_at IS NOT NULL;
        
        -- Calculate proper streak based on latest review date
        IF v_latest_review_date IS NOT NULL THEN
            -- Check if user has studied today or yesterday for continuous streak
            WITH daily_activity AS (
                SELECT DISTINCT get_client_date(r.completed_at, p_client_timezone) as review_date
                FROM public.sr_reviews r
                INNER JOIN public.sr_cards c ON r.card_id = c.id
                WHERE r.student_id = progress_record.student_id
                  AND c.lesson_id = progress_record.lesson_id
                  AND r.completed_at IS NOT NULL
                ORDER BY review_date DESC
            ),
            streak_calculation AS (
                SELECT 
                    ROW_NUMBER() OVER (ORDER BY review_date DESC) as day_rank,
                    review_date,
                    review_date = v_client_today OR review_date = v_client_today - (ROW_NUMBER() OVER (ORDER BY review_date DESC) - 1) as is_consecutive
                FROM daily_activity
                WHERE review_date >= v_client_today - INTERVAL '100 days' -- Look back max 100 days
            )
            SELECT COUNT(*) INTO v_new_streak
            FROM streak_calculation 
            WHERE is_consecutive = true
            ORDER BY day_rank;
            
            -- If no consecutive days found but there are reviews, set to 1
            IF v_new_streak = 0 AND v_latest_review_date = v_client_today THEN
                v_new_streak = 1;
            END IF;
            
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

-- =============================================================================
-- GRANT PERMISSIONS
-- =============================================================================

GRANT EXECUTE ON FUNCTION record_sr_review(UUID, UUID, INT, INT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION recalculate_all_streaks(TEXT) TO authenticated;

-- =============================================================================
-- COMMENTS
-- =============================================================================

COMMENT ON FUNCTION record_sr_review(UUID, UUID, INT, INT, TEXT) IS
'FIXED: Enhanced record spaced repetition review with proper first-day streak calculation';

COMMENT ON FUNCTION recalculate_all_streaks(TEXT) IS
'Debugging function to recalculate all user streaks based on actual review history';

-- =============================================================================
-- SUMMARY
-- =============================================================================

SELECT 'Fixed streak calculation logic for first-day study sessions' as status,
       'Run recalculate_all_streaks() to fix existing data' as next_action;