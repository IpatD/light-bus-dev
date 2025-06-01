-- =============================================================================
-- USER MANAGEMENT AND AUTHENTICATION FUNCTIONS
-- =============================================================================
-- Functions for user profile management, authentication, and user statistics
-- =============================================================================

-- Create or update user profile
CREATE OR REPLACE FUNCTION create_user_profile(
    p_user_id UUID,
    p_email TEXT,
    p_full_name TEXT DEFAULT NULL,
    p_avatar_url TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO profiles (id, email, full_name, avatar_url, created_at, updated_at)
    VALUES (p_user_id, p_email, p_full_name, p_avatar_url, NOW(), NOW())
    ON CONFLICT (id) 
    DO UPDATE SET
        email = EXCLUDED.email,
        full_name = EXCLUDED.full_name,
        avatar_url = EXCLUDED.avatar_url,
        updated_at = NOW();
END;
$$;

-- Get user profile by ID
CREATE OR REPLACE FUNCTION get_user_profile(p_user_id UUID)
RETURNS TABLE(
    id UUID,
    email TEXT,
    full_name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT p.id, p.email, p.full_name, p.avatar_url, p.created_at, p.updated_at
    FROM profiles p
    WHERE p.id = p_user_id;
END;
$$;

-- Update user profile
CREATE OR REPLACE FUNCTION update_user_profile(
    p_user_id UUID,
    p_full_name TEXT DEFAULT NULL,
    p_avatar_url TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE profiles 
    SET 
        full_name = COALESCE(p_full_name, full_name),
        avatar_url = COALESCE(p_avatar_url, avatar_url),
        updated_at = NOW()
    WHERE id = p_user_id;
    
    RETURN FOUND;
END;
$$;

-- Check if user is teacher
CREATE OR REPLACE FUNCTION is_user_teacher(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    teacher_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO teacher_count
    FROM lesson_participants lp
    WHERE lp.user_id = p_user_id 
    AND lp.role = 'teacher';
    
    RETURN teacher_count > 0;
END;
$$;

-- Get user statistics
CREATE OR REPLACE FUNCTION get_user_stats(p_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    stats JSON;
BEGIN
    SELECT json_build_object(
        'total_cards', COUNT(DISTINCT sc.id),
        'cards_due', COUNT(DISTINCT CASE WHEN sp.next_review <= NOW() THEN sc.id END),
        'cards_mastered', COUNT(DISTINCT CASE WHEN sp.interval_days >= 21 THEN sc.id END),
        'total_reviews', COUNT(sr.id),
        'lessons_attended', COUNT(DISTINCT lp.lesson_id)
    )
    INTO stats
    FROM profiles p
    LEFT JOIN sr_progress sp ON sp.user_id = p.id
    LEFT JOIN sr_cards sc ON sc.id = sp.card_id
    LEFT JOIN sr_reviews sr ON sr.user_id = p.id
    LEFT JOIN lesson_participants lp ON lp.user_id = p.id
    WHERE p.id = p_user_id;
    
    RETURN stats;
END;
$$;

-- Get user learning analytics
CREATE OR REPLACE FUNCTION get_user_learning_analytics(
    p_user_id UUID,
    p_days_back INTEGER DEFAULT 30
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    analytics JSON;
    start_date DATE;
BEGIN
    start_date := CURRENT_DATE - p_days_back;
    
    SELECT json_build_object(
        'period_days', p_days_back,
        'total_reviews', COUNT(sr.id),
        'avg_daily_reviews', ROUND(COUNT(sr.id)::DECIMAL / p_days_back, 2),
        'avg_quality', ROUND(AVG(sr.quality), 2),
        'cards_learned', COUNT(DISTINCT CASE WHEN sp.interval_days >= 1 THEN sp.card_id END),
        'cards_mastered', COUNT(DISTINCT CASE WHEN sp.interval_days >= 21 THEN sp.card_id END),
        'lessons_attended', COUNT(DISTINCT lp.lesson_id),
        'study_streak', get_user_study_streak(p_user_id),
        'daily_breakdown', (
            SELECT json_agg(
                json_build_object(
                    'date', review_date,
                    'reviews', review_count,
                    'avg_quality', avg_quality
                )
            )
            FROM (
                SELECT 
                    sr.reviewed_at::DATE as review_date,
                    COUNT(*) as review_count,
                    ROUND(AVG(sr.quality), 2) as avg_quality
                FROM sr_reviews sr
                WHERE sr.user_id = p_user_id
                AND sr.reviewed_at >= start_date
                GROUP BY sr.reviewed_at::DATE
                ORDER BY review_date
            ) daily_stats
        )
    )
    INTO analytics
    FROM sr_reviews sr
    LEFT JOIN sr_progress sp ON sp.card_id = sr.card_id AND sp.user_id = sr.user_id
    LEFT JOIN lesson_participants lp ON lp.user_id = sr.user_id
    WHERE sr.user_id = p_user_id
    AND sr.reviewed_at >= start_date;
    
    RETURN analytics;
END;
$$;

-- Get user study streak
CREATE OR REPLACE FUNCTION get_user_study_streak(p_user_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    streak_days INTEGER := 0;
    check_date DATE := CURRENT_DATE;
    has_review BOOLEAN;
BEGIN
    LOOP
        SELECT EXISTS(
            SELECT 1 FROM sr_reviews
            WHERE user_id = p_user_id
            AND reviewed_at::DATE = check_date
        ) INTO has_review;
        
        IF NOT has_review THEN
            EXIT;
        END IF;
        
        streak_days := streak_days + 1;
        check_date := check_date - 1;
    END LOOP;
    
    RETURN streak_days;
END;
$$;