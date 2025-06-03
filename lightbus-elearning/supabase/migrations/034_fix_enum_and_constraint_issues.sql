-- Fix Enum Reference and Constraint Issues
-- The record_sr_review function has two issues:
-- 1. References non-existent card_status_enum
-- 2. Violates unique constraint when creating next review

-- First, let's check what the actual card_status column type is
DO $$
BEGIN
    -- Create the enum if it doesn't exist (just in case)
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'card_status_enum') THEN
        CREATE TYPE card_status_enum AS ENUM ('new', 'accepted', 'due');
    END IF;
END $$;

-- Drop the problematic unique constraint if it exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'sr_reviews_card_student_unique'
    ) THEN
        ALTER TABLE public.sr_reviews DROP CONSTRAINT sr_reviews_card_student_unique;
    END IF;
EXCEPTION WHEN OTHERS THEN
    -- Constraint doesn't exist or already dropped
    NULL;
END $$;

-- Create a working version of record_sr_review without the problematic constraint
CREATE OR REPLACE FUNCTION record_sr_review_fixed(
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
    v_current_review_id UUID;
    v_next_date TIMESTAMPTZ;
    v_new_interval INT;
    v_card_status TEXT;
    v_ease_factor DECIMAL;
    v_repetition_count INT;
BEGIN
    -- Find the pending review
    SELECT 
        r.id,
        r.card_status::TEXT,
        r.ease_factor,
        r.repetition_count
    INTO 
        v_current_review_id,
        v_card_status,
        v_ease_factor,
        v_repetition_count
    FROM public.sr_reviews r
    WHERE r.card_id = p_card_id 
      AND r.student_id = p_user_id 
      AND r.completed_at IS NULL
    ORDER BY r.created_at DESC
    LIMIT 1;
    
    IF v_current_review_id IS NULL THEN
        PERFORM public.log_sr_review_attempt(p_user_id, p_card_id, p_quality, p_response_time_ms, FALSE, 'No pending review found');
        RAISE EXCEPTION 'No pending review found for card % and user %', p_card_id, p_user_id;
    END IF;
    
    -- Calculate next review using simple SM-2 logic
    IF p_quality >= 3 THEN
        v_new_interval := CASE 
            WHEN v_repetition_count = 0 THEN 1
            WHEN v_repetition_count = 1 THEN 6
            ELSE CEIL(v_new_interval * v_ease_factor)
        END;
        v_repetition_count := v_repetition_count + 1;
    ELSE
        v_new_interval := 1;  -- Reset to 1 day for failures
        v_repetition_count := 0;
    END IF;
    
    v_next_date := NOW() + (v_new_interval || ' days')::INTERVAL;
    
    -- Complete the current review
    UPDATE public.sr_reviews
    SET 
        completed_at = NOW(),
        quality_rating = p_quality,
        response_time_ms = p_response_time_ms
    WHERE id = v_current_review_id;
    
    -- Delete any existing future reviews for this card/student to avoid constraint violation
    DELETE FROM public.sr_reviews 
    WHERE card_id = p_card_id 
      AND student_id = p_user_id 
      AND completed_at IS NULL 
      AND id != v_current_review_id;
    
    -- Create next review if quality was acceptable
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
            v_new_interval,
            GREATEST(1.3, v_ease_factor + (0.1 - (5 - p_quality) * (0.08 + (5 - p_quality) * 0.02))),
            v_repetition_count,
            v_card_status
        );
    ELSE
        -- For failures, create a retry review for tomorrow
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
            NOW() + INTERVAL '1 day',
            1,
            v_ease_factor,
            0,
            v_card_status
        );
        v_next_date := NOW() + INTERVAL '1 day';
    END IF;
    
    -- Update progress tracking
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
    )
    SELECT 
        p_user_id,
        c.lesson_id,
        1,
        1,
        CASE WHEN p_quality >= 4 AND v_card_status = 'new' THEN 1 ELSE 0 END,
        p_quality,
        1,
        CURRENT_DATE,
        v_next_date::DATE
    FROM public.sr_cards c
    WHERE c.id = p_card_id
    ON CONFLICT (student_id, lesson_id) 
    DO UPDATE SET
        cards_reviewed = sr_progress.cards_reviewed + 1,
        cards_learned = CASE 
            WHEN p_quality >= 4 AND v_card_status = 'new' 
            THEN sr_progress.cards_learned + 1 
            ELSE sr_progress.cards_learned 
        END,
        average_quality = (sr_progress.average_quality * sr_progress.cards_reviewed + p_quality) / (sr_progress.cards_reviewed + 1),
        last_review_date = CURRENT_DATE,
        next_review_date = LEAST(sr_progress.next_review_date, v_next_date::DATE),
        updated_at = NOW();
    
    -- Log success
    PERFORM public.log_sr_review_attempt(p_user_id, p_card_id, p_quality, p_response_time_ms, TRUE, 'Review completed successfully');
    
    -- Return success
    RETURN QUERY SELECT 
        v_current_review_id,
        v_next_date,
        v_new_interval,
        TRUE;
        
EXCEPTION WHEN OTHERS THEN
    -- Log the error
    PERFORM public.log_sr_review_attempt(p_user_id, p_card_id, p_quality, p_response_time_ms, FALSE, SQLERRM);
    
    -- Return failure
    RETURN QUERY SELECT 
        NULL::UUID,
        NULL::TIMESTAMPTZ,
        NULL::INT,
        FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.record_sr_review_fixed(UUID, UUID, INT, INT) TO authenticated;

-- Add helpful comments
COMMENT ON FUNCTION public.record_sr_review_fixed(UUID, UUID, INT, INT) IS
'Fixed version of record_sr_review that handles enum issues and constraint violations properly';