-- =============================================================================
-- DEBUGGING SESSION 003: ACCEPTED CARDS INVESTIGATION
-- =============================================================================
-- 
-- Student ID: 46246124-a43f-4980-b05e-97670eed3f32
-- Date: 2025-06-07
-- Purpose: Investigate student's accepted cards and their current status
-- =============================================================================

-- 3. STUDENT'S ACCEPTED CARDS ANALYSIS
SELECT 
    '=== ACCEPTED CARDS ANALYSIS ===' as section,
    sc.id as card_id,
    sc.lesson_id,
    l.name as lesson_name,
    sc.front_content,
    sc.back_content,
    sc.difficulty_level,
    sc.created_at as card_created,
    -- Find when this student first accepted this card
    (
        SELECT MIN(r.created_at)
        FROM public.sr_reviews r
        WHERE r.card_id = sc.id 
          AND r.student_id = '46246124-a43f-4980-b05e-97670eed3f32'
    ) as first_accepted_date,
    -- Current card status for this student
    COALESCE(
        (
            SELECT r.card_status
            FROM public.sr_reviews r
            WHERE r.card_id = sc.id 
              AND r.student_id = '46246124-a43f-4980-b05e-97670eed3f32'
              AND r.completed_at IS NULL
            ORDER BY r.created_at DESC
            LIMIT 1
        ),
        'not_accepted'
    ) as current_card_status
FROM public.sr_cards sc
INNER JOIN public.lessons l ON sc.lesson_id = l.id
INNER JOIN public.lesson_participants lp ON l.id = lp.lesson_id
WHERE lp.student_id = '46246124-a43f-4980-b05e-97670eed3f32'
  AND sc.status = 'approved'
  AND EXISTS (
      SELECT 1 FROM public.sr_reviews r
      WHERE r.card_id = sc.id AND r.student_id = '46246124-a43f-4980-b05e-97670eed3f32'
  )
ORDER BY first_accepted_date DESC;