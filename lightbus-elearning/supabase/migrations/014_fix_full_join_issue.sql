-- Migration: Fix FULL JOIN issue in get_lesson_analytics function
-- File: 014_fix_full_join_issue.sql
-- Purpose: Replace problematic FULL JOIN with simpler separate queries

-- Drop and recreate the function without FULL JOIN
DROP FUNCTION IF EXISTS get_lesson_analytics(UUID);

-- Function: get_lesson_analytics (fixed FULL JOIN version)
-- Gets comprehensive analytics for a lesson
CREATE OR REPLACE FUNCTION get_lesson_analytics(p_lesson_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_teacher_id UUID;
    v_result JSON;
    v_total_students INTEGER;
    v_total_cards INTEGER;
    v_approved_cards INTEGER;
    v_pending_cards INTEGER;
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
    
    -- Get overview stats separately to avoid complex joins
    SELECT COUNT(DISTINCT student_id) INTO v_total_students
    FROM public.lesson_participants 
    WHERE lesson_id = p_lesson_id;
    
    SELECT 
        COUNT(*) as total,
        COUNT(CASE WHEN status = 'approved' THEN 1 END) as approved,
        COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending
    INTO v_total_cards, v_approved_cards, v_pending_cards
    FROM public.sr_cards 
    WHERE lesson_id = p_lesson_id;
    
    -- Build comprehensive analytics
    SELECT json_build_object(
        'success', true,
        'data', json_build_object(
            'lesson_id', p_lesson_id,
            'overview', json_build_object(
                'total_students', COALESCE(v_total_students, 0),
                'total_cards', COALESCE(v_total_cards, 0),
                'approved_cards', COALESCE(v_approved_cards, 0),
                'pending_cards', COALESCE(v_pending_cards, 0)
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
COMMENT ON FUNCTION get_lesson_analytics IS 'Gets comprehensive analytics for a lesson (FIXED FULL JOIN VERSION)';