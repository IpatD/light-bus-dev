-- =============================================================================
-- DEBUG AND FIX STREAK CALCULATION
-- =============================================================================
-- This script helps debug and fix streak calculation issues

-- 1. Check current streak data for all users
SELECT 
    'Current Streak Data' as section,
    p.name as student_name,
    sp.study_streak,
    sp.last_review_date,
    sp.cards_reviewed,
    COUNT(r.id) as actual_reviews_completed
FROM public.sr_progress sp
JOIN public.profiles p ON sp.student_id = p.id
LEFT JOIN public.sr_reviews r ON r.student_id = sp.student_id
LEFT JOIN public.sr_cards c ON r.card_id = c.id AND c.lesson_id = sp.lesson_id
WHERE r.completed_at IS NOT NULL
GROUP BY p.name, sp.study_streak, sp.last_review_date, sp.cards_reviewed
ORDER BY p.name;

-- 2. Check if users have completed reviews today
SELECT 
    'Reviews Completed Today' as section,
    p.name as student_name,
    COUNT(r.id) as reviews_today,
    MIN(r.completed_at) as first_review_today,
    MAX(r.completed_at) as last_review_today
FROM public.profiles p
LEFT JOIN public.sr_reviews r ON r.student_id = p.id
WHERE r.completed_at IS NOT NULL
  AND DATE(r.completed_at AT TIME ZONE 'Europe/Warsaw') = CURRENT_DATE AT TIME ZONE 'Europe/Warsaw'
GROUP BY p.name
HAVING COUNT(r.id) > 0
ORDER BY p.name;

-- 3. Run the streak recalculation function
SELECT 
    'Running Streak Recalculation' as section,
    'This will fix any incorrect streaks' as description;

-- Execute the recalculation function
SELECT * FROM recalculate_all_streaks('Europe/Warsaw');

-- 4. Check streak data after recalculation
SELECT 
    'Streak Data After Recalculation' as section,
    p.name as student_name,
    sp.study_streak,
    sp.last_review_date,
    sp.cards_reviewed
FROM public.sr_progress sp
JOIN public.profiles p ON sp.student_id = p.id
ORDER BY p.name;

-- 5. Manually trigger a study session for testing (if needed)
-- Replace with actual user and card IDs
/*
SELECT 
    'Manual Study Session Test' as section,
    'Triggering a review for testing' as description;

-- Get a test user and card
DO $$
DECLARE
    test_user_id UUID;
    test_card_id UUID;
BEGIN
    -- Get first available user
    SELECT id INTO test_user_id FROM public.profiles WHERE role = 'student' LIMIT 1;
    
    -- Get first available card for that user
    SELECT c.id INTO test_card_id 
    FROM public.sr_cards c
    JOIN public.lesson_participants lp ON c.lesson_id = lp.lesson_id
    WHERE lp.student_id = test_user_id 
      AND c.status = 'approved'
    LIMIT 1;
    
    IF test_user_id IS NOT NULL AND test_card_id IS NOT NULL THEN
        -- Trigger a review
        PERFORM record_sr_review(test_user_id, test_card_id, 4, 5000, 'Europe/Warsaw');
        RAISE NOTICE 'Test review recorded for user % and card %', test_user_id, test_card_id;
    ELSE
        RAISE NOTICE 'No suitable test user or card found';
    END IF;
END $$;
*/

-- 6. Check final results
SELECT 
    'Final Verification' as section,
    p.name as student_name,
    sp.study_streak as current_streak,
    sp.last_review_date,
    CASE 
        WHEN sp.last_review_date = CURRENT_DATE AT TIME ZONE 'Europe/Warsaw' 
        THEN 'Studied today ✓'
        ELSE 'No study today'
    END as today_status
FROM public.sr_progress sp
JOIN public.profiles p ON sp.student_id = p.id
ORDER BY sp.study_streak DESC, p.name;