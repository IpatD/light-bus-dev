-- =============================================================================
-- TEST 005: REVIEWS BY DATE
-- =============================================================================
-- Check reviews by date for our test student (last 7 days)
-- Student ID: 46246124-a43f-4980-b05e-97670eed3f32

-- Check reviews by date (last 7 days)
SELECT 
    'Reviews by Date (Last 7 Days)' as test_section,
    DATE(r.completed_at AT TIME ZONE 'Europe/Warsaw') as review_date,
    COUNT(*) as reviews_count,
    AVG(r.quality_rating) as avg_quality,
    STRING_AGG(r.quality_rating::TEXT, ', ') as quality_ratings
FROM public.sr_reviews r
WHERE r.student_id = '46246124-a43f-4980-b05e-97670eed3f32'::UUID
  AND r.completed_at IS NOT NULL
  AND r.completed_at >= NOW() - INTERVAL '7 days'
GROUP BY DATE(r.completed_at AT TIME ZONE 'Europe/Warsaw')
ORDER BY review_date DESC;