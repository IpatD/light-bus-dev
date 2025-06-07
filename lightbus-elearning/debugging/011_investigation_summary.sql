-- =============================================================================
-- DEBUGGING SESSION 011: INVESTIGATION SUMMARY
-- =============================================================================
-- 
-- Student ID: 46246124-a43f-4980-b05e-97670eed3f32
-- Date: 2025-06-07
-- Purpose: Summary of all key metrics and potential issues
-- =============================================================================

-- 11. INVESTIGATION SUMMARY
SELECT 
    '=== INVESTIGATION SUMMARY ===' as section,
    (SELECT COUNT(*) FROM public.lesson_participants WHERE student_id = '46246124-a43f-4980-b05e-97670eed3f32') as total_lessons_enrolled,
    (SELECT COUNT(DISTINCT r.card_id) FROM public.sr_reviews r WHERE r.student_id = '46246124-a43f-4980-b05e-97670eed3f32') as total_cards_ever_studied,
    (SELECT COUNT(*) FROM public.sr_reviews r WHERE r.student_id = '46246124-a43f-4980-b05e-97670eed3f32' AND r.completed_at IS NOT NULL) as total_completed_reviews,
    (SELECT COUNT(*) FROM public.sr_reviews r WHERE r.student_id = '46246124-a43f-4980-b05e-97670eed3f32' AND r.completed_at IS NULL) as total_pending_reviews,
    (SELECT COUNT(*) FROM public.sr_progress WHERE student_id = '46246124-a43f-4980-b05e-97670eed3f32') as progress_records_count,
    -- Timezone mismatch count
    (
        SELECT COUNT(*)
        FROM public.sr_reviews r
        WHERE r.student_id = '46246124-a43f-4980-b05e-97670eed3f32'
          AND r.completed_at IS NOT NULL
          AND r.completed_at::DATE != (r.completed_at AT TIME ZONE 'Europe/Warsaw')::DATE
    ) as timezone_date_mismatches,
    -- Recent activity (last 7 days)
    (
        SELECT COUNT(*)
        FROM public.sr_reviews r
        WHERE r.student_id = '46246124-a43f-4980-b05e-97670eed3f32'
          AND r.completed_at IS NOT NULL
          AND r.completed_at >= NOW() - INTERVAL '7 days'
    ) as reviews_last_7_days,
    -- Due cards count
    (
        SELECT COUNT(*)
        FROM public.sr_reviews r
        WHERE r.student_id = '46246124-a43f-4980-b05e-97670eed3f32'
          AND r.completed_at IS NULL
          AND r.scheduled_for <= NOW()
    ) as cards_due_now_utc,
    (
        SELECT COUNT(*)
        FROM public.sr_reviews r
        WHERE r.student_id = '46246124-a43f-4980-b05e-97670eed3f32'
          AND r.completed_at IS NULL
          AND (r.scheduled_for AT TIME ZONE 'Europe/Warsaw')::DATE <= (NOW() AT TIME ZONE 'Europe/Warsaw')::DATE
    ) as cards_due_now_warsaw;