-- =============================================================================
-- TEST 010: CHECK TODAY STATUS
-- =============================================================================
-- Check if student has any activity today
-- Student ID: 46246124-a43f-4980-b05e-97670eed3f32

-- Check if student has completed any reviews today
SELECT 
    'Reviews Completed Today' as test_section,
    COUNT(r.id) as reviews_today,
    MIN(r.completed_at) as first_review_today,
    MAX(r.completed_at) as last_review_today,
    CURRENT_DATE AT TIME ZONE 'Europe/Warsaw' as today_in_timezone
FROM public.sr_reviews r
WHERE r.student_id = '46246124-a43f-4980-b05e-97670eed3f32'::UUID
  AND r.completed_at IS NOT NULL
  AND DATE(r.completed_at AT TIME ZONE 'Europe/Warsaw') = CURRENT_DATE AT TIME ZONE 'Europe/Warsaw';