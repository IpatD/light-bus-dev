-- =============================================================================
-- DEBUGGING SESSION 007: TODAY'S STATS FUNCTION COMPARISON
-- =============================================================================
-- 
-- Student ID: 46246124-a43f-4980-b05e-97670eed3f32
-- Date: 2025-06-07
-- Purpose: Compare original vs timezone-aware today's study stats functions
-- =============================================================================

-- First, let's check what get_today_study_stats functions exist
SELECT 
    '=== AVAILABLE get_today_study_stats FUNCTIONS ===' as section,
    proname as function_name,
    pg_get_function_arguments(oid) as arguments,
    pg_get_function_result(oid) as return_type
FROM pg_proc 
WHERE proname LIKE 'get_today_study_stats%' 
ORDER BY proname, pg_get_function_arguments(oid);

-- Try the original function with explicit timezone parameter
SELECT 
    '=== ORIGINAL get_today_study_stats() WITH TIMEZONE ===' as section,
    'get_today_study_stats (with timezone)' as function_type,
    cards_studied_today,
    total_cards_ready,
    study_time_minutes,
    sessions_completed,
    new_cards_accepted_today,
    cards_mastered_today
FROM public.get_today_study_stats('46246124-a43f-4980-b05e-97670eed3f32'::UUID, 'Europe/Warsaw');

-- Try the new timezone-aware function (if it exists)
SELECT 
    '=== TIMEZONE-AWARE get_today_study_stats_with_timezone() ===' as section,
    'get_today_study_stats_with_timezone' as function_type,
    cards_studied_today,
    total_cards_ready,
    study_time_minutes,
    sessions_completed,
    new_cards_accepted_today,
    cards_mastered_today
FROM public.get_today_study_stats_with_timezone('46246124-a43f-4980-b05e-97670eed3f32'::UUID, 'Europe/Warsaw');