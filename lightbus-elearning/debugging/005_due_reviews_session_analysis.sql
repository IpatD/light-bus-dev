-- =============================================================================
-- DEBUGGING SESSION 005: DUE REVIEWS SESSION ANALYSIS
-- =============================================================================
-- 
-- Student ID: 46246124-a43f-4980-b05e-97670eed3f32
-- Date: 2025-06-07
-- Purpose: Analyze due reviews and scheduling with timezone considerations
-- =============================================================================

-- 5. DUE REVIEWS SESSION ANALYSIS
SELECT 
    '=== DUE REVIEWS SESSION ANALYSIS ===' as section,
    r.id as review_id,
    r.card_id,
    sc.front_content as card_front,
    l.name as lesson_name,
    r.scheduled_for as scheduled_for_utc,
    r.scheduled_for AT TIME ZONE 'Europe/Warsaw' as scheduled_for_warsaw,
    r.scheduled_for::DATE as scheduled_date_utc,
    (r.scheduled_for AT TIME ZONE 'Europe/Warsaw')::DATE as scheduled_date_warsaw,
    CURRENT_DATE as today_utc,
    (NOW() AT TIME ZONE 'Europe/Warsaw')::DATE as today_warsaw,
    r.interval_days,
    r.ease_factor,
    r.repetition_count,
    r.card_status,
    -- Check if card is due today in different timezones
    CASE 
        WHEN r.scheduled_for::DATE <= CURRENT_DATE THEN 'DUE_UTC'
        ELSE 'NOT_DUE_UTC'
    END as due_status_utc,
    CASE 
        WHEN (r.scheduled_for AT TIME ZONE 'Europe/Warsaw')::DATE <= (NOW() AT TIME ZONE 'Europe/Warsaw')::DATE 
        THEN 'DUE_WARSAW'
        ELSE 'NOT_DUE_WARSAW'
    END as due_status_warsaw,
    -- Days until due
    r.scheduled_for::DATE - CURRENT_DATE as days_until_due_utc,
    (r.scheduled_for AT TIME ZONE 'Europe/Warsaw')::DATE - (NOW() AT TIME ZONE 'Europe/Warsaw')::DATE as days_until_due_warsaw
FROM public.sr_reviews r
INNER JOIN public.sr_cards sc ON r.card_id = sc.id
INNER JOIN public.lessons l ON sc.lesson_id = l.id
WHERE r.student_id = '46246124-a43f-4980-b05e-97670eed3f32'
  AND r.completed_at IS NULL
ORDER BY r.scheduled_for ASC;