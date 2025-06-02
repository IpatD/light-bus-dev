-- Migration: Fix get_lesson_analytics function SQL GROUP BY error
-- File: 013_fix_lesson_analytics_function.sql
-- Purpose: Fix GROUP BY clause error in get_lesson_analytics function

-- Drop and recreate the function with correct SQL syntax
DROP FUNCTION IF EXISTS get_lesson_analytics(UUID);

-- Function: get_lesson_analytics (fixed version)
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
                SELECT COALESCE(json_agg(
                    json_build_object(
                        'student_id', student_data.id,
                        'student_name', student_data.name,
                        'student_email', student_data.email,
                        'cards_total', student_data.cards_total,
                        'cards_reviewed', student_data.cards_reviewed,
                        'cards_learned', student_data.cards_learned,
                        'average_quality', student_data.average_quality,
                        'study_streak', student_data.study_streak,
                        'last_review_date', student_data.last_review_date,
                        'next_review_date', student_data.next_review_date,
                        'enrolled_at', student_data.enrolled_at
                    ) ORDER BY student_data.name
                ), '[]'::json)
                FROM (
                    SELECT 
                        p.id,
                        p.name,
                        p.email,
                        COALESCE(sp.cards_total, 0) as cards_total,
                        COALESCE(sp.cards_reviewed, 0) as cards_reviewed,
                        COALESCE(sp.cards_learned, 0) as cards_learned,
                        COALESCE(sp.average_quality, 0) as average_quality,
                        COALESCE(sp.study_streak, 0) as study_streak,
                        sp.last_review_date,
                        sp.next_review_date,
                        lp.enrolled_at
                    FROM public.lesson_participants lp
                    JOIN public.profiles p ON lp.student_id = p.id
                    LEFT JOIN public.sr_progress sp ON sp.student_id = p.id AND sp.lesson_id = p_lesson_id
                    WHERE lp.lesson_id = p_lesson_id
                    ORDER BY p.name
                ) AS student_data
            ),
            'recent_activity', (
                SELECT COALESCE(json_agg(
                    json_build_object(
                        'type', 'review',
                        'student_name', activity_data.student_name,
                        'card_front', activity_data.card_front,
                        'quality_rating', activity_data.quality_rating,
                        'completed_at', activity_data.completed_at
                    ) ORDER BY activity_data.completed_at DESC
                ), '[]'::json)
                FROM (
                    SELECT 
                        p.name as student_name,
                        sc.front_content as card_front,
                        sr.quality_rating,
                        sr.completed_at
                    FROM public.sr_reviews sr
                    JOIN public.sr_cards sc ON sr.card_id = sc.id
                    JOIN public.profiles p ON sr.student_id = p.id
                    WHERE sc.lesson_id = p_lesson_id 
                      AND sr.completed_at IS NOT NULL
                    ORDER BY sr.completed_at DESC
                    LIMIT 20
                ) AS activity_data
            )
        )
    ) INTO v_result;
    
    RETURN v_result;
END;
$$;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION get_lesson_analytics TO authenticated;

-- Add helpful comments
COMMENT ON FUNCTION get_lesson_analytics IS 'Gets comprehensive analytics for a lesson (FIXED VERSION)';