-- Migration: Fix get_available_students function SQL error
-- File: 012_fix_get_students_function.sql
-- Purpose: Fix GROUP BY clause error in get_available_students function

-- Drop and recreate the function with correct SQL syntax
DROP FUNCTION IF EXISTS get_available_students(TEXT, INTEGER);

-- Function: get_available_students (fixed version)
-- Returns list of students for teacher to select from when creating lessons
CREATE OR REPLACE FUNCTION get_available_students(
    p_search_term TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 50
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
    
    -- Validate user is a teacher
    IF NOT EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE id = v_teacher_id AND role = 'teacher'
    ) THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Access denied. Only teachers can fetch students.'
        );
    END IF;
    
    -- Build result with students list using subquery to avoid GROUP BY issues
    SELECT json_build_object(
        'success', true,
        'data', COALESCE(json_agg(
            json_build_object(
                'id', student_data.id,
                'name', student_data.name,
                'email', student_data.email,
                'created_at', student_data.created_at
            ) ORDER BY student_data.name ASC
        ), '[]'::json)
    )
    INTO v_result
    FROM (
        SELECT p.id, p.name, p.email, p.created_at
        FROM public.profiles p
        WHERE p.role = 'student'
            AND (
                p_search_term IS NULL 
                OR p.name ILIKE '%' || p_search_term || '%'
                OR p.email ILIKE '%' || p_search_term || '%'
            )
        ORDER BY p.name ASC
        LIMIT p_limit
    ) AS student_data;
    
    RETURN v_result;
END;
$$;

-- Also fix the get_lesson_students function
DROP FUNCTION IF EXISTS get_lesson_students(UUID);

-- Function: get_lesson_students (fixed version)
-- Returns students enrolled in a specific lesson
CREATE OR REPLACE FUNCTION get_lesson_students(
    p_lesson_id UUID
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
    
    -- Validate user owns the lesson or is admin
    IF NOT EXISTS (
        SELECT 1 FROM public.lessons 
        WHERE id = p_lesson_id 
        AND (teacher_id = v_teacher_id OR EXISTS (
            SELECT 1 FROM public.profiles 
            WHERE id = v_teacher_id AND role = 'admin'
        ))
    ) THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Lesson not found or access denied'
        );
    END IF;
    
    -- Build result with enrolled students using subquery
    SELECT json_build_object(
        'success', true,
        'data', COALESCE(json_agg(
            json_build_object(
                'id', enrolled_data.id,
                'name', enrolled_data.name,
                'email', enrolled_data.email,
                'enrolled_at', enrolled_data.enrolled_at
            ) ORDER BY enrolled_data.enrolled_at ASC
        ), '[]'::json)
    )
    INTO v_result
    FROM (
        SELECT p.id, p.name, p.email, lp.enrolled_at
        FROM public.lesson_participants lp
        JOIN public.profiles p ON lp.student_id = p.id
        WHERE lp.lesson_id = p_lesson_id
        ORDER BY lp.enrolled_at ASC
    ) AS enrolled_data;
    
    RETURN v_result;
END;
$$;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION get_available_students TO authenticated;
GRANT EXECUTE ON FUNCTION get_lesson_students TO authenticated;

-- Add helpful comments
COMMENT ON FUNCTION get_available_students IS 'Fetches available students for lesson creation with optional search and limit (FIXED VERSION)';
COMMENT ON FUNCTION get_lesson_students IS 'Returns students enrolled in a specific lesson (FIXED VERSION)';