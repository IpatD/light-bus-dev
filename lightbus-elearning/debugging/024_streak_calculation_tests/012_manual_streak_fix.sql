-- =============================================================================
-- TEST 012: MANUAL STREAK FIX
-- =============================================================================
-- Manually fix the streak for our test student using the new function
-- Student ID: 46246124-a43f-4980-b05e-97670eed3f32

-- Run the manual streak fix function
SELECT 
    'Manual Streak Fix Results' as test_section,
    lesson_id,
    old_streak,
    new_streak,
    last_review_date,
    today_reviews
FROM public.fix_student_streak_manual('46246124-a43f-4980-b05e-97670eed3f32'::UUID, 'Europe/Warsaw');