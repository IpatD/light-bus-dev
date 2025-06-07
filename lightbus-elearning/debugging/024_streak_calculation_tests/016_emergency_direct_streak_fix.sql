-- =============================================================================
-- EMERGENCY DIRECT STREAK FIX
-- =============================================================================
-- Direct database update to fix streak for student who has completed reviews today
-- Student ID: 46246124-a43f-4980-b05e-97670eed3f32

-- Step 1: Check current state before fix
SELECT 
    'BEFORE FIX - Current Progress State' as section,
    sp.lesson_id,
    sp.study_streak as current_streak,
    sp.last_review_date,
    sp.cards_reviewed,
    COUNT(r.id) as reviews_today
FROM public.sr_progress sp
LEFT JOIN public.sr_reviews r ON r.student_id = sp.student_id
LEFT JOIN public.sr_cards c ON r.card_id = c.id AND c.lesson_id = sp.lesson_id
WHERE sp.student_id = '46246124-a43f-4980-b05e-97670eed3f32'::UUID
  AND (r.id IS NULL OR (
    r.completed_at IS NOT NULL 
    AND DATE(r.completed_at AT TIME ZONE 'Europe/Warsaw') = CURRENT_DATE AT TIME ZONE 'Europe/Warsaw'
  ))
GROUP BY sp.lesson_id, sp.study_streak, sp.last_review_date, sp.cards_reviewed
ORDER BY sp.lesson_id;

-- Step 2: Apply direct fix
UPDATE public.sr_progress 
SET 
    study_streak = 1,
    last_review_date = (CURRENT_DATE AT TIME ZONE 'Europe/Warsaw')::DATE,
    updated_at = NOW()
WHERE student_id = '46246124-a43f-4980-b05e-97670eed3f32'::UUID
  AND EXISTS (
    SELECT 1 FROM public.sr_reviews r
    INNER JOIN public.sr_cards c ON r.card_id = c.id
    WHERE r.student_id = '46246124-a43f-4980-b05e-97670eed3f32'::UUID
      AND c.lesson_id = sr_progress.lesson_id
      AND r.completed_at IS NOT NULL
      AND DATE(r.completed_at AT TIME ZONE 'Europe/Warsaw') = (CURRENT_DATE AT TIME ZONE 'Europe/Warsaw')::DATE
  );

-- Step 3: Verify the fix was applied
SELECT 
    'AFTER FIX - Updated Progress State' as section,
    sp.lesson_id,
    sp.study_streak as updated_streak,
    sp.last_review_date,
    sp.updated_at,
    COUNT(r.id) as reviews_today_count
FROM public.sr_progress sp
LEFT JOIN public.sr_reviews r ON r.student_id = sp.student_id
LEFT JOIN public.sr_cards c ON r.card_id = c.id AND c.lesson_id = sp.lesson_id
WHERE sp.student_id = '46246124-a43f-4980-b05e-97670eed3f32'::UUID
  AND (r.id IS NULL OR (
    r.completed_at IS NOT NULL 
    AND DATE(r.completed_at AT TIME ZONE 'Europe/Warsaw') = CURRENT_DATE AT TIME ZONE 'Europe/Warsaw'
  ))
GROUP BY sp.lesson_id, sp.study_streak, sp.last_review_date, sp.updated_at
ORDER BY sp.lesson_id;

-- Step 4: Test get_user_stats function
SELECT 
    'USER STATS FUNCTION TEST' as section,
    study_streak,
    total_reviews,
    cards_learned,
    weekly_progress
FROM public.get_user_stats_with_timezone('46246124-a43f-4980-b05e-97670eed3f32'::UUID, 'Europe/Warsaw');