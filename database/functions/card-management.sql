-- =============================================================================
-- CARD CREATION AND MODERATION FUNCTIONS
-- =============================================================================
-- Functions for creating, approving, rejecting, and managing spaced repetition cards
-- =============================================================================

-- Create new spaced repetition card
CREATE OR REPLACE FUNCTION create_sr_card(
    p_front_text TEXT,
    p_back_text TEXT,
    p_lesson_id UUID DEFAULT NULL,
    p_created_by UUID DEFAULT NULL,
    p_tags TEXT[] DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    card_id UUID;
BEGIN
    INSERT INTO sr_cards (front_text, back_text, lesson_id, created_by, tags, created_at, updated_at)
    VALUES (p_front_text, p_back_text, p_lesson_id, p_created_by, p_tags, NOW(), NOW())
    RETURNING id INTO card_id;
    
    RETURN card_id;
END;
$$;

-- Approve spaced repetition card
CREATE OR REPLACE FUNCTION approve_sr_card(
    p_card_id UUID,
    p_approved_by UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE sr_cards
    SET 
        status = 'approved',
        approved_by = p_approved_by,
        approved_at = NOW(),
        updated_at = NOW()
    WHERE id = p_card_id;
    
    RETURN FOUND;
END;
$$;

-- Reject spaced repetition card
CREATE OR REPLACE FUNCTION reject_sr_card(
    p_card_id UUID,
    p_rejected_by UUID,
    p_rejection_reason TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE sr_cards
    SET 
        status = 'rejected',
        approved_by = p_rejected_by,
        approved_at = NOW(),
        updated_at = NOW()
    WHERE id = p_card_id;
    
    -- Log rejection reason if provided
    IF p_rejection_reason IS NOT NULL THEN
        INSERT INTO sr_card_flags (card_id, flagged_by, flag_type, description, created_at)
        VALUES (p_card_id, p_rejected_by, 'rejection', p_rejection_reason, NOW());
    END IF;
    
    RETURN FOUND;
END;
$$;

-- Update spaced repetition card
CREATE OR REPLACE FUNCTION update_sr_card(
    p_card_id UUID,
    p_front_text TEXT DEFAULT NULL,
    p_back_text TEXT DEFAULT NULL,
    p_tags TEXT[] DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE sr_cards
    SET 
        front_text = COALESCE(p_front_text, front_text),
        back_text = COALESCE(p_back_text, back_text),
        tags = COALESCE(p_tags, tags),
        updated_at = NOW()
    WHERE id = p_card_id;
    
    RETURN FOUND;
END;
$$;

-- Get cards for moderation
CREATE OR REPLACE FUNCTION get_cards_for_moderation(
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE(
    id UUID,
    front_text TEXT,
    back_text TEXT,
    lesson_id UUID,
    created_by UUID,
    tags TEXT[],
    status TEXT,
    created_at TIMESTAMPTZ,
    creator_name TEXT
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
        sc.lesson_id,
        sc.created_by,
        sc.tags,
        sc.status,
        sc.created_at,
        p.full_name as creator_name
    FROM sr_cards sc
    LEFT JOIN profiles p ON p.id = sc.created_by
    WHERE sc.status = 'pending'
    ORDER BY sc.created_at ASC
    LIMIT p_limit OFFSET p_offset;
END;
$$;

-- Search cards
CREATE OR REPLACE FUNCTION search_cards(
    p_search_term TEXT,
    p_user_id UUID DEFAULT NULL,
    p_lesson_id UUID DEFAULT NULL,
    p_tags TEXT[] DEFAULT NULL,
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE(
    id UUID,
    front_text TEXT,
    back_text TEXT,
    lesson_id UUID,
    tags TEXT[],
    status TEXT,
    created_at TIMESTAMPTZ
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
        sc.lesson_id,
        sc.tags,
        sc.status,
        sc.created_at
    FROM sr_cards sc
    WHERE sc.status = 'approved'
    AND (p_search_term IS NULL OR 
         sc.front_text ILIKE '%' || p_search_term || '%' OR 
         sc.back_text ILIKE '%' || p_search_term || '%')
    AND (p_lesson_id IS NULL OR sc.lesson_id = p_lesson_id)
    AND (p_tags IS NULL OR sc.tags && p_tags)
    ORDER BY sc.created_at DESC
    LIMIT p_limit OFFSET p_offset;
END;
$$;

-- Get card details with metadata
CREATE OR REPLACE FUNCTION get_card_details(p_card_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    card_data JSON;
BEGIN
    SELECT json_build_object(
        'card', row_to_json(sc),
        'creator', (
            SELECT json_build_object('id', p.id, 'name', p.full_name, 'email', p.email)
            FROM profiles p WHERE p.id = sc.created_by
        ),
        'lesson', (
            SELECT json_build_object('id', l.id, 'title', l.title)
            FROM lessons l WHERE l.id = sc.lesson_id
        ),
        'review_stats', (
            SELECT json_build_object(
                'total_reviews', COUNT(sr.id),
                'avg_quality', ROUND(AVG(sr.quality), 2),
                'last_reviewed', MAX(sr.reviewed_at),
                'users_studying', COUNT(DISTINCT sp.user_id)
            )
            FROM sr_reviews sr
            LEFT JOIN sr_progress sp ON sp.card_id = sr.card_id
            WHERE sr.card_id = sc.id
        ),
        'flags', COALESCE(
            (SELECT json_agg(
                json_build_object(
                    'id', scf.id,
                    'flag_type', scf.flag_type,
                    'description', scf.description,
                    'status', scf.status,
                    'created_at', scf.created_at,
                    'flagged_by', (
                        SELECT p.full_name FROM profiles p WHERE p.id = scf.flagged_by
                    )
                )
            )
            FROM sr_card_flags scf
            WHERE scf.card_id = sc.id), '[]'::json
        )
    )
    INTO card_data
    FROM sr_cards sc
    WHERE sc.id = p_card_id;
    
    RETURN card_data;
END;
$$;

-- Duplicate card detection
CREATE OR REPLACE FUNCTION find_duplicate_cards(
    p_front_text TEXT,
    p_back_text TEXT,
    p_lesson_id UUID DEFAULT NULL
)
RETURNS TABLE(
    card_id UUID,
    front_text TEXT,
    back_text TEXT,
    similarity_score DECIMAL
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
        -- Simple similarity calculation based on text similarity
        CASE 
            WHEN sc.front_text = p_front_text AND sc.back_text = p_back_text THEN 1.0
            WHEN sc.front_text = p_front_text OR sc.back_text = p_back_text THEN 0.8
            WHEN similarity(sc.front_text, p_front_text) > 0.7 AND similarity(sc.back_text, p_back_text) > 0.7 THEN 0.7
            WHEN similarity(sc.front_text, p_front_text) > 0.6 OR similarity(sc.back_text, p_back_text) > 0.6 THEN 0.6
            ELSE 0.0
        END as similarity_score
    FROM sr_cards sc
    WHERE sc.status = 'approved'
    AND (p_lesson_id IS NULL OR sc.lesson_id = p_lesson_id)
    AND (
        sc.front_text = p_front_text OR 
        sc.back_text = p_back_text OR
        similarity(sc.front_text, p_front_text) > 0.5 OR
        similarity(sc.back_text, p_back_text) > 0.5
    )
    ORDER BY similarity_score DESC;
END;
$$;

-- Batch approve cards
CREATE OR REPLACE FUNCTION batch_approve_cards(
    p_card_ids UUID[],
    p_approved_by UUID
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    approved_count INTEGER;
BEGIN
    UPDATE sr_cards
    SET 
        status = 'approved',
        approved_by = p_approved_by,
        approved_at = NOW(),
        updated_at = NOW()
    WHERE id = ANY(p_card_ids)
    AND status = 'pending';
    
    GET DIAGNOSTICS approved_count = ROW_COUNT;
    RETURN approved_count;
END;
$$;

-- Batch reject cards
CREATE OR REPLACE FUNCTION batch_reject_cards(
    p_card_ids UUID[],
    p_rejected_by UUID,
    p_rejection_reason TEXT DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    rejected_count INTEGER;
    card_id UUID;
BEGIN
    UPDATE sr_cards
    SET 
        status = 'rejected',
        approved_by = p_rejected_by,
        approved_at = NOW(),
        updated_at = NOW()
    WHERE id = ANY(p_card_ids)
    AND status = 'pending';
    
    GET DIAGNOSTICS rejected_count = ROW_COUNT;
    
    -- Log rejection reasons if provided
    IF p_rejection_reason IS NOT NULL AND rejected_count > 0 THEN
        FOREACH card_id IN ARRAY p_card_ids
        LOOP
            INSERT INTO sr_card_flags (card_id, flagged_by, flag_type, description, created_at)
            VALUES (card_id, p_rejected_by, 'rejection', p_rejection_reason, NOW())
            ON CONFLICT DO NOTHING;
        END LOOP;
    END IF;
    
    RETURN rejected_count;
END;
$$;

-- Get card usage statistics
CREATE OR REPLACE FUNCTION get_card_usage_stats(p_card_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    stats JSON;
BEGIN
    SELECT json_build_object(
        'total_users', COUNT(DISTINCT sp.user_id),
        'total_reviews', COUNT(sr.id),
        'avg_quality', ROUND(AVG(sr.quality), 2),
        'avg_response_time', ROUND(AVG(sr.response_time_ms), 0),
        'mastery_rate', ROUND(
            COUNT(DISTINCT CASE WHEN sp.interval_days >= 21 THEN sp.user_id END)::DECIMAL / 
            NULLIF(COUNT(DISTINCT sp.user_id), 0) * 100, 2
        ),
        'difficulty_distribution', (
            SELECT json_build_object(
                'new', COUNT(CASE WHEN sp.review_count = 0 THEN 1 END),
                'learning', COUNT(CASE WHEN sp.interval_days > 0 AND sp.interval_days < 21 THEN 1 END),
                'mastered', COUNT(CASE WHEN sp.interval_days >= 21 THEN 1 END)
            )
            FROM sr_progress sp
            WHERE sp.card_id = p_card_id
        )
    )
    INTO stats
    FROM sr_progress sp
    LEFT JOIN sr_reviews sr ON sr.card_id = sp.card_id AND sr.user_id = sp.user_id
    WHERE sp.card_id = p_card_id;
    
    RETURN stats;
END;
$$;

-- Validate card content
CREATE OR REPLACE FUNCTION validate_card_content(
    p_front_text TEXT,
    p_back_text TEXT
)
RETURNS JSON
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    validation JSON;
    errors TEXT[] := '{}';
BEGIN
    -- Check for empty content
    IF p_front_text IS NULL OR LENGTH(TRIM(p_front_text)) = 0 THEN
        errors := array_append(errors, 'Front text cannot be empty');
    END IF;
    
    IF p_back_text IS NULL OR LENGTH(TRIM(p_back_text)) = 0 THEN
        errors := array_append(errors, 'Back text cannot be empty');
    END IF;
    
    -- Check length limits
    IF LENGTH(p_front_text) > 1000 THEN
        errors := array_append(errors, 'Front text too long (max 1000 characters)');
    END IF;
    
    IF LENGTH(p_back_text) > 2000 THEN
        errors := array_append(errors, 'Back text too long (max 2000 characters)');
    END IF;
    
    -- Build validation result
    SELECT json_build_object(
        'valid', array_length(errors, 1) IS NULL,
        'errors', errors
    ) INTO validation;
    
    RETURN validation;
END;
$$;