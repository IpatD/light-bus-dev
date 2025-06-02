-- Enable teachers to delete their own lessons
-- This extends the existing RLS policies to allow lesson owners to delete

-- Add policy for teachers to delete their own lessons
CREATE POLICY "Teachers can delete their own lessons" ON public.lessons
    FOR DELETE USING (teacher_id = auth.uid());

-- Create function to safely delete a lesson with proper validation
CREATE OR REPLACE FUNCTION public.delete_lesson(
    p_lesson_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_result JSON;
    v_lesson_record RECORD;
    v_user_id UUID;
    v_user_role TEXT;
BEGIN
    -- Get current user
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Authentication required'
        );
    END IF;

    -- Get user role
    SELECT role INTO v_user_role
    FROM public.profiles
    WHERE id = v_user_id;

    IF v_user_role IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'User profile not found'
        );
    END IF;

    -- Check if lesson exists and get lesson details
    SELECT * INTO v_lesson_record
    FROM public.lessons
    WHERE id = p_lesson_id;

    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Lesson not found'
        );
    END IF;

    -- Check permissions: only lesson owner (teacher) or admin can delete
    IF v_lesson_record.teacher_id != v_user_id AND v_user_role != 'admin' THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Permission denied. You can only delete lessons you created.'
        );
    END IF;

    -- Check if lesson has active students (optional safety check)
    -- This gives teachers a warning but doesn't prevent deletion
    DECLARE
        v_student_count INTEGER;
    BEGIN
        SELECT COUNT(*) INTO v_student_count
        FROM public.lesson_participants
        WHERE lesson_id = p_lesson_id;
    END;

    -- Perform the deletion
    -- The CASCADE DELETE will handle related records automatically
    DELETE FROM public.lessons
    WHERE id = p_lesson_id;

    -- Return success with lesson info
    RETURN json_build_object(
        'success', true,
        'message', 'Lesson deleted successfully',
        'data', json_build_object(
            'lesson_id', p_lesson_id,
            'lesson_name', v_lesson_record.name,
            'student_count', v_student_count
        )
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Failed to delete lesson: ' || SQLERRM
        );
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.delete_lesson(UUID) TO authenticated;

-- Add comment for documentation
COMMENT ON FUNCTION public.delete_lesson(UUID) IS 'Safely delete a lesson with proper authorization checks. Only lesson owners (teachers) and admins can delete lessons.';