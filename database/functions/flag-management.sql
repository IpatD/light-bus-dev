-- =============================================================================
-- FLAG MANAGEMENT AND RESOLUTION FUNCTIONS
-- =============================================================================
-- Functions for flagging cards, resolving issues, and managing content moderation
-- =============================================================================

-- Flag a card for review
CREATE OR REPLACE FUNCTION flag_card(
    p_card_id UUID,
    p_flagged_by UUID,
    p_flag_type TEXT,
    p_description TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    flag_id UUID;
BEGIN
    INSERT INTO sr_card_flags (card_id, flagged_by, flag_type, description, created_at)
    VALUES (p_card_id, p_flagged_by, p_flag_type, p_description, NOW())
    RETURNING id INTO flag_id;
    
    RETURN flag_id;
END;
$$;

-- Resolve card flag
CREATE OR REPLACE FUNCTION resolve_card_flag(
    p_flag_id UUID,
    p_resolved_by UUID,
    p_resolution TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE sr_card_flags
    SET 
        status = 'resolved',
        resolved_by = p_resolved_by,
        resolved_at = NOW(),
        resolution = p_resolution,
        updated_at = NOW()
    WHERE id = p_flag_id;
    
    RETURN FOUND;
END;
$$;

-- Dismiss card flag
CREATE OR REPLACE FUNCTION dismiss_card_flag(
    p_flag_id UUID,
    p_resolved_by UUID,
    p_resolution TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE sr_card_flags
    SET 
        status = 'dismissed',
        resolved_by = p_resolved_by,
        resolved_at = NOW(),
        resolution = p_resolution,
        updated_at = NOW()
    WHERE id = p_flag_id;
    
    RETURN FOUND;
END;
$$;

-- Get pending flags
CREATE OR REPLACE FUNCTION get_pending_flags(
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE(
    flag_id UUID,
    card_id UUID,
    front_text TEXT,
    back_text TEXT,
    flag_type TEXT,
    description TEXT,
    flagged_by UUID,
    flagged_by_name TEXT,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        scf.id as flag_id,
        sc.id as card_id,
        sc.front_text,
        sc.back_text,
        scf.flag_type,
        scf.description,
        scf.flagged_by,
        p.full_name as flagged_by_name,
        scf.created_at
    FROM sr_card_flags scf
    JOIN sr_cards sc ON sc.id = scf.card_id
    LEFT JOIN profiles p ON p.id = scf.flagged_by
    WHERE scf.status = 'pending'
    ORDER BY scf.created_at ASC
    LIMIT p_limit OFFSET p_offset;
END;
$$;

-- Get flag statistics
CREATE OR REPLACE FUNCTION get_flag_statistics()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    stats JSON;
BEGIN
    SELECT json_build_object(
        'total_flags', COUNT(*),
        'pending_flags', COUNT(CASE WHEN status = 'pending' THEN 1 END),
        'resolved_flags', COUNT(CASE WHEN status = 'resolved' THEN 1 END),
        'dismissed_flags', COUNT(CASE WHEN status = 'dismissed' THEN 1 END),
        'flags_by_type', (
            SELECT json_object_agg(flag_type, count)
            FROM (
                SELECT flag_type, COUNT(*) as count
                FROM sr_card_flags
                GROUP BY flag_type
            ) type_counts
        ),
        'avg_resolution_time_hours', (
            SELECT ROUND(AVG(EXTRACT(EPOCH FROM (resolved_at - created_at)) / 3600), 2)
            FROM sr_card_flags
            WHERE resolved_at IS NOT NULL
        ),
        'top_flaggers', (
            SELECT json_agg(
                json_build_object(
                    'user_id', flagged_by,
                    'user_name', user_name,
                    'flag_count', flag_count
                )
            )
            FROM (
                SELECT 
                    scf.flagged_by,
                    p.full_name as user_name,
                    COUNT(*) as flag_count
                FROM sr_card_flags scf
                LEFT JOIN profiles p ON p.id = scf.flagged_by
                GROUP BY scf.flagged_by, p.full_name
                ORDER BY flag_count DESC
                LIMIT 5
            ) top_flaggers_data
        )
    )
    INTO stats
    FROM sr_card_flags;
    
    RETURN stats;
END;
$$;

-- Get flags for a specific card
CREATE OR REPLACE FUNCTION get_card_flags(p_card_id UUID)
RETURNS TABLE(
    flag_id UUID,
    flag_type TEXT,
    description TEXT,
    status TEXT,
    flagged_by UUID,
    flagged_by_name TEXT,
    resolved_by UUID,
    resolved_by_name TEXT,
    resolution TEXT,
    created_at TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        scf.id,
        scf.flag_type,
        scf.description,
        scf.status,
        scf.flagged_by,
        p1.full_name as flagged_by_name,
        scf.resolved_by,
        p2.full_name as resolved_by_name,
        scf.resolution,
        scf.created_at,
        scf.resolved_at
    FROM sr_card_flags scf
    LEFT JOIN profiles p1 ON p1.id = scf.flagged_by
    LEFT JOIN profiles p2 ON p2.id = scf.resolved_by
    WHERE scf.card_id = p_card_id
    ORDER BY scf.created_at DESC;
END;
$$;

-- Get flags by user
CREATE OR REPLACE FUNCTION get_user_flags(
    p_user_id UUID,
    p_status TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE(
    flag_id UUID,
    card_id UUID,
    front_text TEXT,
    back_text TEXT,
    flag_type TEXT,
    description TEXT,
    status TEXT,
    created_at TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        scf.id,
        sc.id,
        sc.front_text,
        sc.back_text,
        scf.flag_type,
        scf.description,
        scf.status,
        scf.created_at,
        scf.resolved_at
    FROM sr_card_flags scf
    JOIN sr_cards sc ON sc.id = scf.card_id
    WHERE scf.flagged_by = p_user_id
    AND (p_status IS NULL OR scf.status = p_status)
    ORDER BY scf.created_at DESC
    LIMIT p_limit OFFSET p_offset;
END;
$$;

-- Bulk resolve flags
CREATE OR REPLACE FUNCTION bulk_resolve_flags(
    p_flag_ids UUID[],
    p_resolved_by UUID,
    p_resolution TEXT DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    resolved_count INTEGER;
BEGIN
    UPDATE sr_card_flags
    SET 
        status = 'resolved',
        resolved_by = p_resolved_by,
        resolved_at = NOW(),
        resolution = p_resolution,
        updated_at = NOW()
    WHERE id = ANY(p_flag_ids)
    AND status = 'pending';
    
    GET DIAGNOSTICS resolved_count = ROW_COUNT;
    RETURN resolved_count;
END;
$$;

-- Bulk dismiss flags
CREATE OR REPLACE FUNCTION bulk_dismiss_flags(
    p_flag_ids UUID[],
    p_resolved_by UUID,
    p_resolution TEXT DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    dismissed_count INTEGER;
BEGIN
    UPDATE sr_card_flags
    SET 
        status = 'dismissed',
        resolved_by = p_resolved_by,
        resolved_at = NOW(),
        resolution = p_resolution,
        updated_at = NOW()
    WHERE id = ANY(p_flag_ids)
    AND status = 'pending';
    
    GET DIAGNOSTICS dismissed_count = ROW_COUNT;
    RETURN dismissed_count;
END;
$$;

-- Auto-flag cards based on patterns
CREATE OR REPLACE FUNCTION auto_flag_suspicious_cards()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    flagged_count INTEGER := 0;
    card_record RECORD;
    system_user_id UUID := '00000000-0000-0000-0000-000000000000'; -- System user for auto-flags
BEGIN
    -- Flag cards with very short content
    FOR card_record IN
        SELECT id FROM sr_cards 
        WHERE status = 'approved'
        AND (LENGTH(TRIM(front_text)) < 3 OR LENGTH(TRIM(back_text)) < 3)
        AND NOT EXISTS (
            SELECT 1 FROM sr_card_flags 
            WHERE card_id = sr_cards.id 
            AND flag_type = 'auto_short_content'
            AND status = 'pending'
        )
    LOOP
        INSERT INTO sr_card_flags (card_id, flagged_by, flag_type, description, created_at)
        VALUES (
            card_record.id, 
            system_user_id, 
            'auto_short_content', 
            'Automatically flagged: Content is too short',
            NOW()
        );
        flagged_count := flagged_count + 1;
    END LOOP;
    
    -- Flag cards with duplicate content
    FOR card_record IN
        SELECT DISTINCT sc1.id
        FROM sr_cards sc1
        JOIN sr_cards sc2 ON sc1.front_text = sc2.front_text 
                         AND sc1.back_text = sc2.back_text 
                         AND sc1.id != sc2.id
        WHERE sc1.status = 'approved'
        AND NOT EXISTS (
            SELECT 1 FROM sr_card_flags 
            WHERE card_id = sc1.id 
            AND flag_type = 'auto_duplicate'
            AND status = 'pending'
        )
    LOOP
        INSERT INTO sr_card_flags (card_id, flagged_by, flag_type, description, created_at)
        VALUES (
            card_record.id, 
            system_user_id, 
            'auto_duplicate', 
            'Automatically flagged: Duplicate content detected',
            NOW()
        );
        flagged_count := flagged_count + 1;
    END LOOP;
    
    -- Flag cards with unusual character patterns
    FOR card_record IN
        SELECT id FROM sr_cards 
        WHERE status = 'approved'
        AND (
            front_text ~ '[^\x00-\x7F]{10,}' OR  -- Many non-ASCII characters
            back_text ~ '[^\x00-\x7F]{10,}' OR
            front_text ~ '\d{10,}' OR  -- Long sequences of numbers
            back_text ~ '\d{10,}'
        )
        AND NOT EXISTS (
            SELECT 1 FROM sr_card_flags 
            WHERE card_id = sr_cards.id 
            AND flag_type = 'auto_unusual_content'
            AND status = 'pending'
        )
    LOOP
        INSERT INTO sr_card_flags (card_id, flagged_by, flag_type, description, created_at)
        VALUES (
            card_record.id, 
            system_user_id, 
            'auto_unusual_content', 
            'Automatically flagged: Unusual character patterns detected',
            NOW()
        );
        flagged_count := flagged_count + 1;
    END LOOP;
    
    RETURN flagged_count;
END;
$$;

-- Get flag trends over time
CREATE OR REPLACE FUNCTION get_flag_trends(p_days_back INTEGER DEFAULT 30)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    trends JSON;
    start_date DATE;
BEGIN
    start_date := CURRENT_DATE - p_days_back;
    
    SELECT json_build_object(
        'period_days', p_days_back,
        'daily_flags', (
            SELECT json_agg(
                json_build_object(
                    'date', flag_date,
                    'total_flags', total_flags,
                    'pending_flags', pending_flags,
                    'resolved_flags', resolved_flags
                )
            )
            FROM (
                SELECT 
                    created_at::DATE as flag_date,
                    COUNT(*) as total_flags,
                    COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_flags,
                    COUNT(CASE WHEN status = 'resolved' THEN 1 END) as resolved_flags
                FROM sr_card_flags
                WHERE created_at >= start_date
                GROUP BY created_at::DATE
                ORDER BY flag_date
            ) daily_data
        ),
        'flag_types_trend', (
            SELECT json_object_agg(flag_type, daily_counts)
            FROM (
                SELECT 
                    flag_type,
                    json_agg(
                        json_build_object(
                            'date', flag_date,
                            'count', flag_count
                        )
                        ORDER BY flag_date
                    ) as daily_counts
                FROM (
                    SELECT 
                        flag_type,
                        created_at::DATE as flag_date,
                        COUNT(*) as flag_count
                    FROM sr_card_flags
                    WHERE created_at >= start_date
                    GROUP BY flag_type, created_at::DATE
                ) type_daily
                GROUP BY flag_type
            ) type_trends
        )
    )
    INTO trends;
    
    RETURN trends;
END;
$$;