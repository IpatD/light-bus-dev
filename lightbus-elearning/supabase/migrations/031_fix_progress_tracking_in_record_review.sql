-- Fix Progress Tracking in record_sr_review Function
-- The issue is that progress tracking is not being updated correctly when reviews are recorded

-- Enhanced record_sr_review function with fixed progress tracking
CREATE OR REPLACE FUNCTION record_sr_review(
    p_user_id UUID,
    p_card_id UUID,
    p_quality INT,
    p_response_time_ms INT
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
    v_error_msg TEXT := NULL;
    v_progress_exists BOOLEAN := FALSE;
BEGIN
    -- Log the attempt
    PERFORM public.log_sr_review_attempt(p_user_id, p_card_id, p_quality, p_response_time_ms, FALSE, 'Starting review recording');
    
    -- TRANSACTION START: Prevent race conditions
    -- Get and lock the current scheduled review
    SELECT * INTO v_current_review
    FROM public.sr_reviews
    WHERE card_id = p_card_id 
      AND student_id = p_user_id 
      AND completed_at IS NULL
    ORDER BY created_at DESC, id DESC
    LIMIT 1
    FOR UPDATE;  -- Lock the row to prevent race conditions

    -- If no pending review found, create initial review
    IF v_current_review.id IS NULL THEN
        SELECT * INTO v_card FROM public.sr_cards WHERE id = p_card_id;
        
        IF v_card.id IS NULL THEN
            v_error_msg := 'Card not found: ' || p_card_id::TEXT;
            PERFORM public.log_sr_review_attempt(p_user_id, p_card_id, p_quality, p_response_time_ms, FALSE, v_error_msg);
            RAISE EXCEPTION '%', v_error_msg;
        END IF;

        -- Create initial review record
        INSERT INTO public.sr_reviews (
            card_id, student_id, scheduled_for, interval_days, ease_factor, repetition_count
        ) VALUES (
            p_card_id, p_user_id, NOW(), 1, 2.5, 0
        ) RETURNING * INTO v_current_review;
        
        PERFORM public.log_sr_review_attempt(p_user_id, p_card_id, p_quality, p_response_time_ms, FALSE, 'Created initial review record');
    END IF;

    -- Get card and lesson info
    SELECT * INTO v_card FROM public.sr_cards WHERE id = p_card_id;
    v_lesson_id := v_card.lesson_id;

    -- Calculate new interval using FIXED SM-2 algorithm
    SELECT * INTO v_calc_result
    FROM calculate_sr_interval(
        v_current_review.interval_days,
        v_current_review.ease_factor,
        p_quality
    );

    -- Calculate next review date
    v_next_date := NOW() + (v_calc_result.new_interval || ' days')::INTERVAL;

    -- Check if this is first time success for accurate progress tracking
    v_is_first_success := (v_current_review.card_status = 'new' AND p_quality >= 4);

    -- CRITICAL FIX: Create next review BEFORE completing current (prevents race condition)
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
            v_current_review.card_status  -- Keep same status on failure
        );
        v_next_date := NOW() + (v_calc_result.new_interval || ' days')::INTERVAL;
    END IF;

    -- NOW complete current review (after creating next one)
    UPDATE public.sr_reviews
    SET 
        completed_at = NOW(),
        quality_rating = p_quality,
        response_time_ms = p_response_time_ms
    WHERE id = v_current_review.id;

    v_review_id := v_current_review.id;

    -- FIXED PROGRESS TRACKING: Check if progress record exists
    SELECT * INTO v_progress
    FROM public.sr_progress
    WHERE student_id = p_user_id AND lesson_id = v_lesson_id;

    v_progress_exists := (v_progress.id IS NOT NULL);

    PERFORM public.log_sr_review_attempt(p_user_id, p_card_id, p_quality, p_response_time_ms, FALSE, 
        'Progress tracking - exists: ' || v_progress_exists::TEXT || ', is_first_success: ' || v_is_first_success::TEXT);

    IF NOT v_progress_exists THEN
        -- Create new progress record
        INSERT INTO public.sr_progress (
            student_id, 
            lesson_id, 
            cards_total, 
            cards_reviewed, 
            cards_learned,
            average_quality, 
            study_streak, 
            last_review_date, 
            next_review_date,
            created_at,
            updated_at
        ) VALUES (
            p_user_id, 
            v_lesson_id, 
            1, 
            1, 
            CASE WHEN v_is_first_success THEN 1 ELSE 0 END,
            p_quality, 
            1, 
            CURRENT_DATE, 
            v_next_date::DATE,
            NOW(),
            NOW()
        );
        
        PERFORM public.log_sr_review_attempt(p_user_id, p_card_id, p_quality, p_response_time_ms, FALSE, 'Created new progress record');
    ELSE
        -- Update existing progress record with EXPLICIT INCREMENTS
        UPDATE public.sr_progress
        SET
            cards_reviewed = cards_reviewed + 1,  -- Always increment reviewed count
            cards_learned = CASE 
                WHEN v_is_first_success THEN cards_learned + 1  -- Only increment learned on first-time success
                ELSE cards_learned 
            END,
            average_quality = (
                -- Recalculate average quality including this review
                (average_quality * cards_reviewed + p_quality) / 
                (cards_reviewed + 1)
            ),
            study_streak = CASE
                WHEN last_review_date = CURRENT_DATE THEN study_streak  -- Same day, keep streak
                WHEN last_review_date = CURRENT_DATE - 1 THEN study_streak + 1  -- Consecutive day, increment
                ELSE 1  -- Gap in days, reset to 1
            END,
            last_review_date = CURRENT_DATE,
            next_review_date = LEAST(COALESCE(next_review_date, v_next_date::DATE), v_next_date::DATE),
            updated_at = NOW()
        WHERE id = v_progress.id;
        
        PERFORM public.log_sr_review_attempt(p_user_id, p_card_id, p_quality, p_response_time_ms, FALSE, 
            'Updated existing progress record - old reviewed: ' || v_progress.cards_reviewed::TEXT);
    END IF;

    -- Log successful completion
    PERFORM public.log_sr_review_attempt(p_user_id, p_card_id, p_quality, p_response_time_ms, TRUE, 'Review recorded successfully with progress update');

    -- Return results
    RETURN QUERY SELECT 
        v_review_id,
        v_next_date,
        v_calc_result.new_interval,
        TRUE;

EXCEPTION WHEN OTHERS THEN
    -- Log the error
    v_error_msg := SQLERRM;
    PERFORM public.log_sr_review_attempt(p_user_id, p_card_id, p_quality, p_response_time_ms, FALSE, v_error_msg);
    
    -- Return error state
    RETURN QUERY SELECT 
        NULL::UUID,
        NULL::TIMESTAMPTZ,
        NULL::INT,
        FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to manually fix progress tracking for a student
CREATE OR REPLACE FUNCTION public.fix_student_progress(
    p_user_id UUID
) RETURNS TABLE(
    lesson_id UUID,
    lesson_name TEXT,
    old_cards_reviewed INT,
    new_cards_reviewed INT,
    old_cards_learned INT,
    new_cards_learned INT,
    status TEXT
) AS $$
DECLARE
    v_lesson RECORD;
    v_completed_count INT;
    v_learned_count INT;
    v_avg_quality DECIMAL;
BEGIN
    -- Loop through each lesson the student participates in
    FOR v_lesson IN 
        SELECT DISTINCT 
            l.id as lesson_id,
            l.name as lesson_name
        FROM public.lessons l
        INNER JOIN public.lesson_participants lp ON l.id = lp.lesson_id
        WHERE lp.student_id = p_user_id
    LOOP
        -- Count actual completed reviews for this lesson
        SELECT 
            COUNT(*) as completed,
            COUNT(CASE WHEN r.quality_rating >= 4 AND NOT EXISTS (
                SELECT 1 FROM public.sr_reviews r2
                WHERE r2.card_id = r.card_id
                  AND r2.student_id = r.student_id
                  AND r2.completed_at < r.completed_at
                  AND r2.quality_rating >= 3
            ) THEN 1 END) as learned,
            COALESCE(AVG(r.quality_rating), 0) as avg_qual
        INTO v_completed_count, v_learned_count, v_avg_quality
        FROM public.sr_reviews r
        INNER JOIN public.sr_cards c ON r.card_id = c.id
        WHERE r.student_id = p_user_id
          AND c.lesson_id = v_lesson.lesson_id
          AND r.completed_at IS NOT NULL;

        -- Update or insert progress record
        INSERT INTO public.sr_progress (
            student_id,
            lesson_id,
            cards_total,
            cards_reviewed,
            cards_learned,
            average_quality,
            study_streak,
            last_review_date,
            next_review_date
        ) VALUES (
            p_user_id,
            v_lesson.lesson_id,
            GREATEST(v_completed_count, 1),
            v_completed_count,
            v_learned_count,
            v_avg_quality,
            1,
            CURRENT_DATE,
            CURRENT_DATE + 1
        )
        ON CONFLICT (student_id, lesson_id) 
        DO UPDATE SET
            cards_reviewed = v_completed_count,
            cards_learned = v_learned_count,
            average_quality = v_avg_quality,
            updated_at = NOW();

        RETURN QUERY SELECT 
            v_lesson.lesson_id,
            v_lesson.lesson_name,
            0, -- old_cards_reviewed (we don't track this)
            v_completed_count,
            0, -- old_cards_learned
            v_learned_count,
            'FIXED'::TEXT;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.fix_student_progress(UUID) TO authenticated;

-- Add helpful comments
COMMENT ON FUNCTION public.fix_student_progress(UUID) IS
'Manually recalculate and fix progress tracking for a student based on actual completed reviews';