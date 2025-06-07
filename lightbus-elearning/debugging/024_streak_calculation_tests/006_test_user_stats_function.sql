-- =============================================================================
-- TEST 006: TEST USER STATS FUNCTION
-- =============================================================================
-- Test the get_user_stats_with_timezone function
-- Student ID: 46246124-a43f-4980-b05e-97670eed3f32

-- Test get_user_stats_with_timezone function
SELECT 
    'get_user_stats_with_timezone Results' as test_section,
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
FROM public.get_user_stats_with_timezone('46246124-a43f-4980-b05e-97670eed3f32'::UUID, 'Europe/Warsaw');