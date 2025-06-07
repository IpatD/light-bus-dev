-- =============================================================================
-- TEST 007: TEST DIRECT USER STATS FUNCTION
-- =============================================================================
-- Test the direct get_user_stats function (without wrapper)
-- Student ID: 46246124-a43f-4980-b05e-97670eed3f32

-- Test get_user_stats function directly
SELECT 
    'get_user_stats Results (Direct)' as test_section,
    total_reviews,
    average_quality,
    study_streak,
    cards_learned,
    cards_due_today,
    next_review_date,
    weekly_progress,
    monthly_progress,
    total_lessons,
    lessons_with_progress
FROM public.get_user_stats('46246124-a43f-4980-b05e-97670eed3f32'::UUID, 'Europe/Warsaw');