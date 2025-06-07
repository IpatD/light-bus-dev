-- =============================================================================
-- TEST 003: LESSON PARTICIPATION
-- =============================================================================
-- Check lesson participation for our test student
-- Student ID: 46246124-a43f-4980-b05e-97670eed3f32

-- Check lesson participation
SELECT 
    'Lesson Participation' as test_section,
    lp.lesson_id,
    l.name as lesson_name,
    l.teacher_id,
    lp.enrolled_at
FROM public.lesson_participants lp
JOIN public.lessons l ON lp.lesson_id = l.id
WHERE lp.student_id = '46246124-a43f-4980-b05e-97670eed3f32'::UUID
ORDER BY lp.enrolled_at DESC;