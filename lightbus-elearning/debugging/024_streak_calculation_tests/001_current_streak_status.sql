-- =============================================================================
-- TEST 001: CURRENT STREAK STATUS
-- =============================================================================
-- Check the current streak status for our test student
-- Student ID: 46246124-a43f-4980-b05e-97670eed3f32

-- 1. Check current progress records
SELECT 
    'Current Progress Records' as test_section,
    sp.lesson_id,
    sp.study_streak,
    sp.last_review_date,
    sp.cards_reviewed,
    sp.cards_learned,
    sp.average_quality,
    sp.next_review_date,
    sp.created_at,
    sp.updated_at
FROM public.sr_progress sp
WHERE sp.student_id = '46246124-a43f-4980-b05e-97670eed3f32'::UUID
ORDER BY sp.updated_at DESC;