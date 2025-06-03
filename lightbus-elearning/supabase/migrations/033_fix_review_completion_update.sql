-- Fix Review Completion Update Issue
-- The record_sr_review function is finding reviews but failing to complete them

-- Test function to manually complete a review and see what fails
CREATE OR REPLACE FUNCTION public.test_complete_review(
    p_user_id UUID,
    p_card_id UUID,
    p_quality INT,
    p_response_time_ms INT
) RETURNS TABLE(
    step_name TEXT,
    success BOOLEAN,
    message TEXT,
    data JSONB
) AS $$
DECLARE
    v_review_id UUID;
    v_current_review public.sr_reviews%ROWTYPE;
    v_rows_updated INT;
BEGIN
    -- Step 1: Find the pending review
    BEGIN
        SELECT * INTO v_current_review
        FROM public.sr_reviews
        WHERE card_id = p_card_id 
          AND student_id = p_user_id 
          AND completed_at IS NULL
        ORDER BY created_at DESC, id DESC
        LIMIT 1;
        
        IF v_current_review.id IS NULL THEN
            RETURN QUERY SELECT 
                'Find Pending Review'::TEXT, 
                FALSE, 
                'No pending review found'::TEXT,
                jsonb_build_object('card_id', p_card_id, 'user_id', p_user_id);
            RETURN;
        END IF;
        
        RETURN QUERY SELECT 
            'Find Pending Review'::TEXT, 
            TRUE, 
            'Found pending review'::TEXT,
            jsonb_build_object(
                'review_id', v_current_review.id,
                'scheduled_for', v_current_review.scheduled_for,
                'card_status', v_current_review.card_status
            );
    EXCEPTION WHEN OTHERS THEN
        RETURN QUERY SELECT 
            'Find Pending Review'::TEXT, 
            FALSE, 
            SQLERRM::TEXT,
            jsonb_build_object('error', 'Exception during review lookup');
        RETURN;
    END;
    
    -- Step 2: Try to update the review
    BEGIN
        UPDATE public.sr_reviews
        SET 
            completed_at = NOW(),
            quality_rating = p_quality,
            response_time_ms = p_response_time_ms
        WHERE id = v_current_review.id;
        
        GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
        
        RETURN QUERY SELECT 
            'Update Review'::TEXT, 
            (v_rows_updated > 0), 
            CASE 
                WHEN v_rows_updated > 0 THEN 'Review updated successfully'
                ELSE 'No rows updated'
            END::TEXT,
            jsonb_build_object(
                'rows_updated', v_rows_updated,
                'review_id', v_current_review.id
            );
    EXCEPTION WHEN OTHERS THEN
        RETURN QUERY SELECT 
            'Update Review'::TEXT, 
            FALSE, 
            SQLERRM::TEXT,
            jsonb_build_object('error', 'Exception during review update');
        RETURN;
    END;
    
    -- Step 3: Try to create next review
    BEGIN
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
            2.5,
            1,
            v_current_review.card_status
        );
        
        RETURN QUERY SELECT 
            'Create Next Review'::TEXT, 
            TRUE, 
            'Next review created'::TEXT,
            jsonb_build_object('next_scheduled', NOW() + INTERVAL '1 day');
    EXCEPTION WHEN OTHERS THEN
        RETURN QUERY SELECT 
            'Create Next Review'::TEXT, 
            FALSE, 
            SQLERRM::TEXT,
            jsonb_build_object('error', 'Exception during next review creation');
        RETURN;
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Simplified record_sr_review function that focuses on core functionality
CREATE OR REPLACE FUNCTION record_sr_review_simple(
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
BEGIN
    -- Find the pending review
    SELECT id INTO v_current_review_id
    FROM public.sr_reviews
    WHERE card_id = p_card_id 
      AND student_id = p_user_id 
      AND completed_at IS NULL
    ORDER BY created_at DESC
    LIMIT 1;
    
    IF v_current_review_id IS NULL THEN
        RAISE EXCEPTION 'No pending review found for card % and user %', p_card_id, p_user_id;
    END IF;
    
    -- Calculate next review (simple 1-day interval for now)
    v_new_interval := CASE 
        WHEN p_quality >= 3 THEN 1
        ELSE 0  -- Same day retry
    END;
    
    v_next_date := NOW() + (v_new_interval || ' days')::INTERVAL;
    
    -- Complete the current review
    UPDATE public.sr_reviews
    SET 
        completed_at = NOW(),
        quality_rating = p_quality,
        response_time_ms = p_response_time_ms
    WHERE id = v_current_review_id;
    
    -- Create next review if quality was good
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
            2.5,
            1,
            'accepted'
        );
    END IF;
    
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
GRANT EXECUTE ON FUNCTION public.test_complete_review(UUID, UUID, INT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_sr_review_simple(UUID, UUID, INT, INT) TO authenticated;

-- Add helpful comments
COMMENT ON FUNCTION public.test_complete_review(UUID, UUID, INT, INT) IS
'Test function to debug exactly what step is failing in review completion';

COMMENT ON FUNCTION public.record_sr_review_simple(UUID, UUID, INT, INT) IS
'Simplified version of record_sr_review focused on core functionality without complex logic';