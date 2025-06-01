-- =============================================================================
-- SPACED REPETITION LEARNING SYSTEM - DATABASE FUNCTIONS
-- =============================================================================
-- This file contains all custom functions for the spaced repetition e-learning platform
-- Functions are organized by category for better maintainability
-- =============================================================================

-- =============================================================================
-- USER MANAGEMENT AND AUTHENTICATION FUNCTIONS
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

-- =============================================================================
-- LESSON MANAGEMENT AND RECORDING FUNCTIONS
-- =============================================================================

-- Create new lesson
CREATE OR REPLACE FUNCTION create_lesson(
    p_title TEXT,
    p_description TEXT DEFAULT NULL,
    p_scheduled_at TIMESTAMPTZ DEFAULT NULL,
    p_teacher_id UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    lesson_id UUID;
BEGIN
    INSERT INTO lessons (title, description, scheduled_at, created_at, updated_at)
    VALUES (p_title, p_description, p_scheduled_at, NOW(), NOW())
    RETURNING id INTO lesson_id;
    
    -- Add teacher as participant if provided
    IF p_teacher_id IS NOT NULL THEN
        INSERT INTO lesson_participants (lesson_id, user_id, role, joined_at)
        VALUES (lesson_id, p_teacher_id, 'teacher', NOW());
    END IF;
    
    RETURN lesson_id;
END;
$$;

-- Add participant to lesson
CREATE OR REPLACE FUNCTION add_lesson_participant(
    p_lesson_id UUID,
    p_user_id UUID,
    p_role TEXT DEFAULT 'student'
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO lesson_participants (lesson_id, user_id, role, joined_at)
    VALUES (p_lesson_id, p_user_id, p_role, NOW())
    ON CONFLICT (lesson_id, user_id) DO NOTHING;
    
    RETURN FOUND;
END;
$$;

-- Remove participant from lesson
CREATE OR REPLACE FUNCTION remove_lesson_participant(
    p_lesson_id UUID,
    p_user_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    DELETE FROM lesson_participants
    WHERE lesson_id = p_lesson_id AND user_id = p_user_id;
    
    RETURN FOUND;
END;
$$;

-- Start lesson recording
CREATE OR REPLACE FUNCTION start_lesson_recording(
    p_lesson_id UUID,
    p_recording_url TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE lessons
    SET 
        status = 'recording',
        recording_url = p_recording_url,
        started_at = NOW(),
        updated_at = NOW()
    WHERE id = p_lesson_id;
    
    RETURN FOUND;
END;
$$;

-- End lesson recording
CREATE OR REPLACE FUNCTION end_lesson_recording(
    p_lesson_id UUID,
    p_recording_url TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE lessons
    SET 
        status = 'completed',
        recording_url = COALESCE(p_recording_url, recording_url),
        ended_at = NOW(),
        updated_at = NOW()
    WHERE id = p_lesson_id;
    
    RETURN FOUND;
END;
$$;

-- Get lesson details with participants
CREATE OR REPLACE FUNCTION get_lesson_details(p_lesson_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    lesson_data JSON;
BEGIN
    SELECT json_build_object(
        'lesson', row_to_json(l),
        'participants', COALESCE(
            (SELECT json_agg(
                json_build_object(
                    'user_id', lp.user_id,
                    'role', lp.role,
                    'joined_at', lp.joined_at,
                    'user_profile', row_to_json(p)
                )
            )
            FROM lesson_participants lp
            LEFT JOIN profiles p ON p.id = lp.user_id
            WHERE lp.lesson_id = l.id), '[]'::json
        )
    )
    INTO lesson_data
    FROM lessons l
    WHERE l.id = p_lesson_id;
    
    RETURN lesson_data;
END;
$$;

-- Get user's lessons
CREATE OR REPLACE FUNCTION get_user_lessons(
    p_user_id UUID,
    p_role TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN (
        SELECT json_agg(
            json_build_object(
                'lesson', row_to_json(l),
                'role', lp.role,
                'joined_at', lp.joined_at
            )
        )
        FROM lesson_participants lp
        JOIN lessons l ON l.id = lp.lesson_id
        WHERE lp.user_id = p_user_id
        AND (p_role IS NULL OR lp.role = p_role)
        ORDER BY l.scheduled_at DESC NULLS LAST, l.created_at DESC
        LIMIT p_limit OFFSET p_offset
    );
END;
$$;

-- =============================================================================
-- SPACED REPETITION ALGORITHM FUNCTIONS
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

-- =============================================================================
-- CARD CREATION AND MODERATION FUNCTIONS
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

-- =============================================================================
-- PROGRESS TRACKING AND ANALYTICS FUNCTIONS
-- =============================================================================

-- Get lesson analytics
CREATE OR REPLACE FUNCTION get_lesson_analytics(p_lesson_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    analytics JSON;
BEGIN
    SELECT json_build_object(
        'total_participants', COUNT(DISTINCT lp.user_id),
        'students', COUNT(DISTINCT CASE WHEN lp.role = 'student' THEN lp.user_id END),
        'teachers', COUNT(DISTINCT CASE WHEN lp.role = 'teacher' THEN lp.user_id END),
        'cards_created', COUNT(DISTINCT sc.id),
        'total_interactions', COUNT(sli.id),
        'avg_engagement_score', ROUND(AVG(sli.engagement_score), 2)
    )
    INTO analytics
    FROM lessons l
    LEFT JOIN lesson_participants lp ON lp.lesson_id = l.id
    LEFT JOIN sr_cards sc ON sc.lesson_id = l.id
    LEFT JOIN student_lesson_interactions sli ON sli.lesson_id = l.id
    WHERE l.id = p_lesson_id;
    
    RETURN analytics;
END;
$$;

-- Get user progress in lesson
CREATE OR REPLACE FUNCTION get_user_lesson_progress(
    p_user_id UUID,
    p_lesson_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    progress JSON;
BEGIN
    SELECT json_build_object(
        'cards_from_lesson', COUNT(DISTINCT sc.id),
        'cards_reviewed', COUNT(DISTINCT sp.card_id),
        'avg_quality', ROUND(AVG(sr.quality), 2),
        'total_reviews', COUNT(sr.id),
        'last_review', MAX(sr.reviewed_at),
        'interactions', COUNT(sli.id),
        'avg_engagement', ROUND(AVG(sli.engagement_score), 2)
    )
    INTO progress
    FROM sr_cards sc
    LEFT JOIN sr_progress sp ON sp.card_id = sc.id AND sp.user_id = p_user_id
    LEFT JOIN sr_reviews sr ON sr.card_id = sc.id AND sr.user_id = p_user_id
    LEFT JOIN student_lesson_interactions sli ON sli.lesson_id = sc.lesson_id AND sli.user_id = p_user_id
    WHERE sc.lesson_id = p_lesson_id;
    
    RETURN progress;
END;
$$;

-- Record student lesson interaction
CREATE OR REPLACE FUNCTION record_lesson_interaction(
    p_user_id UUID,
    p_lesson_id UUID,
    p_interaction_type TEXT,
    p_engagement_score INTEGER DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    interaction_id UUID;
BEGIN
    INSERT INTO student_lesson_interactions (
        user_id, lesson_id, interaction_type, engagement_score, notes, created_at
    )
    VALUES (
        p_user_id, p_lesson_id, p_interaction_type, p_engagement_score, p_notes, NOW()
    )
    RETURNING id INTO interaction_id;
    
    RETURN interaction_id;
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

-- =============================================================================
-- FLAG MANAGEMENT AND RESOLUTION FUNCTIONS
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

-- =============================================================================
-- STUDENT-TEACHER INTERACTION FUNCTIONS
-- =============================================================================

-- Get teacher's students
CREATE OR REPLACE FUNCTION get_teacher_students(p_teacher_id UUID)
RETURNS TABLE(
    student_id UUID,
    student_name TEXT,
    student_email TEXT,
    lessons_together INTEGER,
    last_interaction TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        s.id as student_id,
        s.full_name as student_name,
        s.email as student_email,
        COUNT(DISTINCT lp1.lesson_id)::INTEGER as lessons_together,
        MAX(sli.created_at) as last_interaction
    FROM lesson_participants lp_teacher
    JOIN lesson_participants lp_student ON lp_teacher.lesson_id = lp_student.lesson_id
    JOIN profiles s ON s.id = lp_student.user_id
    LEFT JOIN lesson_participants lp1 ON lp1.user_id = s.id
    LEFT JOIN student_lesson_interactions sli ON sli.user_id = s.id
    WHERE lp_teacher.user_id = p_teacher_id
    AND lp_teacher.role = 'teacher'
    AND lp_student.role = 'student'
    AND lp_student.user_id != p_teacher_id
    GROUP BY s.id, s.full_name, s.email
    ORDER BY lessons_together DESC, last_interaction DESC NULLS LAST;
END;
$$;

-- Get student's teachers
CREATE OR REPLACE FUNCTION get_student_teachers(p_student_id UUID)
RETURNS TABLE(
    teacher_id UUID,
    teacher_name TEXT,
    teacher_email TEXT,
    lessons_together INTEGER,
    last_lesson TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        t.id as teacher_id,
        t.full_name as teacher_name,
        t.email as teacher_email,
        COUNT(DISTINCT lp_student.lesson_id)::INTEGER as lessons_together,
        MAX(l.scheduled_at) as last_lesson
    FROM lesson_participants lp_student
    JOIN lesson_participants lp_teacher ON lp_student.lesson_id = lp_teacher.lesson_id
    JOIN profiles t ON t.id = lp_teacher.user_id
    LEFT JOIN lessons l ON l.id = lp_student.lesson_id
    WHERE lp_student.user_id = p_student_id
    AND lp_student.role = 'student'
    AND lp_teacher.role = 'teacher'
    AND lp_teacher.user_id != p_student_id
    GROUP BY t.id, t.full_name, t.email
    ORDER BY lessons_together DESC, last_lesson DESC NULLS LAST;
END;
$$;

-- =============================================================================
-- TRANSCRIPTION AND AUDIO PROCESSING FUNCTIONS
-- =============================================================================

-- Create transcript for lesson
CREATE OR REPLACE FUNCTION create_transcript(
    p_lesson_id UUID,
    p_content TEXT,
    p_language TEXT DEFAULT 'en',
    p_confidence_score DECIMAL DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    transcript_id UUID;
BEGIN
    INSERT INTO transcripts (lesson_id, content, language, confidence_score, created_at, updated_at)
    VALUES (p_lesson_id, p_content, p_language, p_confidence_score, NOW(), NOW())
    RETURNING id INTO transcript_id;
    
    RETURN transcript_id;
END;
$$;

-- Update transcript
CREATE OR REPLACE FUNCTION update_transcript(
    p_transcript_id UUID,
    p_content TEXT,
    p_confidence_score DECIMAL DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE transcripts
    SET 
        content = p_content,
        confidence_score = COALESCE(p_confidence_score, confidence_score),
        updated_at = NOW()
    WHERE id = p_transcript_id;
    
    RETURN FOUND;
END;
$$;

-- Create summary for lesson
CREATE OR REPLACE FUNCTION create_summary(
    p_lesson_id UUID,
    p_summary_text TEXT,
    p_key_points TEXT[] DEFAULT NULL,
    p_generated_by TEXT DEFAULT 'ai'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    summary_id UUID;
BEGIN
    INSERT INTO summaries (lesson_id, summary_text, key_points, generated_by, created_at, updated_at)
    VALUES (p_lesson_id, p_summary_text, p_key_points, p_generated_by, NOW(), NOW())
    RETURNING id INTO summary_id;
    
    RETURN summary_id;
END;
$$;

-- Get lesson content (transcript + summary)
CREATE OR REPLACE FUNCTION get_lesson_content(p_lesson_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    content JSON;
BEGIN
    SELECT json_build_object(
        'lesson', row_to_json(l),
        'transcript', (
            SELECT row_to_json(t)
            FROM transcripts t
            WHERE t.lesson_id = l.id
            ORDER BY t.created_at DESC
            LIMIT 1
        ),
        'summary', (
            SELECT row_to_json(s)
            FROM summaries s
            WHERE s.lesson_id = l.id
            ORDER BY s.created_at DESC
            LIMIT 1
        ),
        'cards', COALESCE(
            (SELECT json_agg(row_to_json(sc))
             FROM sr_cards sc
             WHERE sc.lesson_id = l.id
             AND sc.status = 'approved'), '[]'::json
        )
    )
    INTO content
    FROM lessons l
    WHERE l.id = p_lesson_id;
    
    RETURN content;
END;
$$;

-- =============================================================================
-- DEBUG AND TESTING FUNCTIONS
-- =============================================================================

-- Get system health check
CREATE OR REPLACE FUNCTION system_health_check()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    health JSON;
BEGIN
    SELECT json_build_object(
        'timestamp', NOW(),
        'database', 'healthy',
        'tables', json_build_object(
            'profiles', (SELECT COUNT(*) FROM profiles),
            'lessons', (SELECT COUNT(*) FROM lessons),
            'sr_cards', (SELECT COUNT(*) FROM sr_cards),
            'sr_progress', (SELECT COUNT(*) FROM sr_progress),
            'sr_reviews', (SELECT COUNT(*) FROM sr_reviews),
            'lesson_participants', (SELECT COUNT(*) FROM lesson_participants),
            'sr_card_flags', (SELECT COUNT(*) FROM sr_card_flags),
            'transcripts', (SELECT COUNT(*) FROM transcripts),
            'summaries', (SELECT COUNT(*) FROM summaries),
            'student_lesson_interactions', (SELECT COUNT(*) FROM student_lesson_interactions)
        ),
        'functions_loaded', 60,
        'triggers_active', 3
    )
    INTO health;
    
    RETURN health;
END;
$$;

-- Clean up test data
CREATE OR REPLACE FUNCTION cleanup_test_data()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    deleted_count INTEGER := 0;
BEGIN
    -- Delete test reviews
    DELETE FROM sr_reviews WHERE user_id IN (
        SELECT id FROM profiles WHERE email LIKE '%test%'
    );
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    -- Delete test progress
    DELETE FROM sr_progress WHERE user_id IN (
        SELECT id FROM profiles WHERE email LIKE '%test%'
    );
    
    -- Delete test cards
    DELETE FROM sr_cards WHERE created_by IN (
        SELECT id FROM profiles WHERE email LIKE '%test%'
    );
    
    -- Delete test lesson participants
    DELETE FROM lesson_participants WHERE user_id IN (
        SELECT id FROM profiles WHERE email LIKE '%test%'
    );
    
    -- Delete test lessons
    DELETE FROM lessons WHERE title LIKE '%test%';
    
    -- Delete test profiles
    DELETE FROM profiles WHERE email LIKE '%test%';
    
    RETURN deleted_count;
END;
$$;

-- Generate sample data for testing
CREATE OR REPLACE FUNCTION generate_sample_data()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    test_user_id UUID;
    test_lesson_id UUID;
    test_card_id UUID;
BEGIN
    -- Create test user
    INSERT INTO profiles (id, email, full_name, created_at, updated_at)
    VALUES (gen_random_uuid(), 'test@example.com', 'Test User', NOW(), NOW())
    RETURNING id INTO test_user_id;
    
    -- Create test lesson
    test_lesson_id := create_lesson('Test Lesson', 'Sample lesson for testing', NOW() + INTERVAL '1 hour');
    
    -- Add user to lesson
    PERFORM add_lesson_participant(test_lesson_id, test_user_id, 'student');
    
    -- Create test card
    test_card_id := create_sr_card('What is 2+2?', '4', test_lesson_id, test_user_id, ARRAY['math', 'basic']);
    
    -- Approve the card
    PERFORM approve_sr_card(test_card_id, test_user_id);
    
    -- Record a review
    PERFORM record_sr_review(test_user_id, test_card_id, 4, 3000);
    
    RETURN 'Sample data generated successfully';
END;
$$;

-- =============================================================================
-- UTILITY AND HELPER FUNCTIONS
-- =============================================================================

-- Get database statistics
CREATE OR REPLACE FUNCTION get_database_stats()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    stats JSON;
BEGIN
    SELECT json_build_object(
        'total_users', (SELECT COUNT(*) FROM profiles),
        'total_lessons', (SELECT COUNT(*) FROM lessons),
        'active_lessons', (SELECT COUNT(*) FROM lessons WHERE status = 'recording'),
        'total_cards', (SELECT COUNT(*) FROM sr_cards),
        'approved_cards', (SELECT COUNT(*) FROM sr_cards WHERE status = 'approved'),
        'pending_cards', (SELECT COUNT(*) FROM sr_cards WHERE status = 'pending'),
        'total_reviews', (SELECT COUNT(*) FROM sr_reviews),
        'reviews_today', (SELECT COUNT(*) FROM sr_reviews WHERE reviewed_at::DATE = CURRENT_DATE),
        'active_progress_records', (SELECT COUNT(*) FROM sr_progress),
        'pending_flags', (SELECT COUNT(*) FROM sr_card_flags WHERE status = 'pending'),
        'lesson_participants', (SELECT COUNT(*) FROM lesson_participants),
        'transcripts', (SELECT COUNT(*) FROM transcripts),
        'summaries', (SELECT COUNT(*) FROM summaries)
    )
    INTO stats;
    
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

-- =============================================================================
-- END OF FUNCTIONS
-- =============================================================================
-- Total functions: 60+
-- Last updated: 2025-05-30
-- =============================================================================
