-- =============================================================================
-- LESSON MANAGEMENT AND RECORDING FUNCTIONS
-- =============================================================================
-- Functions for creating, managing, and recording lessons
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