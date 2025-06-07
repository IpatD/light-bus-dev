-- =============================================================================
-- TEST 013: VERIFY AFTER FIX
-- =============================================================================
-- Check the streak status after running the manual fix
-- Student ID: 46246124-a43f-4980-b05e-97670eed3f32

-- Check current progress records after fix
SELECT 
    'Progress After Manual Fix' as test_section,
    sp.lesson_id,
    sp.study_streak,
    sp.last_review_date,
    sp.cards_reviewed,
    sp.updated_at
FROM public.sr_progress sp
WHERE sp.student_id = '46246124-a43f-4980-b05e-97670eed3f32'::UUID
ORDER BY sp.updated_at DESC;