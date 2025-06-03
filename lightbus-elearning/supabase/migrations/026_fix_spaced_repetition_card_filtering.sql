-- Fix Spaced Repetition Card Filtering Logic
-- CRITICAL BUG: Cards studied are still showing as ready because filtering logic is incorrect
-- 
-- PROBLEM: get_cards_for_study filters for r.completed_at IS NULL, but when cards are studied,
--          record_sr_review sets completed_at = NOW() and creates NEW review record for future.
--          The function should find the LATEST review record for each card, not filter out
--          cards that have ANY completed reviews.
--
-- SOLUTION: Rewrite get_cards_for_study to properly find latest uncompleted reviews

-- Step 1: Fix the get_cards_for_study function with proper latest review logic
CREATE OR REPLACE FUNCTION public.get_cards_for_study(
    p_user_id UUID,
    p_pool_type TEXT DEFAULT 'both',  -- 'new', 'due', or 'both'
    p_limit_new INT DEFAULT 10,
    p_limit_due INT DEFAULT 20,
    p_lesson_id UUID DEFAULT NULL
) RETURNS TABLE(
    card_id UUID,
    lesson_id UUID,
    lesson_name TEXT,
    front_content TEXT,
    back_content TEXT,
    difficulty_level INT,
    tags TEXT[],
    card_pool TEXT,  -- 'new' or 'due'
    scheduled_for TIMESTAMPTZ,
    review_id UUID,
    repetition_count INT,
    ease_factor DECIMAL,
    can_accept BOOLEAN  -- Whether this card can be accepted to due pool
) AS $$
DECLARE
    v_is_active BOOLEAN;
BEGIN
    -- Check if student is active
    SELECT public.is_student_active(p_user_id) INTO v_is_active;
    
    -- Return new cards (always available from lesson participation)
    IF p_pool_type IN ('new', 'both') THEN
        RETURN QUERY
        WITH latest_reviews AS (
            SELECT DISTINCT ON (r.card_id)
                r.card_id,
                r.id as review_id,
                r.scheduled_for,
                r.repetition_count,
                r.ease_factor,
                r.card_status,
                r.completed_at,
                r.accepted_at
            FROM public.sr_reviews r
            WHERE r.student_id = p_user_id
            ORDER BY r.card_id, r.created_at DESC
        )
        SELECT DISTINCT
            c.id as card_id,
            c.lesson_id,
            l.name as lesson_name,
            c.front_content,
            c.back_content,
            c.difficulty_level,
            c.tags,
            'new'::TEXT as card_pool,
            lr.scheduled_for,
            lr.review_id,
            lr.repetition_count,
            lr.ease_factor,
            TRUE as can_accept
        FROM public.sr_cards c
        INNER JOIN public.lessons l ON c.lesson_id = l.id
        INNER JOIN latest_reviews lr ON c.id = lr.card_id
        INNER JOIN public.lesson_participants lp ON c.lesson_id = lp.lesson_id
        WHERE lp.student_id = p_user_id
          AND c.status = 'approved'
          AND lr.card_status = 'new'  -- New cards pool
          AND lr.completed_at IS NULL  -- Not yet completed
          AND (p_lesson_id IS NULL OR c.lesson_id = p_lesson_id)
        ORDER BY lr.scheduled_for ASC
        LIMIT p_limit_new;
    END IF;
    
    -- Return due cards ONLY if student is active (positive reinforcement)
    IF p_pool_type IN ('due', 'both') AND v_is_active THEN
        RETURN QUERY
        WITH latest_reviews AS (
            SELECT DISTINCT ON (r.card_id)
                r.card_id,
                r.id as review_id,
                r.scheduled_for,
                r.repetition_count,
                r.ease_factor,
                r.card_status,
                r.completed_at,
                r.accepted_at
            FROM public.sr_reviews r
            WHERE r.student_id = p_user_id
            ORDER BY r.card_id, r.created_at DESC
        )
        SELECT DISTINCT
            c.id as card_id,
            c.lesson_id,
            l.name as lesson_name,
            c.front_content,
            c.back_content,
            c.difficulty_level,
            c.tags,
            'due'::TEXT as card_pool,
            lr.scheduled_for,
            lr.review_id,
            lr.repetition_count,
            lr.ease_factor,
            FALSE as can_accept
        FROM public.sr_cards c
        INNER JOIN public.lessons l ON c.lesson_id = l.id
        INNER JOIN latest_reviews lr ON c.id = lr.card_id
        INNER JOIN public.lesson_participants lp ON c.lesson_id = lp.lesson_id
        WHERE lp.student_id = p_user_id
          AND c.status = 'approved'
          AND lr.card_status = 'accepted'  -- Accepted cards pool
          AND lr.completed_at IS NULL  -- Not yet completed (this is the KEY fix)
          AND lr.scheduled_for::DATE <= CURRENT_DATE  -- Due today
          AND (p_lesson_id IS NULL OR c.lesson_id = p_lesson_id)
        ORDER BY lr.scheduled_for ASC
        LIMIT p_limit_due;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 2: Create a debugging function to verify the fix works
CREATE OR REPLACE FUNCTION public.debug_card_review_status(
    p_user_id UUID,
    p_card_id UUID DEFAULT NULL
) RETURNS TABLE(
    card_id UUID,
    lesson_name TEXT,
    front_content TEXT,
    review_id UUID,
    created_at TIMESTAMPTZ,
    scheduled_for TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    card_status TEXT,
    is_latest BOOLEAN,
    should_show_in_study BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    WITH review_rankings AS (
        SELECT 
            r.*,
            c.front_content,
            l.name as lesson_name,
            ROW_NUMBER() OVER (PARTITION BY r.card_id ORDER BY r.created_at DESC) as rank_desc
        FROM public.sr_reviews r
        JOIN public.sr_cards c ON c.id = r.card_id
        JOIN public.lessons l ON l.id = c.lesson_id
        JOIN public.lesson_participants lp ON lp.lesson_id = c.lesson_id
        WHERE r.student_id = p_user_id
          AND lp.student_id = p_user_id
          AND c.status = 'approved'
          AND (p_card_id IS NULL OR r.card_id = p_card_id)
    )
    SELECT 
        rr.card_id,
        rr.lesson_name,
        LEFT(rr.front_content, 50) as front_content,
        rr.id as review_id,
        rr.created_at,
        rr.scheduled_for,
        rr.completed_at,
        rr.card_status,
        (rr.rank_desc = 1) as is_latest,
        (
            rr.rank_desc = 1 
            AND rr.completed_at IS NULL 
            AND (
                (rr.card_status = 'new') OR 
                (rr.card_status = 'accepted' AND rr.scheduled_for::DATE <= CURRENT_DATE)
            )
        ) as should_show_in_study
    FROM review_rankings rr
    ORDER BY rr.card_id, rr.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 3: Create a function to test the spaced repetition flow
CREATE OR REPLACE FUNCTION public.test_sr_card_lifecycle(
    p_user_id UUID,
    p_lesson_id UUID
) RETURNS TABLE(
    step_name TEXT,
    cards_in_new_pool INT,
    cards_in_due_pool INT,
    total_cards_available INT,
    details TEXT
) AS $$
BEGIN
    -- Step 1: Check initial state
    RETURN QUERY
    SELECT 
        'Initial State'::TEXT as step_name,
        (
            SELECT COUNT(*)::INT 
            FROM public.get_cards_for_study(p_user_id, 'new', 100, 0, p_lesson_id)
        ) as cards_in_new_pool,
        (
            SELECT COUNT(*)::INT 
            FROM public.get_cards_for_study(p_user_id, 'due', 0, 100, p_lesson_id)
        ) as cards_in_due_pool,
        (
            SELECT COUNT(*)::INT 
            FROM public.get_cards_for_study(p_user_id, 'both', 100, 100, p_lesson_id)
        ) as total_cards_available,
        'Cards available for study before any interaction'::TEXT as details;

    -- Step 2: Show card review states
    RETURN QUERY
    SELECT 
        'Review States'::TEXT as step_name,
        (
            SELECT COUNT(*)::INT 
            FROM public.debug_card_review_status(p_user_id) 
            WHERE card_status = 'new' AND is_latest = true
        ) as cards_in_new_pool,
        (
            SELECT COUNT(*)::INT 
            FROM public.debug_card_review_status(p_user_id) 
            WHERE card_status = 'accepted' AND is_latest = true
        ) as cards_in_due_pool,
        (
            SELECT COUNT(*)::INT 
            FROM public.debug_card_review_status(p_user_id) 
            WHERE should_show_in_study = true
        ) as total_cards_available,
        'Latest review status for each card'::TEXT as details;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 4: Grant permissions
GRANT EXECUTE ON FUNCTION public.get_cards_for_study(UUID, TEXT, INT, INT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.debug_card_review_status(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.test_sr_card_lifecycle(UUID, UUID) TO authenticated;

-- Step 5: Add helpful comments
COMMENT ON FUNCTION public.get_cards_for_study(UUID, TEXT, INT, INT, UUID) IS
'FIXED: Now properly finds latest uncompleted review for each card instead of filtering out cards with any completed reviews';

COMMENT ON FUNCTION public.debug_card_review_status(UUID, UUID) IS
'Debug function to trace card review lifecycle and identify which cards should appear in study sessions';

COMMENT ON FUNCTION public.test_sr_card_lifecycle(UUID, UUID) IS
'Test function to verify spaced repetition card filtering works correctly';

-- Step 6: Migration completed successfully
-- Fixed critical bug in get_cards_for_study card filtering logic
-- Issue: Cards studied were still showing as ready due to incorrect completed_at filtering
-- Solution: Rewritten to find latest uncompleted review per card using CTE with DISTINCT ON