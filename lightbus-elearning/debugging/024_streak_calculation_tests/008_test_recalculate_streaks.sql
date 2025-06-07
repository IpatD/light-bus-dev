-- =============================================================================
-- TEST 008: TEST RECALCULATE STREAKS FUNCTION
-- =============================================================================
-- Test the recalculate_all_streaks function to fix any streak issues
-- Student ID: 46246124-a43f-4980-b05e-97670eed3f32

-- Run the streak recalculation function
SELECT 
    'Recalculate Streaks Results' as test_section,
    student_id,
    lesson_id,
    old_streak,
    new_streak,
    last_review_date
FROM public.recalculate_all_streaks('Europe/Warsaw')
WHERE student_id = '46246124-a43f-4980-b05e-97670eed3f32'::UUID;