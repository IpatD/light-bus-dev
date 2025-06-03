-- Fix new cards initialization for existing students
-- PROBLEM: When teachers create new cards, they don't appear for existing students
-- SOLUTION: Automatically create initial sr_reviews entries when cards are created

-- Step 1: Create function to initialize new cards for all enrolled students
CREATE OR REPLACE FUNCTION public.initialize_new_card_for_students(
    p_card_id UUID
) RETURNS BOOLEAN AS $$
DECLARE
    v_lesson_id UUID;
    v_student RECORD;
BEGIN
    -- Get the lesson_id for this card
    SELECT lesson_id INTO v_lesson_id
    FROM public.sr_cards
    WHERE id = p_card_id AND status = 'approved';
    
    -- If card not found or not approved, return false
    IF v_lesson_id IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Create initial review records for all students enrolled in this lesson
    FOR v_student IN 
        SELECT student_id 
        FROM public.lesson_participants 
        WHERE lesson_id = v_lesson_id
    LOOP
        -- Only create if no review exists for this card and student
        IF NOT EXISTS(
            SELECT 1 FROM public.sr_reviews 
            WHERE card_id = p_card_id AND student_id = v_student.student_id
        ) THEN
            INSERT INTO public.sr_reviews (
                card_id, student_id, scheduled_for, 
                interval_days, ease_factor, repetition_count
            ) VALUES (
                p_card_id, v_student.student_id, NOW(),
                1, 2.5, 0
            );
        END IF;
    END LOOP;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 2: Create function to trigger initialization when card is approved
CREATE OR REPLACE FUNCTION public.trigger_initialize_card_for_students()
RETURNS TRIGGER AS $$
BEGIN
    -- Only initialize if card is being set to approved status
    IF NEW.status = 'approved' AND (OLD.status IS NULL OR OLD.status != 'approved') THEN
        PERFORM public.initialize_new_card_for_students(NEW.id);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 3: Create trigger on sr_cards table
DROP TRIGGER IF EXISTS trigger_new_card_initialization ON public.sr_cards;

CREATE TRIGGER trigger_new_card_initialization
    AFTER INSERT OR UPDATE ON public.sr_cards
    FOR EACH ROW
    EXECUTE FUNCTION public.trigger_initialize_card_for_students();

-- Step 4: Update the create_sr_card function to ensure proper initialization
-- First drop the existing function to avoid return type conflicts
DROP FUNCTION IF EXISTS public.create_sr_card(UUID, TEXT, TEXT, TEXT, INT, TEXT[]);

CREATE OR REPLACE FUNCTION public.create_sr_card(
    p_lesson_id UUID,
    p_front_content TEXT,
    p_back_content TEXT,
    p_card_type TEXT DEFAULT 'basic',
    p_difficulty_level INT DEFAULT 2,
    p_tags TEXT[] DEFAULT ARRAY[]::TEXT[]
) RETURNS TABLE(
    success BOOLEAN,
    error TEXT,
    data JSON
) AS $$
DECLARE
    v_card_id UUID;
    v_teacher_id UUID;
    v_lesson_exists BOOLEAN;
BEGIN
    -- Get current user ID
    SELECT auth.uid() INTO v_teacher_id;
    
    IF v_teacher_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Authentication required'::TEXT, NULL::JSON;
        RETURN;
    END IF;
    
    -- Verify lesson exists and user is the teacher
    SELECT EXISTS(
        SELECT 1 FROM public.lessons 
        WHERE id = p_lesson_id AND teacher_id = v_teacher_id
    ) INTO v_lesson_exists;
    
    IF NOT v_lesson_exists THEN
        RETURN QUERY SELECT FALSE, 'Lesson not found or access denied'::TEXT, NULL::JSON;
        RETURN;
    END IF;
    
    -- Validate input
    IF p_front_content IS NULL OR LENGTH(TRIM(p_front_content)) < 3 THEN
        RETURN QUERY SELECT FALSE, 'Front content must be at least 3 characters'::TEXT, NULL::JSON;
        RETURN;
    END IF;
    
    IF p_back_content IS NULL OR LENGTH(TRIM(p_back_content)) < 3 THEN
        RETURN QUERY SELECT FALSE, 'Back content must be at least 3 characters'::TEXT, NULL::JSON;
        RETURN;
    END IF;
    
    IF p_difficulty_level < 1 OR p_difficulty_level > 5 THEN
        RETURN QUERY SELECT FALSE, 'Difficulty level must be between 1 and 5'::TEXT, NULL::JSON;
        RETURN;
    END IF;
    
    -- Create the card (approved by default for teachers)
    INSERT INTO public.sr_cards (
        lesson_id,
        front_content,
        back_content,
        card_type,
        difficulty_level,
        tags,
        status,
        created_by
    ) VALUES (
        p_lesson_id,
        TRIM(p_front_content),
        TRIM(p_back_content),
        p_card_type,
        p_difficulty_level,
        p_tags,
        'approved', -- Teachers' cards are auto-approved
        v_teacher_id
    ) RETURNING id INTO v_card_id;
    
    -- The trigger will automatically initialize this card for all enrolled students
    
    RETURN QUERY SELECT 
        TRUE,
        NULL::TEXT,
        json_build_object(
            'id', v_card_id,
            'lesson_id', p_lesson_id,
            'front_content', TRIM(p_front_content),
            'back_content', TRIM(p_back_content),
            'card_type', p_card_type,
            'difficulty_level', p_difficulty_level,
            'tags', p_tags,
            'status', 'approved'
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 5: Initialize any existing approved cards that don't have review records
-- This fixes existing cards that students should be able to study
DO $$
DECLARE
    v_card RECORD;
    v_student RECORD;
BEGIN
    -- Loop through all approved cards
    FOR v_card IN 
        SELECT c.id as card_id, c.lesson_id
        FROM public.sr_cards c
        WHERE c.status = 'approved'
    LOOP
        -- Loop through all students enrolled in this lesson
        FOR v_student IN 
            SELECT lp.student_id
            FROM public.lesson_participants lp
            WHERE lp.lesson_id = v_card.lesson_id
        LOOP
            -- Create initial review record if it doesn't exist
            IF NOT EXISTS(
                SELECT 1 FROM public.sr_reviews 
                WHERE card_id = v_card.card_id AND student_id = v_student.student_id
            ) THEN
                INSERT INTO public.sr_reviews (
                    card_id, student_id, scheduled_for, 
                    interval_days, ease_factor, repetition_count
                ) VALUES (
                    v_card.card_id, v_student.student_id, NOW(),
                    1, 2.5, 0
                );
            END IF;
        END LOOP;
    END LOOP;
END $$;

-- Step 6: Grant permissions
GRANT EXECUTE ON FUNCTION public.initialize_new_card_for_students(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.trigger_initialize_card_for_students() TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_sr_card(UUID, TEXT, TEXT, TEXT, INT, TEXT[]) TO authenticated;

-- Step 7: Add helpful comments
COMMENT ON FUNCTION public.initialize_new_card_for_students(UUID) IS
'Creates initial sr_reviews entries for a new card for all students enrolled in the lesson';

COMMENT ON FUNCTION public.trigger_initialize_card_for_students() IS
'Trigger function that automatically initializes new approved cards for all enrolled students';

COMMENT ON FUNCTION public.create_sr_card(UUID, TEXT, TEXT, TEXT, INT, TEXT[]) IS
'Creates a new flashcard and automatically makes it available to all enrolled students';