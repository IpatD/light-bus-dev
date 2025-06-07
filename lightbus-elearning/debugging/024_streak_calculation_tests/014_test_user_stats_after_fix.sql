-- =============================================================================
-- TEST 014: TEST USER STATS AFTER FIX
-- =============================================================================
-- Check if get_user_stats_with_timezone returns updated streak
-- Student ID: 46246124-a43f-4980-b05e-97670eed3f32

-- Test get_user_stats_with_timezone function after manual fix
SELECT 
    'User Stats After Fix' as test_section,
    total_reviews,
    average_quality,
    study_streak,
    cards_learned,
    cards_due_today,
    next_review_date,
    weekly_progress
FROM public.get_user_stats_with_timezone('46246124-a43f-4980-b05e-97670eed3f32'::UUID, 'Europe/Warsaw');