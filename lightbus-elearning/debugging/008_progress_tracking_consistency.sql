-- =============================================================================
-- DEBUGGING SESSION 008: PROGRESS TRACKING CONSISTENCY ANALYSIS
-- =============================================================================
-- 
-- Student ID: 46246124-a43f-4980-b05e-97670eed3f32
-- Date: 2025-06-07
-- Purpose: Analyze progress table vs actual review data consistency
-- =============================================================================

-- 8. PROGRESS TRACKING TABLE ANALYSIS
SELECT 
    '=== PROGRESS TRACKING TABLE ANALYSIS ===' as section,
    sp.lesson_id,
    l.name as lesson_name,
    sp.cards_total,
    sp.cards_reviewed,
    sp.cards_learned,
    sp.average_quality,
    sp.study_streak,
    sp.last_review_date as progress_last_review_date,
    sp.next_review_date as progress_next_review_date,
    sp.created_at as progress_created,
    sp.updated_at as progress_updated,
    -- Compare with actual review data
    (
        SELECT MAX(r.completed_at)::DATE
        FROM public.sr_reviews r
        INNER JOIN public.sr_cards sc ON r.card_id = sc.id
        WHERE r.student_id = '46246124-a43f-4980-b05e-97670eed3f32'
          AND sc.lesson_id = sp.lesson_id
          AND r.completed_at IS NOT NULL
    ) as actual_last_review_date_utc,
    (
        SELECT MAX(r.completed_at AT TIME ZONE 'Europe/Warsaw')::DATE
        FROM public.sr_reviews r
        INNER JOIN public.sr_cards sc ON r.card_id = sc.id
        WHERE r.student_id = '46246124-a43f-4980-b05e-97670eed3f32'
          AND sc.lesson_id = sp.lesson_id
          AND r.completed_at IS NOT NULL
    ) as actual_last_review_date_warsaw,
    -- Check for inconsistencies
    CASE 
        WHEN sp.last_review_date != (
            SELECT MAX(r.completed_at)::DATE
            FROM public.sr_reviews r
            INNER JOIN public.sr_cards sc ON r.card_id = sc.id
            WHERE r.student_id = '46246124-a43f-4980-b05e-97670eed3f32'
              AND sc.lesson_id = sp.lesson_id
              AND r.completed_at IS NOT NULL
        ) THEN 'INCONSISTENT_UTC'
        WHEN sp.last_review_date != (
            SELECT MAX(r.completed_at AT TIME ZONE 'Europe/Warsaw')::DATE
            FROM public.sr_reviews r
            INNER JOIN public.sr_cards sc ON r.card_id = sc.id
            WHERE r.student_id = '46246124-a43f-4980-b05e-97670eed3f32'
              AND sc.lesson_id = sp.lesson_id
              AND r.completed_at IS NOT NULL
        ) THEN 'INCONSISTENT_WARSAW'
        ELSE 'CONSISTENT'
    END as consistency_status
FROM public.sr_progress sp
INNER JOIN public.lessons l ON sp.lesson_id = l.id
WHERE sp.student_id = '46246124-a43f-4980-b05e-97670eed3f32'
ORDER BY sp.updated_at DESC;