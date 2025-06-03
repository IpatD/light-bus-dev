-- Fix duplicate card initialization issue
-- PROBLEM: Students see new cards twice - once "on time" and once "overdue"
-- CAUSE: Trigger fires on both INSERT and UPDATE, potential duplicate creation

-- Step 1: Fix the trigger to only fire on INSERT when status is approved
DROP TRIGGER IF EXISTS trigger_new_card_initialization ON public.sr_cards;

CREATE OR REPLACE FUNCTION public.trigger_initialize_card_for_students()
RETURNS TRIGGER AS $$
BEGIN
    -- Only initialize if this is a new card being created with approved status
    -- OR if status is being changed from non-approved to approved
    IF TG_OP = 'INSERT' AND NEW.status = 'approved' THEN
        PERFORM public.initialize_new_card_for_students(NEW.id);
    ELSIF TG_OP = 'UPDATE' AND NEW.status = 'approved' AND 
          (OLD.status IS NULL OR OLD.status != 'approved') THEN
        PERFORM public.initialize_new_card_for_students(NEW.id);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger only on INSERT (not UPDATE to prevent duplicates)
CREATE TRIGGER trigger_new_card_initialization
    AFTER INSERT ON public.sr_cards
    FOR EACH ROW
    EXECUTE FUNCTION public.trigger_initialize_card_for_students();

-- Also create a separate trigger for updates only when status changes
CREATE TRIGGER trigger_card_status_change
    AFTER UPDATE OF status ON public.sr_cards
    FOR EACH ROW
    WHEN (NEW.status = 'approved' AND OLD.status != 'approved')
    EXECUTE FUNCTION public.trigger_initialize_card_for_students();

-- Step 2: Clean up any duplicate sr_reviews entries
-- Remove duplicate entries keeping only the earliest one for each card-student pair
DELETE FROM public.sr_reviews sr1
WHERE EXISTS (
    SELECT 1 FROM public.sr_reviews sr2
    WHERE sr2.card_id = sr1.card_id
      AND sr2.student_id = sr1.student_id
      AND sr2.created_at < sr1.created_at
);

-- Step 3: Update the initialize function to be more robust
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
        SELECT student_id 
        FROM public.lesson_participants 
        WHERE lesson_id = v_lesson_id
    LOOP
        -- Check if any review already exists for this card and student
        SELECT COUNT(*) INTO v_count
        FROM public.sr_reviews 
        WHERE card_id = p_card_id AND student_id = v_student.student_id;
        
        -- Only create if no review exists
        IF v_count = 0 THEN
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

-- Step 4: Add unique constraint to prevent future duplicates
-- First check if constraint already exists
DO $$
BEGIN
    -- Add unique constraint on card_id + student_id if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'sr_reviews_card_student_unique'
        AND table_name = 'sr_reviews'
    ) THEN
        ALTER TABLE public.sr_reviews 
        ADD CONSTRAINT sr_reviews_card_student_unique 
        UNIQUE (card_id, student_id);
    END IF;
END $$;

-- Step 5: Grant permissions
GRANT EXECUTE ON FUNCTION public.initialize_new_card_for_students(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.trigger_initialize_card_for_students() TO authenticated;

-- Step 6: Add helpful comment
COMMENT ON FUNCTION public.trigger_initialize_card_for_students() IS
'Trigger function that automatically initializes new approved cards for enrolled students - prevents duplicates';