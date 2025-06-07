-- =============================================================================
-- DEBUGGING SESSION 006: USER STATS FUNCTION COMPARISON
-- =============================================================================
-- 
-- Student ID: 46246124-a43f-4980-b05e-97670eed3f32
-- Date: 2025-06-07
-- Purpose: Compare original vs timezone-aware user stats functions
-- =============================================================================

-- SAFE ORIGINAL FUNCTION (single parameter)
SELECT 
    '=== ORIGINAL get_user_stats_safe() ===' as section,
    'get_user_stats_safe (single param)' as function_type,
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
FROM public.get_user_stats_safe('46246124-a43f-4980-b05e-97670eed3f32'::UUID);

-- ORIGINAL FUNCTION WITH EXPLICIT TIMEZONE (default timezone)
SELECT 
    '=== ORIGINAL get_user_stats() WITH DEFAULT TIMEZONE ===' as section,
    'get_user_stats (with default timezone)' as function_type,
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

-- NEW TIMEZONE-AWARE FUNCTION
SELECT 
    '=== TIMEZONE-AWARE get_user_stats_with_timezone() ===' as section,
    'get_user_stats_with_timezone' as function_type,
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