-- =============================================================================
-- DEBUGGING SESSION 002: LESSON PARTICIPATION INVESTIGATION
-- =============================================================================
-- 
-- Student ID: 46246124-a43f-4980-b05e-97670eed3f32
-- Date: 2025-06-07
-- Purpose: Investigate student's lesson participation and enrollment
-- =============================================================================

-- 2. STUDENT'S LESSON PARTICIPATION
SELECT 
    '=== LESSON PARTICIPATION ===' as section,
    l.id as lesson_id,
    l.name as lesson_name,
    l.scheduled_at as lesson_scheduled,
    teacher.name as teacher_name,
    lp.enrolled_at as student_enrolled_date,
    COUNT(sc.id) as total_cards_in_lesson
FROM public.lesson_participants lp
INNER JOIN public.lessons l ON lp.lesson_id = l.id
INNER JOIN public.profiles teacher ON l.teacher_id = teacher.id
LEFT JOIN public.sr_cards sc ON l.id = sc.lesson_id AND sc.status = 'approved'
WHERE lp.student_id = '46246124-a43f-4980-b05e-97670eed3f32'
GROUP BY l.id, l.name, l.scheduled_at, teacher.name, lp.enrolled_at
ORDER BY lp.enrolled_at DESC;