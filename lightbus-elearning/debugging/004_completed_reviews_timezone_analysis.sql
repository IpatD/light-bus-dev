-- =============================================================================
-- DEBUGGING SESSION 004: COMPLETED REVIEWS TIMEZONE ANALYSIS
-- =============================================================================
-- 
-- Student ID: 46246124-a43f-4980-b05e-97670eed3f32
-- Date: 2025-06-07
-- Purpose: Analyze completed reviews with timezone comparisons
-- =============================================================================

-- 4. COMPLETED REVIEWS ANALYSIS WITH TIMEZONE INFO
SELECT 
    '=== COMPLETED REVIEWS ANALYSIS ===' as section,
    r.id as review_id,
    r.card_id,
    sc.front_content as card_front,
    l.name as lesson_name,
    r.completed_at as completed_at_utc,
    r.completed_at AT TIME ZONE 'Europe/Warsaw' as completed_at_warsaw,
    r.completed_at::DATE as completed_date_utc,
    (r.completed_at AT TIME ZONE 'Europe/Warsaw')::DATE as completed_date_warsaw,
    r.quality_rating,
    r.response_time_ms,
    r.interval_days,
    r.ease_factor,
    r.repetition_count,
    r.card_status,
    -- Check if dates differ between UTC and Warsaw timezone
    CASE 
        WHEN r.completed_at::DATE != (r.completed_at AT TIME ZONE 'Europe/Warsaw')::DATE 
        THEN 'DATE_MISMATCH' 
        ELSE 'DATE_ALIGNED' 
    END as timezone_date_status
FROM public.sr_reviews r
INNER JOIN public.sr_cards sc ON r.card_id = sc.id
INNER JOIN public.lessons l ON sc.lesson_id = l.id
WHERE r.student_id = '46246124-a43f-4980-b05e-97670eed3f32'
  AND r.completed_at IS NOT NULL
ORDER BY r.completed_at DESC
LIMIT 20;