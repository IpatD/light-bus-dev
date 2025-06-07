-- =============================================================================
-- DEBUGGING SESSION 020: INVESTIGATE STREAK DATA SOURCES
-- =============================================================================
-- 
-- Student ID: 46246124-a43f-4980-b05e-97670eed3f32
-- Date: 2025-06-07
-- Purpose: Find where longest streak data might be stored
-- Issue: Backend functions don't return longest_streak field
-- =============================================================================

-- 1. Check what's in the daily_study_stats table (might have historical streaks)
SELECT 
    'daily_study_stats analysis' as section,
    study_date,
    cards_reviewed,
    study_streak,
    CASE WHEN cards_reviewed > 0 THEN 'Active' ELSE 'Inactive' END as activity_status
FROM daily_study_stats 
WHERE student_id = '46246124-a43f-4980-b05e-97670eed3f32'::UUID
ORDER BY study_date DESC
LIMIT 20;

-- 2. Check if there's a max streak in daily_study_stats
SELECT 
    'max streak from daily_study_stats' as section,
    MAX(study_streak) as max_streak_recorded,
    COUNT(*) as total_days_recorded,
    COUNT(CASE WHEN cards_reviewed > 0 THEN 1 END) as active_days,
    MIN(study_date) as earliest_record,
    MAX(study_date) as latest_record
FROM daily_study_stats 
WHERE student_id = '46246124-a43f-4980-b05e-97670eed3f32'::UUID;

-- 3. Let's see what the current user stats functions actually return
SELECT 
    'current function output analysis' as section,
    *
FROM public.get_user_stats_with_timezone('46246124-a43f-4980-b05e-97670eed3f32'::UUID, 'Europe/Warsaw');

-- 4. Check if there's streak data in sr_progress table
SELECT 
    'sr_progress streak data' as section,
    lesson_id,
    study_streak,
    last_review_date,
    next_review_date
FROM sr_progress 
WHERE student_id = '46246124-a43f-4980-b05e-97670eed3f32'::UUID
ORDER BY study_streak DESC;

-- 5. Let's manually calculate longest streak from daily_study_stats
WITH daily_activity AS (
    SELECT 
        study_date,
        CASE WHEN cards_reviewed > 0 THEN 1 ELSE 0 END as active_day,
        ROW_NUMBER() OVER (ORDER BY study_date) as day_number
    FROM daily_study_stats 
    WHERE student_id = '46246124-a43f-4980-b05e-97670eed3f32'::UUID
    ORDER BY study_date
),
streak_groups AS (
    SELECT 
        study_date,
        active_day,
        day_number - ROW_NUMBER() OVER (PARTITION BY active_day ORDER BY study_date) as streak_group
    FROM daily_activity
    WHERE active_day = 1  -- Only active days
),
streak_lengths AS (
    SELECT 
        streak_group,
        COUNT(*) as streak_length,
        MIN(study_date) as streak_start,
        MAX(study_date) as streak_end
    FROM streak_groups
    GROUP BY streak_group
)
SELECT 
    'calculated longest streak from history' as section,
    MAX(streak_length) as longest_streak_calculated,
    streak_start,
    streak_end
FROM streak_lengths
ORDER BY streak_length DESC
LIMIT 1;

-- 6. Check current streak calculation method
SELECT 
    'current streak verification' as section,
    study_date,
    cards_reviewed,
    study_streak,
    CASE 
        WHEN study_date = CURRENT_DATE THEN 'Today'
        WHEN study_date = CURRENT_DATE - INTERVAL '1 day' THEN 'Yesterday'
        ELSE 'Earlier'
    END as relative_date
FROM daily_study_stats 
WHERE student_id = '46246124-a43f-4980-b05e-97670eed3f32'::UUID
    AND study_date >= CURRENT_DATE - INTERVAL '10 days'
ORDER BY study_date DESC;