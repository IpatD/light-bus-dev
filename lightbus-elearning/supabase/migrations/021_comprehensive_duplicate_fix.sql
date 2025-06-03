-- COMPREHENSIVE FIX: Complete duplicate card initialization resolution
-- PROBLEM: Multiple triggers creating duplicate sr_reviews records causing students to see cards twice
-- SOLUTION: Complete cleanup and single-point initialization

-- Step 1: Drop ALL existing triggers that might create duplicates
DROP TRIGGER IF EXISTS trigger_auto_create_reviews ON public.sr_cards;
DROP TRIGGER IF EXISTS trigger_new_card_initialization ON public.sr_cards;
DROP TRIGGER IF EXISTS trigger_card_status_change ON public.sr_cards;

-- Step 2: Drop conflicting functions
DROP FUNCTION IF EXISTS public.auto_create_reviews_for_new_cards();

-- Step 3: Create a single, robust initialization function with duplicate prevention
CREATE OR REPLACE FUNCTION public.initialize_card_for_students()
RETURNS TRIGGER AS $$
DECLARE
    v_student RECORD;
    v_existing_count INTEGER;
BEGIN
    -- Only process if card is approved (either new or status changed to approved)
    IF NEW.status = 'approved' AND (
        TG_OP = 'INSERT' OR 
        (TG_OP = 'UPDATE' AND (OLD.status IS NULL OR OLD.status != 'approved'))
    ) THEN
        
        -- Create initial review records for all students enrolled in this lesson
        FOR v_student IN 
            SELECT DISTINCT student_id 
            FROM public.lesson_participants 
            WHERE lesson_id = NEW.lesson_id
        LOOP
            -- Double-check no review exists (extra safety)
            SELECT COUNT(*) INTO v_existing_count
            FROM public.sr_reviews 
            WHERE card_id = NEW.id AND student_id = v_student.student_id;
            
            -- Only create if absolutely no review exists
            IF v_existing_count = 0 THEN
                INSERT INTO public.sr_reviews (
                    card_id, student_id, scheduled_for, 
                    interval_days, ease_factor, repetition_count
                ) VALUES (
                    NEW.id, v_student.student_id, NOW(),
                    1, 2.5, 0
                );
            END IF;
        END LOOP;
        
        -- Update sr_progress cards_total count for existing progress records
        UPDATE public.sr_progress 
        SET 
            cards_total = (
                SELECT COUNT(*) 
                FROM public.sr_cards 
                WHERE lesson_id = NEW.lesson_id AND status = 'approved'
            ),
            updated_at = NOW()
        WHERE lesson_id = NEW.lesson_id;
        
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 4: Create single trigger for both INSERT and UPDATE
CREATE TRIGGER trigger_initialize_card_for_students
    AFTER INSERT OR UPDATE OF status ON public.sr_cards
    FOR EACH ROW
    EXECUTE FUNCTION public.initialize_card_for_students();

-- Step 5: Clean up existing duplicate sr_reviews records
-- Keep only the earliest review for each card-student pair
WITH duplicate_reviews AS (
    SELECT 
        id,
        ROW_NUMBER() OVER (
            PARTITION BY card_id, student_id 
            ORDER BY created_at ASC, id ASC
        ) as rn
    FROM public.sr_reviews
    WHERE completed_at IS NULL  -- Only clean up uncompleted reviews
)
DELETE FROM public.sr_reviews 
WHERE id IN (
    SELECT id FROM duplicate_reviews WHERE rn > 1
);

-- Step 6: Add unique constraint to prevent future duplicates
DO $$
BEGIN
    -- Check if constraint already exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'sr_reviews_card_student_uncompleted_unique'
        AND table_name = 'sr_reviews'
    ) THEN
        -- Create partial unique constraint for uncompleted reviews only
        CREATE UNIQUE INDEX sr_reviews_card_student_uncompleted_unique 
        ON public.sr_reviews (card_id, student_id) 
        WHERE completed_at IS NULL;
    END IF;
END $$;

-- Step 7: Update initialize_new_card_for_students function to be extra safe
CREATE OR REPLACE FUNCTION public.initialize_new_card_for_students(
    p_card_id UUID
) RETURNS BOOLEAN AS $$
DECLARE
    v_lesson_id UUID;
    v_student RECORD;
    v_count INTEGER;
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
        SELECT DISTINCT student_id 
        FROM public.lesson_participants 
        WHERE lesson_id = v_lesson_id
    LOOP
        -- Check if any uncompleted review already exists for this card and student
        SELECT COUNT(*) INTO v_count
        FROM public.sr_reviews 
        WHERE card_id = p_card_id 
          AND student_id = v_student.student_id 
          AND completed_at IS NULL;
        
        -- Only create if no uncompleted review exists
        IF v_count = 0 THEN
            BEGIN
                INSERT INTO public.sr_reviews (
                    card_id, student_id, scheduled_for, 
                    interval_days, ease_factor, repetition_count
                ) VALUES (
                    p_card_id, v_student.student_id, NOW(),
                    1, 2.5, 0
                );
            EXCEPTION 
                WHEN unique_violation THEN
                    -- Ignore if duplicate somehow gets through
                    CONTINUE;
            END;
        END IF;
    END LOOP;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 8: Update create_sr_card function for safety
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
    
    -- The trigger will automatically and safely initialize this card for all enrolled students
    
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

-- Step 9: Add comprehensive cleanup for sr_progress duplicates as well
-- Remove duplicate sr_progress records (if any)
WITH duplicate_progress AS (
    SELECT 
        id,
        ROW_NUMBER() OVER (
            PARTITION BY student_id, lesson_id 
            ORDER BY created_at ASC, id ASC
        ) as rn
    FROM public.sr_progress
)
DELETE FROM public.sr_progress 
WHERE id IN (
    SELECT id FROM duplicate_progress WHERE rn > 1
);

-- Add unique constraint for sr_progress if not exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'sr_progress_student_lesson_unique'
        AND table_name = 'sr_progress'
    ) THEN
        ALTER TABLE public.sr_progress 
        ADD CONSTRAINT sr_progress_student_lesson_unique 
        UNIQUE (student_id, lesson_id);
    END IF;
END $$;

-- Step 10: Grant permissions
GRANT EXECUTE ON FUNCTION public.initialize_card_for_students() TO authenticated;
GRANT EXECUTE ON FUNCTION public.initialize_new_card_for_students(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_sr_card(UUID, TEXT, TEXT, TEXT, INT, TEXT[]) TO authenticated;

-- Step 11: Add documentation
COMMENT ON FUNCTION public.initialize_card_for_students() IS
'Single trigger function for initializing approved cards for students - prevents duplicates';

COMMENT ON FUNCTION public.initialize_new_card_for_students(UUID) IS
'Manual card initialization function with duplicate prevention - safe to call multiple times';

-- Step 12: Verify data integrity
-- Count and log any remaining issues for monitoring
DO $$
DECLARE
    v_duplicate_reviews INTEGER;
    v_duplicate_progress INTEGER;
BEGIN
    -- Check for remaining duplicate reviews
    SELECT COUNT(*) INTO v_duplicate_reviews
    FROM (
        SELECT card_id, student_id, COUNT(*) as cnt
        FROM public.sr_reviews
        WHERE completed_at IS NULL
        GROUP BY card_id, student_id
        HAVING COUNT(*) > 1
    ) duplicates;
    
    -- Check for remaining duplicate progress
    SELECT COUNT(*) INTO v_duplicate_progress
    FROM (
        SELECT student_id, lesson_id, COUNT(*) as cnt
        FROM public.sr_progress
        GROUP BY student_id, lesson_id
        HAVING COUNT(*) > 1
    ) duplicates;
    
    -- Log results (these should be 0 after this migration)
    RAISE NOTICE 'Duplicate card initialization fix complete. Remaining duplicate reviews: %, Remaining duplicate progress: %', 
        v_duplicate_reviews, v_duplicate_progress;
END $$;