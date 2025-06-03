-- Add card deletion functionality for teachers
-- Allows teachers to safely delete cards they created

-- Step 1: Create function to delete a card and cleanup related data
CREATE OR REPLACE FUNCTION public.delete_sr_card(
    p_card_id UUID
) RETURNS TABLE(
    success BOOLEAN,
    error TEXT,
    message TEXT
) AS $$
DECLARE
    v_teacher_id UUID;
    v_card_exists BOOLEAN;
    v_lesson_id UUID;
    v_card_creator UUID;
    v_affected_reviews INT;
BEGIN
    -- Get current user ID
    SELECT auth.uid() INTO v_teacher_id;
    
    IF v_teacher_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Authentication required'::TEXT, NULL::TEXT;
        RETURN;
    END IF;
    
    -- Check if card exists and get details
    SELECT EXISTS(
        SELECT 1 FROM public.sr_cards WHERE id = p_card_id
    ), lesson_id, created_by
    INTO v_card_exists, v_lesson_id, v_card_creator
    FROM public.sr_cards 
    WHERE id = p_card_id;
    
    IF NOT v_card_exists THEN
        RETURN QUERY SELECT FALSE, 'Card not found'::TEXT, NULL::TEXT;
        RETURN;
    END IF;
    
    -- Verify the user is the creator of the card OR owns the lesson
    IF v_card_creator != v_teacher_id THEN
        -- Check if user owns the lesson (teachers can delete any cards in their lessons)
        IF NOT EXISTS(
            SELECT 1 FROM public.lessons 
            WHERE id = v_lesson_id AND teacher_id = v_teacher_id
        ) THEN
            RETURN QUERY SELECT FALSE, 'Access denied. You can only delete cards you created or from lessons you own'::TEXT, NULL::TEXT;
            RETURN;
        END IF;
    END IF;
    
    -- Count affected reviews for reporting
    SELECT COUNT(*) INTO v_affected_reviews
    FROM public.sr_reviews
    WHERE card_id = p_card_id;
    
    -- Delete related sr_reviews first (cascade cleanup)
    DELETE FROM public.sr_reviews WHERE card_id = p_card_id;
    
    -- Delete the card
    DELETE FROM public.sr_cards WHERE id = p_card_id;
    
    -- Return success with information
    RETURN QUERY SELECT 
        TRUE,
        NULL::TEXT,
        format('Card deleted successfully. Removed %s student review records.', v_affected_reviews);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 2: Grant permissions
GRANT EXECUTE ON FUNCTION public.delete_sr_card(UUID) TO authenticated;

-- Step 3: Add comments
COMMENT ON FUNCTION public.delete_sr_card(UUID) IS
'Safely deletes a flashcard and all related review data. Only card creators or lesson owners can delete cards.';