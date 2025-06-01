-- =============================================================================
-- SPACED REPETITION ALGORITHM FUNCTIONS
-- =============================================================================
-- Functions implementing the SM-2 spaced repetition algorithm and review logic
-- =============================================================================

-- Calculate next review interval using SM-2 algorithm
CREATE OR REPLACE FUNCTION calculate_sr_interval(
    p_current_interval INTEGER,
    p_easiness_factor DECIMAL,
    p_quality INTEGER
)
RETURNS TABLE(
    next_interval INTEGER,
    new_easiness_factor DECIMAL
)
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    new_ef DECIMAL;
    new_interval INTEGER;
BEGIN
    -- Update easiness factor
    new_ef := p_easiness_factor + (0.1 - (5 - p_quality) * (0.08 + (5 - p_quality) * 0.02));
    
    -- Ensure EF doesn't go below 1.3
    IF new_ef < 1.3 THEN
        new_ef := 1.3;
    END IF;
    
    -- Calculate next interval
    IF p_quality < 3 THEN
        -- Reset to 1 day if quality is poor
        new_interval := 1;
    ELSE
        IF p_current_interval = 0 THEN
            new_interval := 1;
        ELSIF p_current_interval = 1 THEN
            new_interval := 6;
        ELSE
            new_interval := CEIL(p_current_interval * new_ef);
        END IF;
    END IF;
    
    RETURN QUERY SELECT new_interval, new_ef;
END;
$$;

-- Record spaced repetition review
CREATE OR REPLACE FUNCTION record_sr_review(
    p_user_id UUID,
    p_card_id UUID,
    p_quality INTEGER,
    p_response_time INTEGER DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_progress RECORD;
    sr_result RECORD;
    next_interval INTEGER;
    new_ef DECIMAL;
BEGIN
    -- Get current progress
    SELECT * INTO current_progress
    FROM sr_progress
    WHERE user_id = p_user_id AND card_id = p_card_id;
    
    -- If no progress exists, create initial record
    IF NOT FOUND THEN
        INSERT INTO sr_progress (user_id, card_id, interval_days, easiness_factor, next_review, review_count)
        VALUES (p_user_id, p_card_id, 0, 2.5, NOW(), 0);
        
        SELECT * INTO current_progress
        FROM sr_progress
        WHERE user_id = p_user_id AND card_id = p_card_id;
    END IF;
    
    -- Calculate new interval and easiness factor
    SELECT * INTO sr_result
    FROM calculate_sr_interval(current_progress.interval_days, current_progress.easiness_factor, p_quality);
    
    next_interval := sr_result.next_interval;
    new_ef := sr_result.new_easiness_factor;
    
    -- Update progress
    UPDATE sr_progress
    SET
        interval_days = next_interval,
        easiness_factor = new_ef,
        next_review = NOW() + (next_interval || ' days')::INTERVAL,
        review_count = review_count + 1,
        last_review = NOW(),
        updated_at = NOW()
    WHERE user_id = p_user_id AND card_id = p_card_id;
    
    -- Record the review
    INSERT INTO sr_reviews (user_id, card_id, quality, response_time_ms, reviewed_at)
    VALUES (p_user_id, p_card_id, p_quality, p_response_time, NOW());
    
    RETURN TRUE;
END;
$$;

-- Get cards due for review
CREATE OR REPLACE FUNCTION get_cards_due(
    p_user_id UUID,
    p_limit INTEGER DEFAULT 20
)
RETURNS TABLE(
    card_id UUID,
    front_text TEXT,
    back_text TEXT,
    next_review TIMESTAMPTZ,
    interval_days INTEGER,
    review_count INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sc.id,
        sc.front_text,
        sc.back_text,
        sp.next_review,
        sp.interval_days,
        sp.review_count
    FROM sr_cards sc
    JOIN sr_progress sp ON sp.card_id = sc.id
    WHERE sp.user_id = p_user_id
    AND sp.next_review <= NOW()
    AND sc.status = 'approved'
    ORDER BY sp.next_review ASC
    LIMIT p_limit;
END;
$$;

-- Get user's spaced repetition statistics
CREATE OR REPLACE FUNCTION get_sr_statistics(p_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    stats JSON;
BEGIN
    SELECT json_build_object(
        'total_cards', COUNT(DISTINCT sp.card_id),
        'cards_due', COUNT(DISTINCT CASE WHEN sp.next_review <= NOW() THEN sp.card_id END),
        'cards_learning', COUNT(DISTINCT CASE WHEN sp.interval_days < 21 THEN sp.card_id END),
        'cards_mastered', COUNT(DISTINCT CASE WHEN sp.interval_days >= 21 THEN sp.card_id END),
        'total_reviews', COUNT(sr.id),
        'avg_quality', ROUND(AVG(sr.quality), 2),
        'streak_days', get_user_study_streak(p_user_id)
    )
    INTO stats
    FROM sr_progress sp
    LEFT JOIN sr_reviews sr ON sr.user_id = sp.user_id AND sr.card_id = sp.card_id
    WHERE sp.user_id = p_user_id;
    
    RETURN stats;
END;
$$;

-- Get cards by difficulty level
CREATE OR REPLACE FUNCTION get_cards_by_difficulty(
    p_user_id UUID,
    p_difficulty TEXT -- 'new', 'learning', 'review', 'mastered'
)
RETURNS TABLE(
    card_id UUID,
    front_text TEXT,
    back_text TEXT,
    interval_days INTEGER,
    easiness_factor DECIMAL,
    next_review TIMESTAMPTZ,
    review_count INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sc.id,
        sc.front_text,
        sc.back_text,
        sp.interval_days,
        sp.easiness_factor,
        sp.next_review,
        sp.review_count
    FROM sr_cards sc
    LEFT JOIN sr_progress sp ON sp.card_id = sc.id AND sp.user_id = p_user_id
    WHERE sc.status = 'approved'
    AND CASE 
        WHEN p_difficulty = 'new' THEN sp.card_id IS NULL OR sp.review_count = 0
        WHEN p_difficulty = 'learning' THEN sp.interval_days > 0 AND sp.interval_days < 21
        WHEN p_difficulty = 'review' THEN sp.next_review <= NOW() AND sp.interval_days >= 1
        WHEN p_difficulty = 'mastered' THEN sp.interval_days >= 21
        ELSE FALSE
    END
    ORDER BY 
        CASE WHEN p_difficulty = 'review' THEN sp.next_review END ASC,
        sc.created_at DESC;
END;
$$;

-- Get review history for a card
CREATE OR REPLACE FUNCTION get_card_review_history(
    p_user_id UUID,
    p_card_id UUID
)
RETURNS TABLE(
    review_id UUID,
    quality INTEGER,
    response_time_ms INTEGER,
    reviewed_at TIMESTAMPTZ,
    interval_before INTEGER,
    interval_after INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sr.id,
        sr.quality,
        sr.response_time_ms,
        sr.reviewed_at,
        LAG(sp.interval_days) OVER (ORDER BY sr.reviewed_at) as interval_before,
        sp.interval_days as interval_after
    FROM sr_reviews sr
    LEFT JOIN sr_progress sp ON sp.user_id = sr.user_id AND sp.card_id = sr.card_id
    WHERE sr.user_id = p_user_id AND sr.card_id = p_card_id
    ORDER BY sr.reviewed_at DESC;
END;
$$;

-- Reset card progress (for re-learning)
CREATE OR REPLACE FUNCTION reset_card_progress(
    p_user_id UUID,
    p_card_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE sr_progress
    SET 
        interval_days = 0,
        easiness_factor = 2.5,
        next_review = NOW(),
        review_count = 0,
        last_review = NULL,
        updated_at = NOW()
    WHERE user_id = p_user_id AND card_id = p_card_id;
    
    RETURN FOUND;
END;
$$;

-- Bulk update card intervals (for algorithm adjustments)
CREATE OR REPLACE FUNCTION bulk_update_intervals(
    p_user_id UUID,
    p_multiplier DECIMAL DEFAULT 1.0
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    updated_count INTEGER;
BEGIN
    UPDATE sr_progress
    SET 
        interval_days = GREATEST(1, FLOOR(interval_days * p_multiplier)),
        next_review = NOW() + (GREATEST(1, FLOOR(interval_days * p_multiplier)) || ' days')::INTERVAL,
        updated_at = NOW()
    WHERE user_id = p_user_id
    AND interval_days > 0;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RETURN updated_count;
END;
$$;

-- Get optimal study session
CREATE OR REPLACE FUNCTION get_optimal_study_session(
    p_user_id UUID,
    p_session_size INTEGER DEFAULT 20
)
RETURNS TABLE(
    card_id UUID,
    front_text TEXT,
    back_text TEXT,
    priority_score DECIMAL,
    card_type TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH card_priorities AS (
        SELECT 
            sc.id,
            sc.front_text,
            sc.back_text,
            CASE 
                WHEN sp.card_id IS NULL THEN 100 -- New cards get highest priority
                WHEN sp.next_review <= NOW() - INTERVAL '1 day' THEN 90 -- Overdue cards
                WHEN sp.next_review <= NOW() THEN 80 -- Due cards
                WHEN sp.interval_days < 7 THEN 70 -- Learning cards
                ELSE 50 -- Review cards
            END + 
            CASE 
                WHEN sp.easiness_factor < 2.0 THEN 20 -- Difficult cards get bonus
                WHEN sp.easiness_factor > 3.0 THEN -10 -- Easy cards get penalty
                ELSE 0
            END as priority_score,
            CASE 
                WHEN sp.card_id IS NULL THEN 'new'
                WHEN sp.next_review <= NOW() THEN 'due'
                WHEN sp.interval_days < 21 THEN 'learning'
                ELSE 'review'
            END as card_type
        FROM sr_cards sc
        LEFT JOIN sr_progress sp ON sp.card_id = sc.id AND sp.user_id = p_user_id
        WHERE sc.status = 'approved'
        AND (sp.card_id IS NULL OR sp.next_review <= NOW() + INTERVAL '1 day')
    )
    SELECT cp.id, cp.front_text, cp.back_text, cp.priority_score, cp.card_type
    FROM card_priorities cp
    ORDER BY cp.priority_score DESC, RANDOM()
    LIMIT p_session_size;
END;
$$;