-- =============================================================================
-- STUDENT-TEACHER INTERACTION FUNCTIONS
-- =============================================================================
-- Functions for managing relationships and interactions between teachers and students
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

-- Get student performance for teacher
CREATE OR REPLACE FUNCTION get_student_performance_for_teacher(
    p_teacher_id UUID,
    p_student_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    performance JSON;
BEGIN
    -- Verify teacher-student relationship
    IF NOT EXISTS (
        SELECT 1 FROM lesson_participants lp_teacher
        JOIN lesson_participants lp_student ON lp_teacher.lesson_id = lp_student.lesson_id
        WHERE lp_teacher.user_id = p_teacher_id 
        AND lp_teacher.role = 'teacher'
        AND lp_student.user_id = p_student_id 
        AND lp_student.role = 'student'
    ) THEN
        RETURN json_build_object('error', 'No teacher-student relationship found');
    END IF;
    
    SELECT json_build_object(
        'student_info', (
            SELECT json_build_object(
                'id', p.id,
                'name', p.full_name,
                'email', p.email
            )
            FROM profiles p WHERE p.id = p_student_id
        ),
        'shared_lessons', (
            SELECT json_agg(
                json_build_object(
                    'lesson_id', l.id,
                    'title', l.title,
                    'scheduled_at', l.scheduled_at,
                    'status', l.status
                )
            )
            FROM lesson_participants lp_teacher
            JOIN lesson_participants lp_student ON lp_teacher.lesson_id = lp_student.lesson_id
            JOIN lessons l ON l.id = lp_teacher.lesson_id
            WHERE lp_teacher.user_id = p_teacher_id 
            AND lp_teacher.role = 'teacher'
            AND lp_student.user_id = p_student_id 
            AND lp_student.role = 'student'
            ORDER BY l.scheduled_at DESC
        ),
        'learning_progress', (
            SELECT json_build_object(
                'total_cards', COUNT(DISTINCT sp.card_id),
                'cards_mastered', COUNT(DISTINCT CASE WHEN sp.interval_days >= 21 THEN sp.card_id END),
                'total_reviews', COUNT(sr.id),
                'avg_quality', ROUND(AVG(sr.quality), 2),
                'study_streak', get_user_study_streak(p_student_id),
                'last_review', MAX(sr.reviewed_at)
            )
            FROM sr_progress sp
            LEFT JOIN sr_reviews sr ON sr.user_id = sp.user_id AND sr.card_id = sp.card_id
            WHERE sp.user_id = p_student_id
        ),
        'lesson_interactions', (
            SELECT json_agg(
                json_build_object(
                    'lesson_id', sli.lesson_id,
                    'interaction_type', sli.interaction_type,
                    'engagement_score', sli.engagement_score,
                    'created_at', sli.created_at
                )
            )
            FROM student_lesson_interactions sli
            JOIN lesson_participants lp_teacher ON lp_teacher.lesson_id = sli.lesson_id
            WHERE sli.user_id = p_student_id
            AND lp_teacher.user_id = p_teacher_id
            AND lp_teacher.role = 'teacher'
            ORDER BY sli.created_at DESC
            LIMIT 10
        )
    )
    INTO performance;
    
    RETURN performance;
END;
$$;

-- Get class overview for teacher
CREATE OR REPLACE FUNCTION get_class_overview(p_teacher_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    overview JSON;
BEGIN
    SELECT json_build_object(
        'teacher_info', (
            SELECT json_build_object(
                'id', p.id,
                'name', p.full_name,
                'email', p.email
            )
            FROM profiles p WHERE p.id = p_teacher_id
        ),
        'total_students', (
            SELECT COUNT(DISTINCT lp_student.user_id)
            FROM lesson_participants lp_teacher
            JOIN lesson_participants lp_student ON lp_teacher.lesson_id = lp_student.lesson_id
            WHERE lp_teacher.user_id = p_teacher_id 
            AND lp_teacher.role = 'teacher'
            AND lp_student.role = 'student'
        ),
        'total_lessons', (
            SELECT COUNT(DISTINCT lesson_id)
            FROM lesson_participants
            WHERE user_id = p_teacher_id AND role = 'teacher'
        ),
        'recent_lessons', (
            SELECT json_agg(
                json_build_object(
                    'id', l.id,
                    'title', l.title,
                    'scheduled_at', l.scheduled_at,
                    'status', l.status,
                    'participant_count', (
                        SELECT COUNT(*) FROM lesson_participants 
                        WHERE lesson_id = l.id
                    )
                )
            )
            FROM lesson_participants lp
            JOIN lessons l ON l.id = lp.lesson_id
            WHERE lp.user_id = p_teacher_id AND lp.role = 'teacher'
            ORDER BY l.scheduled_at DESC NULLS LAST
            LIMIT 5
        ),
        'student_performance_summary', (
            SELECT json_agg(
                json_build_object(
                    'student_id', s.id,
                    'student_name', s.full_name,
                    'lessons_attended', lessons_count,
                    'avg_engagement', avg_engagement,
                    'last_activity', last_activity
                )
            )
            FROM (
                SELECT 
                    s.id,
                    s.full_name,
                    COUNT(DISTINCT lp_student.lesson_id) as lessons_count,
                    ROUND(AVG(sli.engagement_score), 2) as avg_engagement,
                    MAX(sli.created_at) as last_activity
                FROM lesson_participants lp_teacher
                JOIN lesson_participants lp_student ON lp_teacher.lesson_id = lp_student.lesson_id
                JOIN profiles s ON s.id = lp_student.user_id
                LEFT JOIN student_lesson_interactions sli ON sli.user_id = s.id
                WHERE lp_teacher.user_id = p_teacher_id 
                AND lp_teacher.role = 'teacher'
                AND lp_student.role = 'student'
                GROUP BY s.id, s.full_name
                ORDER BY lessons_count DESC, last_activity DESC NULLS LAST
                LIMIT 10
            ) student_stats
        ),
        'cards_created', (
            SELECT COUNT(*)
            FROM sr_cards sc
            WHERE sc.created_by = p_teacher_id
        ),
        'pending_moderation', (
            SELECT COUNT(*)
            FROM sr_cards sc
            JOIN lesson_participants lp ON lp.lesson_id = sc.lesson_id
            WHERE lp.user_id = p_teacher_id 
            AND lp.role = 'teacher'
            AND sc.status = 'pending'
        )
    )
    INTO overview;
    
    RETURN overview;
END;
$$;

-- Assign cards to students
CREATE OR REPLACE FUNCTION assign_cards_to_students(
    p_teacher_id UUID,
    p_card_ids UUID[],
    p_student_ids UUID[]
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    assigned_count INTEGER := 0;
    card_id UUID;
    student_id UUID;
BEGIN
    -- Verify teacher has permission for these cards
    IF NOT EXISTS (
        SELECT 1 FROM sr_cards sc
        JOIN lesson_participants lp ON lp.lesson_id = sc.lesson_id
        WHERE sc.id = ANY(p_card_ids)
        AND lp.user_id = p_teacher_id
        AND lp.role = 'teacher'
        AND sc.status = 'approved'
    ) THEN
        RAISE EXCEPTION 'Teacher does not have permission for these cards';
    END IF;
    
    -- Create progress records for each student-card combination
    FOREACH card_id IN ARRAY p_card_ids
    LOOP
        FOREACH student_id IN ARRAY p_student_ids
        LOOP
            -- Verify student is in teacher's classes
            IF EXISTS (
                SELECT 1 FROM lesson_participants lp_teacher
                JOIN lesson_participants lp_student ON lp_teacher.lesson_id = lp_student.lesson_id
                WHERE lp_teacher.user_id = p_teacher_id 
                AND lp_teacher.role = 'teacher'
                AND lp_student.user_id = student_id 
                AND lp_student.role = 'student'
            ) THEN
                INSERT INTO sr_progress (
                    user_id, card_id, interval_days, easiness_factor, 
                    next_review, review_count, created_at, updated_at
                )
                VALUES (
                    student_id, card_id, 0, 2.5, NOW(), 0, NOW(), NOW()
                )
                ON CONFLICT (user_id, card_id) DO NOTHING;
                
                GET DIAGNOSTICS assigned_count = ROW_COUNT;
                assigned_count := assigned_count + ROW_COUNT;
            END IF;
        END LOOP;
    END LOOP;
    
    RETURN assigned_count;
END;
$$;

-- Get student engagement metrics
CREATE OR REPLACE FUNCTION get_student_engagement_metrics(
    p_teacher_id UUID,
    p_days_back INTEGER DEFAULT 30
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    metrics JSON;
    start_date DATE;
BEGIN
    start_date := CURRENT_DATE - p_days_back;
    
    SELECT json_build_object(
        'period_days', p_days_back,
        'student_metrics', (
            SELECT json_agg(
                json_build_object(
                    'student_id', student_id,
                    'student_name', student_name,
                    'total_reviews', total_reviews,
                    'avg_quality', avg_quality,
                    'study_days', study_days,
                    'engagement_score', engagement_score,
                    'cards_mastered', cards_mastered
                )
            )
            FROM (
                SELECT 
                    s.id as student_id,
                    s.full_name as student_name,
                    COUNT(sr.id) as total_reviews,
                    ROUND(AVG(sr.quality), 2) as avg_quality,
                    COUNT(DISTINCT sr.reviewed_at::DATE) as study_days,
                    ROUND(AVG(sli.engagement_score), 2) as engagement_score,
                    COUNT(DISTINCT CASE WHEN sp.interval_days >= 21 THEN sp.card_id END) as cards_mastered
                FROM lesson_participants lp_teacher
                JOIN lesson_participants lp_student ON lp_teacher.lesson_id = lp_student.lesson_id
                JOIN profiles s ON s.id = lp_student.user_id
                LEFT JOIN sr_reviews sr ON sr.user_id = s.id AND sr.reviewed_at >= start_date
                LEFT JOIN student_lesson_interactions sli ON sli.user_id = s.id AND sli.created_at >= start_date
                LEFT JOIN sr_progress sp ON sp.user_id = s.id
                WHERE lp_teacher.user_id = p_teacher_id 
                AND lp_teacher.role = 'teacher'
                AND lp_student.role = 'student'
                GROUP BY s.id, s.full_name
                ORDER BY total_reviews DESC, avg_quality DESC
            ) student_data
        ),
        'class_averages', (
            SELECT json_build_object(
                'avg_reviews_per_student', ROUND(AVG(review_count), 2),
                'avg_quality', ROUND(AVG(avg_quality), 2),
                'avg_study_days', ROUND(AVG(study_days), 2),
                'total_active_students', COUNT(CASE WHEN review_count > 0 THEN 1 END)
            )
            FROM (
                SELECT 
                    s.id,
                    COUNT(sr.id) as review_count,
                    AVG(sr.quality) as avg_quality,
                    COUNT(DISTINCT sr.reviewed_at::DATE) as study_days
                FROM lesson_participants lp_teacher
                JOIN lesson_participants lp_student ON lp_teacher.lesson_id = lp_student.lesson_id
                JOIN profiles s ON s.id = lp_student.user_id
                LEFT JOIN sr_reviews sr ON sr.user_id = s.id AND sr.reviewed_at >= start_date
                WHERE lp_teacher.user_id = p_teacher_id 
                AND lp_teacher.role = 'teacher'
                AND lp_student.role = 'student'
                GROUP BY s.id
            ) class_stats
        )
    )
    INTO metrics;
    
    RETURN metrics;
END;
$$;

-- Send message to student (conceptual - would integrate with messaging system)
CREATE OR REPLACE FUNCTION send_student_message(
    p_teacher_id UUID,
    p_student_id UUID,
    p_message_type TEXT,
    p_message_content TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Verify teacher-student relationship
    IF NOT EXISTS (
        SELECT 1 FROM lesson_participants lp_teacher
        JOIN lesson_participants lp_student ON lp_teacher.lesson_id = lp_student.lesson_id
        WHERE lp_teacher.user_id = p_teacher_id 
        AND lp_teacher.role = 'teacher'
        AND lp_student.user_id = p_student_id 
        AND lp_student.role = 'student'
    ) THEN
        RETURN FALSE;
    END IF;
    
    -- Log the interaction
    INSERT INTO student_lesson_interactions (
        user_id, lesson_id, interaction_type, notes, created_at
    )
    SELECT 
        p_student_id,
        lp.lesson_id,
        'teacher_message',
        p_message_type || ': ' || p_message_content,
        NOW()
    FROM lesson_participants lp
    WHERE lp.user_id = p_teacher_id 
    AND lp.role = 'teacher'
    LIMIT 1; -- Use most recent lesson
    
    RETURN TRUE;
END;
$$;