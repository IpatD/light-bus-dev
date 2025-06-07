-- =============================================================================
-- TEST 004: REVIEW HISTORY
-- =============================================================================
-- Check review history for our test student
-- Student ID: 46246124-a43f-4980-b05e-97670eed3f32

-- Check total completed reviews
SELECT 
    'Total Completed Reviews' as test_section,
    COUNT(*) as total_reviews,
    COUNT(CASE WHEN r.completed_at IS NOT NULL THEN 1 END) as completed_reviews,
    MIN(r.completed_at) as first_review,
    MAX(r.completed_at) as latest_review
FROM public.sr_reviews r
WHERE r.student_id = '46246124-a43f-4980-b05e-97670eed3f32'::UUID;