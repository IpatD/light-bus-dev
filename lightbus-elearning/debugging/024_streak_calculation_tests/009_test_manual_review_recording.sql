-- =============================================================================
-- TEST 009: TEST MANUAL REVIEW RECORDING
-- =============================================================================
-- Test recording a manual review to see if streak calculation works
-- Student ID: 46246124-a43f-4980-b05e-97670eed3f32

-- First, find an available card for this student
SELECT 
    'Available Cards for Testing' as test_section,
    c.id as card_id,
    c.lesson_id,
    c.front_content,
    c.status,
    l.name as lesson_name
FROM public.sr_cards c
JOIN public.lessons l ON c.lesson_id = l.id
JOIN public.lesson_participants lp ON l.id = lp.lesson_id
WHERE lp.student_id = '46246124-a43f-4980-b05e-97670eed3f32'::UUID
  AND c.status = 'approved'
LIMIT 5;