-- =============================================================================
-- DEBUGGING SESSION 009: CARDS FOR STUDY ANALYSIS
-- =============================================================================
-- 
-- Student ID: 46246124-a43f-4980-b05e-97670eed3f32
-- Date: 2025-06-07
-- Purpose: Analyze what cards are available for study and their scheduling
-- =============================================================================

-- 9. CARDS FOR STUDY FUNCTION RESULTS
SELECT 
    '=== CARDS FOR STUDY FUNCTION RESULTS ===' as section,
    card_id,
    lesson_id,
    lesson_name,
    front_content,
    difficulty_level,
    scheduled_for,
    scheduled_for AT TIME ZONE 'Europe/Warsaw' as scheduled_for_warsaw,
    card_pool,
    can_accept,
    review_id
FROM public.get_cards_for_study('46246124-a43f-4980-b05e-97670eed3f32'::UUID, 'both', 20, 20)
ORDER BY 
    CASE card_pool 
        WHEN 'new' THEN 1 
        WHEN 'due' THEN 2 
        ELSE 3 
    END,
    scheduled_for ASC;