-- Teacher-specific database functions for Phase 2
-- Functions for lesson creation, card management, and analytics

-- Function: create_lesson
-- Creates a new lesson with validation
CREATE OR REPLACE FUNCTION create_lesson(
    p_name TEXT,
    p_scheduled_at TIMESTAMPTZ,
    p_description TEXT DEFAULT NULL,
    p_duration_minutes INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_teacher_id UUID;
    v_lesson_id UUID;
    v_result JSON;
BEGIN
    -- Get current user ID
    v_teacher_id := auth.uid();
    
    -- Validate user is a teacher
    IF NOT EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE id = v_teacher_id AND role = 'teacher'
    ) THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Unauthorized: Only teachers can create lessons'
        );
    END IF;
    
    -- Validate input
    IF p_name IS NULL OR LENGTH(TRIM(p_name)) = 0 THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Lesson name is required'
        );
    END IF;
    
    IF p_scheduled_at IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Scheduled date is required'
        );
    END IF;
    
    -- Insert new lesson
    INSERT INTO public.lessons (
        teacher_id, 
        name, 
        description, 
        scheduled_at, 
        duration_minutes
    )
    VALUES (
        v_teacher_id,
        TRIM(p_name),
        p_description,
        p_scheduled_at,
        p_duration_minutes
    )
    RETURNING id INTO v_lesson_id;
    
    -- Return success with lesson data
    SELECT json_build_object(
        'success', true,
        'data', row_to_json(lessons.*)
    )
    FROM public.lessons
    WHERE id = v_lesson_id
    INTO v_result;
    
    RETURN v_result;
END;
$$;

-- Function: update_lesson
-- Updates an existing lesson with validation
CREATE OR REPLACE FUNCTION update_lesson(
    p_lesson_id UUID,
    p_name TEXT DEFAULT NULL,
    p_description TEXT DEFAULT NULL,
    p_scheduled_at TIMESTAMPTZ DEFAULT NULL,
    p_duration_minutes INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_teacher_id UUID;
    v_result JSON;
BEGIN
    -- Get current user ID
    v_teacher_id := auth.uid();
    
    -- Validate user owns the lesson
    IF NOT EXISTS (
        SELECT 1 FROM public.lessons 
        WHERE id = p_lesson_id AND teacher_id = v_teacher_id
    ) THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Lesson not found or access denied'
        );
    END IF;
    
    -- Update lesson with non-null values
    UPDATE public.lessons
    SET 
        name = COALESCE(TRIM(p_name), name),
        description = COALESCE(p_description, description),
        scheduled_at = COALESCE(p_scheduled_at, scheduled_at),
        duration_minutes = COALESCE(p_duration_minutes, duration_minutes),
        updated_at = NOW()
    WHERE id = p_lesson_id;
    
    -- Return updated lesson data
    SELECT json_build_object(
        'success', true,
        'data', row_to_json(lessons.*)
    )
    FROM public.lessons
    WHERE id = p_lesson_id
    INTO v_result;
    
    RETURN v_result;
END;
$$;

-- Function: add_lesson_participant
-- Adds a student to a lesson
CREATE OR REPLACE FUNCTION add_lesson_participant(
    p_lesson_id UUID,
    p_student_email TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_teacher_id UUID;
    v_student_id UUID;
    v_result JSON;
BEGIN
    -- Get current user ID
    v_teacher_id := auth.uid();
    
    -- Validate user owns the lesson
    IF NOT EXISTS (
        SELECT 1 FROM public.lessons 
        WHERE id = p_lesson_id AND teacher_id = v_teacher_id
    ) THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Lesson not found or access denied'
        );
    END IF;
    
    -- Find student by email
    SELECT id INTO v_student_id
    FROM public.profiles
    WHERE email = LOWER(TRIM(p_student_email)) AND role = 'student';
    
    IF v_student_id IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Student not found with email: ' || p_student_email
        );
    END IF;
    
    -- Check if already enrolled
    IF EXISTS (
        SELECT 1 FROM public.lesson_participants
        WHERE lesson_id = p_lesson_id AND student_id = v_student_id
    ) THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Student is already enrolled in this lesson'
        );
    END IF;
    
    -- Add participant
    INSERT INTO public.lesson_participants (lesson_id, student_id)
    VALUES (p_lesson_id, v_student_id);
    
    -- Initialize progress tracking
    INSERT INTO public.sr_progress (student_id, lesson_id, cards_total)
    VALUES (v_student_id, p_lesson_id, 0)
    ON CONFLICT (student_id, lesson_id) DO NOTHING;
    
    -- Return success with student data
    SELECT json_build_object(
        'success', true,
        'data', json_build_object(
            'student_id', p.id,
            'name', p.name,
            'email', p.email,
            'enrolled_at', lp.enrolled_at
        )
    )
    FROM public.profiles p
    JOIN public.lesson_participants lp ON p.id = lp.student_id
    WHERE p.id = v_student_id AND lp.lesson_id = p_lesson_id
    INTO v_result;
    
    RETURN v_result;
END;
$$;

-- Function: remove_lesson_participant
-- Removes a student from a lesson
CREATE OR REPLACE FUNCTION remove_lesson_participant(
    p_lesson_id UUID,
    p_student_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_teacher_id UUID;
BEGIN
    -- Get current user ID
    v_teacher_id := auth.uid();
    
    -- Validate user owns the lesson
    IF NOT EXISTS (
        SELECT 1 FROM public.lessons 
        WHERE id = p_lesson_id AND teacher_id = v_teacher_id
    ) THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Lesson not found or access denied'
        );
    END IF;
    
    -- Remove participant
    DELETE FROM public.lesson_participants
    WHERE lesson_id = p_lesson_id AND student_id = p_student_id;
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Student not enrolled in this lesson'
        );
    END IF;
    
    RETURN json_build_object(
        'success', true,
        'message', 'Student removed from lesson'
    );
END;
$$;

-- Function: create_sr_card
-- Creates a new flashcard for a lesson
CREATE OR REPLACE FUNCTION create_sr_card(
    p_lesson_id UUID,
    p_front_content TEXT,
    p_back_content TEXT,
    p_card_type TEXT DEFAULT 'basic',
    p_difficulty_level INTEGER DEFAULT 1,
    p_tags TEXT[] DEFAULT ARRAY[]::TEXT[]
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_teacher_id UUID;
    v_card_id UUID;
    v_result JSON;
BEGIN
    -- Get current user ID
    v_teacher_id := auth.uid();
    
    -- Validate user owns the lesson
    IF NOT EXISTS (
        SELECT 1 FROM public.lessons 
        WHERE id = p_lesson_id AND teacher_id = v_teacher_id
    ) THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Lesson not found or access denied'
        );
    END IF;
    
    -- Validate input
    IF LENGTH(TRIM(p_front_content)) = 0 OR LENGTH(TRIM(p_back_content)) = 0 THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Front and back content are required'
        );
    END IF;
    
    -- Insert new card (auto-approved for teachers)
    INSERT INTO public.sr_cards (
        lesson_id,
        created_by,
        front_content,
        back_content,
        card_type,
        difficulty_level,
        tags,
        status,
        approved_by,
        approved_at
    )
    VALUES (
        p_lesson_id,
        v_teacher_id,
        TRIM(p_front_content),
        TRIM(p_back_content),
        p_card_type,
        p_difficulty_level,
        p_tags,
        'approved',
        v_teacher_id,
        NOW()
    )
    RETURNING id INTO v_card_id;
    
    -- Update lesson card counts for all students
    UPDATE public.sr_progress
    SET cards_total = (
        SELECT COUNT(*) FROM public.sr_cards
        WHERE lesson_id = p_lesson_id AND status = 'approved'
    )
    WHERE lesson_id = p_lesson_id;
    
    -- Return success with card data
    SELECT json_build_object(
        'success', true,
        'data', row_to_json(sr_cards.*)
    )
    FROM public.sr_cards
    WHERE id = v_card_id
    INTO v_result;
    
    RETURN v_result;
END;
$$;

-- Function: approve_sr_card
-- Approves a pending flashcard
CREATE OR REPLACE FUNCTION approve_sr_card(
    p_card_id UUID,
    p_approved BOOLEAN DEFAULT TRUE
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_teacher_id UUID;
    v_lesson_id UUID;
    v_new_status TEXT;
BEGIN
    -- Get current user ID
    v_teacher_id := auth.uid();
    
    -- Get lesson ID and validate teacher ownership
    SELECT lesson_id INTO v_lesson_id
    FROM public.sr_cards sc
    JOIN public.lessons l ON sc.lesson_id = l.id
    WHERE sc.id = p_card_id AND l.teacher_id = v_teacher_id;
    
    IF v_lesson_id IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Card not found or access denied'
        );
    END IF;
    
    -- Set status based on approval
    v_new_status := CASE WHEN p_approved THEN 'approved' ELSE 'rejected' END;
    
    -- Update card status
    UPDATE public.sr_cards
    SET 
        status = v_new_status,
        approved_by = v_teacher_id,
        approved_at = NOW(),
        updated_at = NOW()
    WHERE id = p_card_id;
    
    -- Update lesson card counts if approved
    IF p_approved THEN
        UPDATE public.sr_progress
        SET cards_total = (
            SELECT COUNT(*) FROM public.sr_cards
            WHERE lesson_id = v_lesson_id AND status = 'approved'
        )
        WHERE lesson_id = v_lesson_id;
    END IF;
    
    RETURN json_build_object(
        'success', true,
        'message', 'Card ' || v_new_status || ' successfully'
    );
END;
$$;

-- Function: get_lesson_analytics
-- Gets comprehensive analytics for a lesson
CREATE OR REPLACE FUNCTION get_lesson_analytics(p_lesson_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_teacher_id UUID;
    v_result JSON;
BEGIN
    -- Get current user ID
    v_teacher_id := auth.uid();
    
    -- Validate user owns the lesson
    IF NOT EXISTS (
        SELECT 1 FROM public.lessons 
        WHERE id = p_lesson_id AND teacher_id = v_teacher_id
    ) THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Lesson not found or access denied'
        );
    END IF;
    
    -- Build comprehensive analytics
    SELECT json_build_object(
        'success', true,
        'data', json_build_object(
            'lesson_id', p_lesson_id,
            'overview', (
                SELECT json_build_object(
                    'total_students', COUNT(DISTINCT lp.student_id),
                    'total_cards', COUNT(DISTINCT sc.id),
                    'approved_cards', COUNT(DISTINCT CASE WHEN sc.status = 'approved' THEN sc.id END),
                    'pending_cards', COUNT(DISTINCT CASE WHEN sc.status = 'pending' THEN sc.id END)
                )
                FROM public.lesson_participants lp
                FULL OUTER JOIN public.sr_cards sc ON sc.lesson_id = p_lesson_id
                WHERE lp.lesson_id = p_lesson_id OR sc.lesson_id = p_lesson_id
            ),
            'student_progress', (
                SELECT json_agg(
                    json_build_object(
                        'student_id', p.id,
                        'student_name', p.name,
                        'student_email', p.email,
                        'cards_total', COALESCE(sp.cards_total, 0),
                        'cards_reviewed', COALESCE(sp.cards_reviewed, 0),
                        'cards_learned', COALESCE(sp.cards_learned, 0),
                        'average_quality', COALESCE(sp.average_quality, 0),
                        'study_streak', COALESCE(sp.study_streak, 0),
                        'last_review_date', sp.last_review_date,
                        'next_review_date', sp.next_review_date,
                        'enrolled_at', lp.enrolled_at
                    )
                )
                FROM public.lesson_participants lp
                JOIN public.profiles p ON lp.student_id = p.id
                LEFT JOIN public.sr_progress sp ON sp.student_id = p.id AND sp.lesson_id = p_lesson_id
                WHERE lp.lesson_id = p_lesson_id
                ORDER BY p.name
            ),
            'recent_activity', (
                SELECT json_agg(
                    json_build_object(
                        'type', 'review',
                        'student_name', p.name,
                        'card_front', sc.front_content,
                        'quality_rating', sr.quality_rating,
                        'completed_at', sr.completed_at
                    )
                )
                FROM public.sr_reviews sr
                JOIN public.sr_cards sc ON sr.card_id = sc.id
                JOIN public.profiles p ON sr.student_id = p.id
                WHERE sc.lesson_id = p_lesson_id 
                  AND sr.completed_at IS NOT NULL
                ORDER BY sr.completed_at DESC
                LIMIT 20
            )
        )
    ) INTO v_result;
    
    RETURN v_result;
END;
$$;

-- Function: get_teacher_lessons
-- Gets all lessons for a teacher with basic stats
CREATE OR REPLACE FUNCTION get_teacher_lessons()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_teacher_id UUID;
    v_result JSON;
BEGIN
    -- Get current user ID
    v_teacher_id := auth.uid();
    
    -- Validate user is a teacher
    IF NOT EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE id = v_teacher_id AND role = 'teacher'
    ) THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Unauthorized: Only teachers can access this function'
        );
    END IF;
    
    -- Get lessons with stats
    SELECT json_build_object(
        'success', true,
        'data', COALESCE(json_agg(
            json_build_object(
                'id', l.id,
                'name', l.name,
                'description', l.description,
                'scheduled_at', l.scheduled_at,
                'duration_minutes', l.duration_minutes,
                'has_audio', l.has_audio,
                'recording_path', l.recording_path,
                'created_at', l.created_at,
                'updated_at', l.updated_at,
                'student_count', COALESCE(participant_counts.count, 0),
                'card_count', COALESCE(card_counts.count, 0),
                'pending_cards', COALESCE(pending_counts.count, 0)
            ) ORDER BY l.created_at DESC
        ), '[]'::json)
    )
    FROM public.lessons l
    LEFT JOIN (
        SELECT lesson_id, COUNT(*) as count
        FROM public.lesson_participants
        GROUP BY lesson_id
    ) participant_counts ON l.id = participant_counts.lesson_id
    LEFT JOIN (
        SELECT lesson_id, COUNT(*) as count
        FROM public.sr_cards
        WHERE status = 'approved'
        GROUP BY lesson_id
    ) card_counts ON l.id = card_counts.lesson_id
    LEFT JOIN (
        SELECT lesson_id, COUNT(*) as count
        FROM public.sr_cards
        WHERE status = 'pending'
        GROUP BY lesson_id
    ) pending_counts ON l.id = pending_counts.lesson_id
    WHERE l.teacher_id = v_teacher_id
    INTO v_result;
    
    RETURN v_result;
END;
$$;

-- Function: get_teacher_stats
-- Gets comprehensive statistics for teacher dashboard
CREATE OR REPLACE FUNCTION get_teacher_stats()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_teacher_id UUID;
    v_result JSON;
BEGIN
    -- Get current user ID
    v_teacher_id := auth.uid();
    
    -- Validate user is a teacher
    IF NOT EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE id = v_teacher_id AND role = 'teacher'
    ) THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Unauthorized: Only teachers can access this function'
        );
    END IF;
    
    -- Build comprehensive stats
    SELECT json_build_object(
        'success', true,
        'data', json_build_object(
            'total_lessons', (
                SELECT COUNT(*) FROM public.lessons WHERE teacher_id = v_teacher_id
            ),
            'total_students', (
                SELECT COUNT(DISTINCT lp.student_id)
                FROM public.lesson_participants lp
                JOIN public.lessons l ON lp.lesson_id = l.id
                WHERE l.teacher_id = v_teacher_id
            ),
            'total_cards_created', (
                SELECT COUNT(*)
                FROM public.sr_cards sc
                JOIN public.lessons l ON sc.lesson_id = l.id
                WHERE l.teacher_id = v_teacher_id
            ),
            'pending_cards', (
                SELECT COUNT(*)
                FROM public.sr_cards sc
                JOIN public.lessons l ON sc.lesson_id = l.id
                WHERE l.teacher_id = v_teacher_id AND sc.status = 'pending'
            ),
            'recent_activity', (
                SELECT json_agg(
                    json_build_object(
                        'type', activity_type,
                        'description', description,
                        'timestamp', timestamp
                    ) ORDER BY timestamp DESC
                )
                FROM (
                    -- Lesson creations
                    SELECT 
                        'lesson_created' as activity_type,
                        'Created lesson: ' || name as description,
                        created_at as timestamp
                    FROM public.lessons
                    WHERE teacher_id = v_teacher_id
                    
                    UNION ALL
                    
                    -- Card approvals
                    SELECT 
                        'card_approved' as activity_type,
                        'Approved card: ' || LEFT(front_content, 50) || '...' as description,
                        approved_at as timestamp
                    FROM public.sr_cards sc
                    JOIN public.lessons l ON sc.lesson_id = l.id
                    WHERE l.teacher_id = v_teacher_id 
                      AND sc.status = 'approved' 
                      AND sc.approved_at IS NOT NULL
                    
                    UNION ALL
                    
                    -- Student enrollments
                    SELECT 
                        'student_enrolled' as activity_type,
                        'Student enrolled in ' || l.name as description,
                        lp.enrolled_at as timestamp
                    FROM public.lesson_participants lp
                    JOIN public.lessons l ON lp.lesson_id = l.id
                    WHERE l.teacher_id = v_teacher_id
                    
                    ORDER BY timestamp DESC
                    LIMIT 10
                ) activities
            )
        )
    ) INTO v_result;
    
    RETURN v_result;
END;
$$;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION create_lesson TO authenticated;
GRANT EXECUTE ON FUNCTION update_lesson TO authenticated;
GRANT EXECUTE ON FUNCTION add_lesson_participant TO authenticated;
GRANT EXECUTE ON FUNCTION remove_lesson_participant TO authenticated;
GRANT EXECUTE ON FUNCTION create_sr_card TO authenticated;
GRANT EXECUTE ON FUNCTION approve_sr_card TO authenticated;
GRANT EXECUTE ON FUNCTION get_lesson_analytics TO authenticated;
GRANT EXECUTE ON FUNCTION get_teacher_lessons TO authenticated;
GRANT EXECUTE ON FUNCTION get_teacher_stats TO authenticated;