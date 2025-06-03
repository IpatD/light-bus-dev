-- Debug Spaced Repetition Review Recording
-- Add logging and verification functions to troubleshoot review recording issues

-- Function to verify card and review state before recording
CREATE OR REPLACE FUNCTION public.debug_sr_review_state(
    p_user_id UUID,
    p_card_id UUID
) RETURNS TABLE(
    card_exists BOOLEAN,
    card_status TEXT,
    latest_review_id UUID,
    latest_review_completed BOOLEAN,
    latest_review_scheduled TIMESTAMPTZ,
    can_record_review BOOLEAN,
    error_message TEXT
) AS $$
DECLARE
    v_card_record RECORD;
    v_review_record RECORD;
    v_is_participant BOOLEAN;
BEGIN
    -- Check if card exists
    SELECT INTO v_card_record
        c.id, c.status, c.lesson_id
    FROM public.sr_cards c
    WHERE c.id = p_card_id;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT 
            FALSE, 'not_found'::TEXT, NULL::UUID, NULL::BOOLEAN, 
            NULL::TIMESTAMPTZ, FALSE, 'Card not found'::TEXT;
        RETURN;
    END IF;
    
    -- Check if user is lesson participant
    SELECT INTO v_is_participant
        CASE WHEN COUNT(*) > 0 THEN TRUE ELSE FALSE END
    FROM public.lesson_participants lp
    WHERE lp.lesson_id = v_card_record.lesson_id 
      AND lp.student_id = p_user_id;
    
    IF NOT v_is_participant THEN
        RETURN QUERY SELECT 
            TRUE, v_card_record.status::TEXT, NULL::UUID, NULL::BOOLEAN,
            NULL::TIMESTAMPTZ, FALSE, 'User not participant in lesson'::TEXT;
        RETURN;
    END IF;
    
    -- Get latest review for this card
    SELECT INTO v_review_record
        r.id, r.completed_at, r.scheduled_for, r.card_status
    FROM public.sr_reviews r
    WHERE r.card_id = p_card_id 
      AND r.student_id = p_user_id
    ORDER BY r.created_at DESC, r.id DESC
    LIMIT 1;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT 
            TRUE, v_card_record.status::TEXT, NULL::UUID, NULL::BOOLEAN,
            NULL::TIMESTAMPTZ, FALSE, 'No review record found for card'::TEXT;
        RETURN;
    END IF;
    
    -- Check if review can be recorded
    RETURN QUERY SELECT 
        TRUE,
        v_card_record.status::TEXT,
        v_review_record.id,
        (v_review_record.completed_at IS NOT NULL),
        v_review_record.scheduled_for,
        (v_review_record.completed_at IS NULL AND v_card_record.status = 'approved'),
        CASE 
            WHEN v_review_record.completed_at IS NOT NULL THEN 'Review already completed'
            WHEN v_card_record.status != 'approved' THEN 'Card not approved'
            ELSE 'Ready for review'
        END::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to log review recording attempts
CREATE OR REPLACE FUNCTION public.log_sr_review_attempt(
    p_user_id UUID,
    p_card_id UUID,
    p_quality INT,
    p_response_time_ms INT,
    p_success BOOLEAN,
    p_error_message TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    -- Insert log entry (we'll create a simple log table if needed)
    INSERT INTO public.sr_review_logs (
        student_id,
        card_id,
        quality_rating,
        response_time_ms,
        success,
        error_message,
        attempted_at
    ) VALUES (
        p_user_id,
        p_card_id,
        p_quality,
        p_response_time_ms,
        p_success,
        p_error_message,
        NOW()
    );
EXCEPTION WHEN OTHERS THEN
    -- Silently fail if logging fails
    NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create log table for review attempts
CREATE TABLE IF NOT EXISTS public.sr_review_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    card_id UUID REFERENCES public.sr_cards(id) ON DELETE CASCADE,
    quality_rating INT,
    response_time_ms INT,
    success BOOLEAN,
    error_message TEXT,
    attempted_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enhanced record_sr_review function with logging
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

    -- Calculate new interval using FIXED SM-2 algorithm
    SELECT * INTO v_calc_result
    FROM calculate_sr_interval(
        v_current_review.interval_days,
        v_current_review.ease_factor,
        p_quality
    );

    -- Calculate next review date
    v_next_date := NOW() + (v_calc_result.new_interval || ' days')::INTERVAL;

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

    -- Update progress tracking
    SELECT * INTO v_card FROM public.sr_cards WHERE id = p_card_id;
    v_lesson_id := v_card.lesson_id;

    -- Get or create progress record
    SELECT * INTO v_progress
    FROM public.sr_progress
    WHERE student_id = p_user_id AND lesson_id = v_lesson_id;

    IF v_progress.id IS NULL THEN
        INSERT INTO public.sr_progress (
            student_id, lesson_id, cards_total, cards_reviewed, cards_learned,
            average_quality, study_streak, last_review_date, next_review_date
        ) VALUES (
            p_user_id, v_lesson_id, 1, 1, CASE WHEN v_is_first_success THEN 1 ELSE 0 END,
            p_quality, 1, CURRENT_DATE, v_next_date::DATE
        );
    ELSE
        -- Update existing progress with FIXED tracking
        UPDATE public.sr_progress
        SET
            cards_reviewed = cards_reviewed + 1,
            cards_learned = CASE 
                WHEN v_is_first_success THEN cards_learned + 1  -- Only count first-time successes
                ELSE cards_learned 
            END,
            average_quality = (
                (average_quality * (cards_reviewed - 1) + p_quality) / 
                GREATEST(cards_reviewed, 1.0)
            ),
            study_streak = CASE
                WHEN last_review_date = CURRENT_DATE THEN study_streak
                WHEN last_review_date = CURRENT_DATE - 1 THEN study_streak + 1
                ELSE 1
            END,
            last_review_date = CURRENT_DATE,
            next_review_date = LEAST(next_review_date, v_next_date::DATE),
            updated_at = NOW()
        WHERE id = v_progress.id;
    END IF;

    -- Log successful completion
    PERFORM public.log_sr_review_attempt(p_user_id, p_card_id, p_quality, p_response_time_ms, TRUE, 'Review recorded successfully');

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

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.debug_sr_review_state(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_sr_review_attempt(UUID, UUID, INT, INT, BOOLEAN, TEXT) TO authenticated;
GRANT SELECT ON TABLE public.sr_review_logs TO authenticated;

-- Add helpful comments
COMMENT ON FUNCTION public.debug_sr_review_state(UUID, UUID) IS
'Debug function to verify card and review state before attempting to record a review';

COMMENT ON FUNCTION public.log_sr_review_attempt(UUID, UUID, INT, INT, BOOLEAN, TEXT) IS
'Log function to track all review recording attempts for debugging purposes';

COMMENT ON TABLE public.sr_review_logs IS
'Log table for tracking spaced repetition review recording attempts and failures';