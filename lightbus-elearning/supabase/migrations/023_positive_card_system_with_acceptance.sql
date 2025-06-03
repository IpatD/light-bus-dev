-- Positive Reinforcement Card System with Student Acceptance
-- Features:
-- 1. Lesson participation always adds cards to "new" pool
-- 2. Student must accept new cards to move them to "due" pool  
-- 3. Inactivity only freezes existing due cards, not new lesson cards
-- 4. No negative "overdue" indicators

-- Step 1: Add card acceptance tracking to sr_reviews
ALTER TABLE public.sr_reviews 
ADD COLUMN IF NOT EXISTS card_status TEXT DEFAULT 'new' CHECK (card_status IN ('new', 'accepted', 'due')),
ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMPTZ DEFAULT NULL;

-- Step 2: Add activity tracking to sr_progress
ALTER TABLE public.sr_progress 
ADD COLUMN IF NOT EXISTS last_activity_date DATE DEFAULT CURRENT_DATE,
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS frozen_since DATE DEFAULT NULL;

-- Step 3: Create function to check if student is active (studied within last week)
CREATE OR REPLACE FUNCTION public.is_student_active(p_student_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_last_activity DATE;
BEGIN
    -- Get the most recent study activity across all lessons
    SELECT MAX(last_review_date) INTO v_last_activity
    FROM public.sr_progress
    WHERE student_id = p_student_id;
    
    -- If no activity found, consider active (new student)
    IF v_last_activity IS NULL THEN
        RETURN TRUE;
    END IF;
    
    -- Active if studied within last 7 days
    RETURN v_last_activity >= CURRENT_DATE - INTERVAL '7 days';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 4: Function to accept new cards (move them to due pool)
CREATE OR REPLACE FUNCTION public.accept_new_cards(
    p_student_id UUID,
    p_card_ids UUID[] DEFAULT NULL,  -- If NULL, accept all new cards
    p_lesson_id UUID DEFAULT NULL    -- If provided, accept only from this lesson
) RETURNS TABLE(
    accepted_count INT,
    success BOOLEAN,
    message TEXT
) AS $$
DECLARE
    v_accepted_count INT := 0;
    v_card_id UUID;
BEGIN
    -- If specific cards provided, accept those
    IF p_card_ids IS NOT NULL THEN
        FOR v_card_id IN SELECT unnest(p_card_ids) LOOP
            UPDATE public.sr_reviews
            SET 
                card_status = 'accepted',
                accepted_at = NOW(),
                scheduled_for = NOW()  -- Make available for study immediately
            WHERE student_id = p_student_id
              AND card_id = v_card_id
              AND card_status = 'new';
            
            v_accepted_count := v_accepted_count + 1;
        END LOOP;
    ELSE
        -- Accept all new cards (optionally filtered by lesson)
        UPDATE public.sr_reviews
        SET 
            card_status = 'accepted',
            accepted_at = NOW(),
            scheduled_for = NOW()
        WHERE student_id = p_student_id
          AND card_status = 'new'
          AND (p_lesson_id IS NULL OR card_id IN (
              SELECT id FROM public.sr_cards WHERE lesson_id = p_lesson_id
          ));
        
        GET DIAGNOSTICS v_accepted_count = ROW_COUNT;
    END IF;
    
    RETURN QUERY SELECT 
        v_accepted_count,
        TRUE,
        format('Successfully accepted %s new cards', v_accepted_count);
        
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT 
        0,
        FALSE,
        'Error accepting cards: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 5: Get cards for study with separate pools
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
        SELECT DISTINCT ON (c.id)
            c.id as card_id,
            c.lesson_id,
            l.name as lesson_name,
            c.front_content,
            c.back_content,
            c.difficulty_level,
            c.tags,
            'new'::TEXT as card_pool,
            r.scheduled_for,
            r.id as review_id,
            r.repetition_count,
            r.ease_factor,
            TRUE as can_accept
        FROM public.sr_cards c
        INNER JOIN public.lessons l ON c.lesson_id = l.id
        INNER JOIN public.sr_reviews r ON c.id = r.card_id
        INNER JOIN public.lesson_participants lp ON c.lesson_id = lp.lesson_id
        WHERE r.student_id = p_user_id
          AND lp.student_id = p_user_id
          AND c.status = 'approved'
          AND r.card_status = 'new'  -- New cards pool
          AND r.completed_at IS NULL
          AND (p_lesson_id IS NULL OR c.lesson_id = p_lesson_id)
        ORDER BY c.id, r.created_at ASC
        LIMIT p_limit_new;
    END IF;
    
    -- Return due cards ONLY if student is active (positive reinforcement)
    IF p_pool_type IN ('due', 'both') AND v_is_active THEN
        RETURN QUERY
        SELECT DISTINCT ON (c.id)
            c.id as card_id,
            c.lesson_id,
            l.name as lesson_name,
            c.front_content,
            c.back_content,
            c.difficulty_level,
            c.tags,
            'due'::TEXT as card_pool,
            r.scheduled_for,
            r.id as review_id,
            r.repetition_count,
            r.ease_factor,
            FALSE as can_accept
        FROM public.sr_cards c
        INNER JOIN public.lessons l ON c.lesson_id = l.id
        INNER JOIN public.sr_reviews r ON c.id = r.card_id
        INNER JOIN public.lesson_participants lp ON c.lesson_id = lp.lesson_id
        WHERE r.student_id = p_user_id
          AND lp.student_id = p_user_id
          AND c.status = 'approved'
          AND r.card_status = 'accepted'  -- Accepted cards pool
          AND r.completed_at IS NULL
          AND r.scheduled_for::DATE <= CURRENT_DATE  -- Due today (no "overdue")
          AND (p_lesson_id IS NULL OR c.lesson_id = p_lesson_id)
        ORDER BY c.id, r.scheduled_for ASC
        LIMIT p_limit_due;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 6: Update card initialization - always start as "new" for lesson participation
CREATE OR REPLACE FUNCTION public.initialize_card_for_students()
RETURNS TRIGGER AS $$
DECLARE
    v_student RECORD;
    v_existing_count INTEGER;
BEGIN
    -- Only process if card is approved
    IF NEW.status = 'approved' AND (
        TG_OP = 'INSERT' OR 
        (TG_OP = 'UPDATE' AND (OLD.status IS NULL OR OLD.status != 'approved'))
    ) THEN
        
        -- Create initial review records for ALL students enrolled in lesson
        -- Regardless of their study activity - lesson participation adds to "new" pool
        FOR v_student IN 
            SELECT DISTINCT student_id 
            FROM public.lesson_participants 
            WHERE lesson_id = NEW.lesson_id
        LOOP
            -- Double-check no review exists
            SELECT COUNT(*) INTO v_existing_count
            FROM public.sr_reviews 
            WHERE card_id = NEW.id AND student_id = v_student.student_id;
            
            -- Only create if no review exists
            IF v_existing_count = 0 THEN
                -- Always start as "new" card from lesson participation
                INSERT INTO public.sr_reviews (
                    card_id, student_id, scheduled_for, 
                    interval_days, ease_factor, repetition_count,
                    card_status, accepted_at
                ) VALUES (
                    NEW.id, v_student.student_id, NOW(),
                    1, 2.5, 0,
                    'new', NULL  -- New card, not yet accepted
                );
            END IF;
        END LOOP;
        
        -- Update sr_progress cards_total count
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

-- Step 7: Update record_sr_review to handle card status transitions
CREATE OR REPLACE FUNCTION public.record_sr_review(
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
BEGIN
    -- Get the current review
    SELECT * INTO v_current_review
    FROM public.sr_reviews
    WHERE card_id = p_card_id 
      AND student_id = p_user_id 
      AND completed_at IS NULL
      AND card_status IN ('new', 'accepted')  -- Can review new or accepted cards
    ORDER BY scheduled_for ASC
    LIMIT 1;

    IF v_current_review.id IS NULL THEN
        RETURN QUERY SELECT NULL::UUID, NULL::TIMESTAMPTZ, NULL::INT, FALSE;
        RETURN;
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

    -- Update current review with completion data
    UPDATE public.sr_reviews
    SET 
        completed_at = NOW(),
        quality_rating = p_quality,
        response_time_ms = p_response_time_ms
    WHERE id = v_current_review.id;

    v_review_id := v_current_review.id;

    -- Create next review record (unless quality was too low)
    IF p_quality >= 3 THEN
        INSERT INTO public.sr_reviews (
            card_id,
            student_id,
            scheduled_for,
            interval_days,
            ease_factor,
            repetition_count,
            card_status,
            accepted_at
        ) VALUES (
            p_card_id,
            p_user_id,
            v_next_date,
            v_calc_result.new_interval,
            v_calc_result.new_easiness_factor,
            v_calc_result.new_repetition_count,
            CASE 
                WHEN v_current_review.card_status = 'new' THEN 'accepted'  -- First successful review accepts the card
                ELSE 'accepted'  -- Keep as accepted
            END,
            CASE 
                WHEN v_current_review.card_status = 'new' THEN NOW()  -- Mark acceptance time
                ELSE v_current_review.accepted_at  -- Keep existing acceptance time
            END
        );
    ELSE
        -- For low quality ratings, schedule immediate re-review
        INSERT INTO public.sr_reviews (
            card_id,
            student_id,
            scheduled_for,
            interval_days,
            ease_factor,
            repetition_count,
            card_status,
            accepted_at
        ) VALUES (
            p_card_id,
            p_user_id,
            NOW() + '10 minutes'::INTERVAL,
            1,
            v_current_review.ease_factor,
            0,
            v_current_review.card_status,  -- Keep same status
            v_current_review.accepted_at   -- Keep same acceptance time
        );
        v_next_date := NOW() + '10 minutes'::INTERVAL;
    END IF;

    -- Update progress tracking
    SELECT * INTO v_card FROM public.sr_cards WHERE id = p_card_id;
    v_lesson_id := v_card.lesson_id;

    -- Update sr_progress with activity tracking
    UPDATE public.sr_progress
    SET
        cards_reviewed = cards_reviewed + 1,
        cards_learned = CASE 
            WHEN p_quality >= 4 THEN cards_learned + 1 
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
        last_activity_date = CURRENT_DATE,
        is_active = TRUE,
        frozen_since = NULL,  -- Unfreeze when active
        next_review_date = LEAST(next_review_date, v_next_date::DATE),
        updated_at = NOW()
    WHERE student_id = p_user_id AND lesson_id = v_lesson_id;

    -- Return results
    RETURN QUERY SELECT 
        v_review_id,
        v_next_date,
        v_calc_result.new_interval,
        TRUE;

EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT 
        NULL::UUID,
        NULL::TIMESTAMPTZ,
        NULL::INT,
        FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 8: Function to get student dashboard stats with new system
CREATE OR REPLACE FUNCTION public.get_student_dashboard_stats(
    p_user_id UUID
) RETURNS TABLE(
    new_cards_count INT,
    due_cards_count INT,
    total_reviews BIGINT,
    study_streak INT,
    cards_learned BIGINT,
    is_active BOOLEAN,
    next_new_cards_available BOOLEAN
) AS $$
DECLARE
    v_is_active BOOLEAN;
    v_stats RECORD;
BEGIN
    -- Check if student is active
    SELECT public.is_student_active(p_user_id) INTO v_is_active;
    
    -- Get comprehensive stats
    SELECT
        -- New cards count (from lesson participation)
        COUNT(CASE WHEN r.card_status = 'new' AND r.completed_at IS NULL THEN 1 END)::INT as new_count,
        
        -- Due cards count (only if active)
        CASE WHEN v_is_active THEN
            COUNT(CASE WHEN r.card_status = 'accepted' AND r.completed_at IS NULL 
                      AND r.scheduled_for::DATE <= CURRENT_DATE THEN 1 END)::INT
        ELSE 0 END as due_count,
        
        -- Total reviews completed
        COUNT(CASE WHEN r.completed_at IS NOT NULL THEN 1 END) as total_reviews,
        
        -- Study streak and cards learned
        COALESCE(MAX(p.study_streak), 0) as max_streak,
        COALESCE(SUM(p.cards_learned), 0) as learned_cards
    INTO v_stats
    FROM public.lesson_participants lp
    LEFT JOIN public.sr_reviews r ON r.student_id = lp.student_id
    LEFT JOIN public.sr_cards c ON r.card_id = c.id AND c.lesson_id = lp.lesson_id
    LEFT JOIN public.sr_progress p ON p.student_id = lp.student_id AND p.lesson_id = lp.lesson_id
    WHERE lp.student_id = p_user_id
      AND c.status = 'approved';
    
    RETURN QUERY SELECT
        v_stats.new_count,
        v_stats.due_count,
        v_stats.total_reviews,
        v_stats.max_streak,
        v_stats.learned_cards,
        v_is_active,
        v_stats.new_count > 0;  -- New cards available to accept
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 9: Update existing data to new system
UPDATE public.sr_reviews 
SET card_status = CASE 
    WHEN repetition_count = 0 THEN 'new'
    ELSE 'accepted'
END,
accepted_at = CASE 
    WHEN repetition_count > 0 THEN created_at
    ELSE NULL
END
WHERE card_status IS NULL;

-- Step 10: Grant permissions
GRANT EXECUTE ON FUNCTION public.is_student_active(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.accept_new_cards(UUID, UUID[], UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_cards_for_study(UUID, TEXT, INT, INT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_sr_review(UUID, UUID, INT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_student_dashboard_stats(UUID) TO authenticated;

-- Step 11: Add helpful comments
COMMENT ON FUNCTION public.accept_new_cards(UUID, UUID[], UUID) IS
'Allows students to accept new cards and move them to their due pool for study';

COMMENT ON FUNCTION public.get_cards_for_study(UUID, TEXT, INT, INT, UUID) IS
'Returns cards separated into new and due pools with positive reinforcement logic';

COMMENT ON COLUMN public.sr_reviews.card_status IS
'Card status: new (from lesson participation), accepted (student accepted for study)';