-- =============================================================================
-- COMPREHENSIVE STUDENT DATA INVESTIGATION
-- =============================================================================
-- 
-- This query investigates student 46246124-a43f-4980-b05e-97670eed3f32
-- to analyze their cards, reviews, due sessions, and study analytics
-- for comparison with frontend debug panels
-- =============================================================================

-- Set the student ID as a variable for easy reference
\set student_id '46246124-a43f-4980-b05e-97670eed3f32'

-- =============================================================================
-- 1. STUDENT BASIC INFO AND PROFILE
-- =============================================================================

SELECT 
    '=== STUDENT PROFILE INFORMATION ===' as section,
    p.id as student_id,
    p.name as student_name,
    p.email as student_email,
    p.role,
    p.created_at as account_created,
    p.updated_at as last_profile_update
FROM public.profiles p
WHERE p.id = :'student_id';

-- =============================================================================
-- 2. STUDENT'S LESSON PARTICIPATION
-- =============================================================================

SELECT 
    '=== LESSON PARTICIPATION ===' as section,
    l.id as lesson_id,
    l.name as lesson_name,
    l.scheduled_at as lesson_scheduled,
    l.status as lesson_status,
    teacher.name as teacher_name,
    lp.enrolled_at as student_enrolled_date,
    COUNT(sc.id) as total_cards_in_lesson
FROM public.lesson_participants lp
INNER JOIN public.lessons l ON lp.lesson_id = l.id
INNER JOIN public.profiles teacher ON l.teacher_id = teacher.id
LEFT JOIN public.sr_cards sc ON l.id = sc.lesson_id AND sc.status = 'approved'
WHERE lp.student_id = :'student_id'
GROUP BY l.id, l.name, l.scheduled_at, l.status, teacher.name, lp.enrolled_at
ORDER BY lp.enrolled_at DESC;

-- =============================================================================
-- 3. STUDENT'S ACCEPTED CARDS ANALYSIS
-- =============================================================================

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
          AND r.student_id = :'student_id'
    ) as first_accepted_date,
    -- Current card status for this student
    COALESCE(
        (
            SELECT r.card_status
            FROM public.sr_reviews r
            WHERE r.card_id = sc.id 
              AND r.student_id = :'student_id'
              AND r.completed_at IS NULL
            ORDER BY r.created_at DESC
            LIMIT 1
        ),
        'not_accepted'
    ) as current_card_status
FROM public.sr_cards sc
INNER JOIN public.lessons l ON sc.lesson_id = l.id
INNER JOIN public.lesson_participants lp ON l.id = lp.lesson_id
WHERE lp.student_id = :'student_id'
  AND sc.status = 'approved'
  AND EXISTS (
      SELECT 1 FROM public.sr_reviews r
      WHERE r.card_id = sc.id AND r.student_id = :'student_id'
  )
ORDER BY first_accepted_date DESC;

-- =============================================================================
-- 4. COMPLETED REVIEWS ANALYSIS WITH TIMEZONE INFO
-- =============================================================================

SELECT 
    '=== COMPLETED REVIEWS ANALYSIS ===' as section,
    r.id as review_id,
    r.card_id,
    sc.front_content as card_front,
    l.name as lesson_name,
    r.completed_at as completed_at_utc,
    r.completed_at AT TIME ZONE 'Europe/Warsaw' as completed_at_warsaw,
    r.completed_at::DATE as completed_date_utc,
    (r.completed_at AT TIME ZONE 'Europe/Warsaw')::DATE as completed_date_warsaw,
    r.quality_rating,
    r.response_time_ms,
    r.interval_days,
    r.ease_factor,
    r.repetition_count,
    r.card_status,
    -- Check if dates differ between UTC and Warsaw timezone
    CASE 
        WHEN r.completed_at::DATE != (r.completed_at AT TIME ZONE 'Europe/Warsaw')::DATE 
        THEN 'DATE_MISMATCH' 
        ELSE 'DATE_ALIGNED' 
    END as timezone_date_status
FROM public.sr_reviews r
INNER JOIN public.sr_cards sc ON r.card_id = sc.id
INNER JOIN public.lessons l ON sc.lesson_id = l.id
WHERE r.student_id = :'student_id'
  AND r.completed_at IS NOT NULL
ORDER BY r.completed_at DESC
LIMIT 20;

-- =============================================================================
-- 5. DUE REVIEWS SESSION ANALYSIS
-- =============================================================================

SELECT 
    '=== DUE REVIEWS SESSION ANALYSIS ===' as section,
    r.id as review_id,
    r.card_id,
    sc.front_content as card_front,
    l.name as lesson_name,
    r.scheduled_for as scheduled_for_utc,
    r.scheduled_for AT TIME ZONE 'Europe/Warsaw' as scheduled_for_warsaw,
    r.scheduled_for::DATE as scheduled_date_utc,
    (r.scheduled_for AT TIME ZONE 'Europe/Warsaw')::DATE as scheduled_date_warsaw,
    CURRENT_DATE as today_utc,
    (NOW() AT TIME ZONE 'Europe/Warsaw')::DATE as today_warsaw,
    r.interval_days,
    r.ease_factor,
    r.repetition_count,
    r.card_status,
    -- Check if card is due today in different timezones
    CASE 
        WHEN r.scheduled_for::DATE <= CURRENT_DATE THEN 'DUE_UTC'
        ELSE 'NOT_DUE_UTC'
    END as due_status_utc,
    CASE 
        WHEN (r.scheduled_for AT TIME ZONE 'Europe/Warsaw')::DATE <= (NOW() AT TIME ZONE 'Europe/Warsaw')::DATE 
        THEN 'DUE_WARSAW'
        ELSE 'NOT_DUE_WARSAW'
    END as due_status_warsaw,
    -- Days until due
    r.scheduled_for::DATE - CURRENT_DATE as days_until_due_utc,
    (r.scheduled_for AT TIME ZONE 'Europe/Warsaw')::DATE - (NOW() AT TIME ZONE 'Europe/Warsaw')::DATE as days_until_due_warsaw
FROM public.sr_reviews r
INNER JOIN public.sr_cards sc ON r.card_id = sc.id
INNER JOIN public.lessons l ON sc.lesson_id = l.id
WHERE r.student_id = :'student_id'
  AND r.completed_at IS NULL
ORDER BY r.scheduled_for ASC;

-- =============================================================================
-- 6. STUDY ANALYTICS - USER STATS FUNCTION RESULTS
-- =============================================================================

SELECT 
    '=== USER STATS FUNCTION RESULTS ===' as section;

-- Original function
SELECT 
    'ORIGINAL get_user_stats()' as function_type,
    total_reviews,
    average_quality,
    study_streak,
    cards_learned,
    cards_due_today,
    next_review_date,
    weekly_progress,
    monthly_progress
FROM public.get_user_stats(:'student_id');

-- New timezone-aware function (if it exists)
SELECT 
    'TIMEZONE-AWARE get_user_stats_with_timezone()' as function_type,
    total_reviews,
    average_quality,
    study_streak,
    cards_learned,
    cards_due_today,
    next_review_date,
    weekly_progress,
    monthly_progress
FROM public.get_user_stats_with_timezone(:'student_id', 'Europe/Warsaw');

-- =============================================================================
-- 7. TODAY'S STUDY STATISTICS COMPARISON
-- =============================================================================

SELECT 
    '=== TODAY''S STUDY STATISTICS COMPARISON ===' as section;

-- Original function
SELECT 
    'ORIGINAL get_today_study_stats()' as function_type,
    cards_studied_today,
    total_cards_ready,
    study_time_minutes,
    sessions_completed,
    new_cards_accepted_today,
    cards_mastered_today
FROM public.get_today_study_stats(:'student_id');

-- New timezone-aware function (if it exists)
SELECT 
    'TIMEZONE-AWARE get_today_study_stats_with_timezone()' as function_type,
    cards_studied_today,
    total_cards_ready,
    study_time_minutes,
    sessions_completed,
    new_cards_accepted_today,
    cards_mastered_today
FROM public.get_today_study_stats_with_timezone(:'student_id', 'Europe/Warsaw');

-- =============================================================================
-- 8. PROGRESS TRACKING TABLE ANALYSIS
-- =============================================================================

SELECT 
    '=== PROGRESS TRACKING TABLE ANALYSIS ===' as section,
    sp.lesson_id,
    l.name as lesson_name,
    sp.cards_total,
    sp.cards_reviewed,
    sp.cards_learned,
    sp.average_quality,
    sp.study_streak,
    sp.last_review_date as progress_last_review_date,
    sp.next_review_date as progress_next_review_date,
    sp.created_at as progress_created,
    sp.updated_at as progress_updated,
    -- Compare with actual review data
    (
        SELECT MAX(r.completed_at)::DATE
        FROM public.sr_reviews r
        INNER JOIN public.sr_cards sc ON r.card_id = sc.id
        WHERE r.student_id = :'student_id'
          AND sc.lesson_id = sp.lesson_id
          AND r.completed_at IS NOT NULL
    ) as actual_last_review_date_utc,
    (
        SELECT MAX(r.completed_at AT TIME ZONE 'Europe/Warsaw')::DATE
        FROM public.sr_reviews r
        INNER JOIN public.sr_cards sc ON r.card_id = sc.id
        WHERE r.student_id = :'student_id'
          AND sc.lesson_id = sp.lesson_id
          AND r.completed_at IS NOT NULL
    ) as actual_last_review_date_warsaw,
    -- Check for inconsistencies
    CASE 
        WHEN sp.last_review_date != (
            SELECT MAX(r.completed_at)::DATE
            FROM public.sr_reviews r
            INNER JOIN public.sr_cards sc ON r.card_id = sc.id
            WHERE r.student_id = :'student_id'
              AND sc.lesson_id = sp.lesson_id
              AND r.completed_at IS NOT NULL
        ) THEN 'INCONSISTENT_UTC'
        WHEN sp.last_review_date != (
            SELECT MAX(r.completed_at AT TIME ZONE 'Europe/Warsaw')::DATE
            FROM public.sr_reviews r
            INNER JOIN public.sr_cards sc ON r.card_id = sc.id
            WHERE r.student_id = :'student_id'
              AND sc.lesson_id = sp.lesson_id
              AND r.completed_at IS NOT NULL
        ) THEN 'INCONSISTENT_WARSAW'
        ELSE 'CONSISTENT'
    END as consistency_status
FROM public.sr_progress sp
INNER JOIN public.lessons l ON sp.lesson_id = l.id
WHERE sp.student_id = :'student_id'
ORDER BY sp.updated_at DESC;

-- =============================================================================
-- 9. CARDS FOR STUDY FUNCTION RESULTS
-- =============================================================================

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
FROM public.get_cards_for_study(:'student_id', 'both', 20, 20)
ORDER BY 
    CASE card_pool 
        WHEN 'new' THEN 1 
        WHEN 'due' THEN 2 
        ELSE 3 
    END,
    scheduled_for ASC;

-- =============================================================================
-- 10. TIMEZONE BOUNDARY ANALYSIS
-- =============================================================================

SELECT 
    '=== TIMEZONE BOUNDARY ANALYSIS ===' as section,
    NOW() as current_utc_time,
    NOW() AT TIME ZONE 'Europe/Warsaw' as current_warsaw_time,
    CURRENT_DATE as current_utc_date,
    (NOW() AT TIME ZONE 'Europe/Warsaw')::DATE as current_warsaw_date,
    CASE 
        WHEN CURRENT_DATE = (NOW() AT TIME ZONE 'Europe/Warsaw')::DATE 
        THEN 'DATES_ALIGNED'
        ELSE 'DATES_MISALIGNED - HIGH RISK FOR DISCREPANCIES'
    END as date_alignment_status,
    EXTRACT(HOUR FROM NOW()) as current_utc_hour,
    EXTRACT(HOUR FROM (NOW() AT TIME ZONE 'Europe/Warsaw')) as current_warsaw_hour;

-- =============================================================================
-- 11. RECENT ACTIVITY SUMMARY
-- =============================================================================

SELECT 
    '=== RECENT ACTIVITY SUMMARY (Last 7 Days) ===' as section,
    date_series.activity_date_utc,
    date_series.activity_date_warsaw,
    COALESCE(activity_summary.reviews_completed, 0) as reviews_completed,
    COALESCE(activity_summary.total_study_time_minutes, 0) as total_study_time_minutes,
    COALESCE(activity_summary.unique_cards_studied, 0) as unique_cards_studied,
    COALESCE(activity_summary.avg_quality, 0) as avg_quality_rating
FROM (
    SELECT 
        generate_series(
            CURRENT_DATE - INTERVAL '6 days',
            CURRENT_DATE,
            INTERVAL '1 day'
        )::DATE as activity_date_utc,
        (generate_series(
            (NOW() AT TIME ZONE 'Europe/Warsaw')::DATE - INTERVAL '6 days',
            (NOW() AT TIME ZONE 'Europe/Warsaw')::DATE,
            INTERVAL '1 day'
        ) AT TIME ZONE 'Europe/Warsaw')::DATE as activity_date_warsaw
) date_series
LEFT JOIN (
    SELECT 
        r.completed_at::DATE as review_date,
        COUNT(*) as reviews_completed,
        SUM(r.response_time_ms) / 60000.0 as total_study_time_minutes,
        COUNT(DISTINCT r.card_id) as unique_cards_studied,
        AVG(r.quality_rating) as avg_quality
    FROM public.sr_reviews r
    WHERE r.student_id = :'student_id'
      AND r.completed_at IS NOT NULL
      AND r.completed_at >= CURRENT_DATE - INTERVAL '6 days'
    GROUP BY r.completed_at::DATE
) activity_summary ON date_series.activity_date_utc = activity_summary.review_date
ORDER BY date_series.activity_date_utc DESC;

-- =============================================================================
-- SUMMARY SECTION
-- =============================================================================

SELECT 
    '=== INVESTIGATION SUMMARY ===' as section,
    (SELECT COUNT(*) FROM public.lesson_participants WHERE student_id = :'student_id') as total_lessons_enrolled,
    (SELECT COUNT(DISTINCT r.card_id) FROM public.sr_reviews r WHERE r.student_id = :'student_id') as total_cards_ever_studied,
    (SELECT COUNT(*) FROM public.sr_reviews r WHERE r.student_id = :'student_id' AND r.completed_at IS NOT NULL) as total_completed_reviews,
    (SELECT COUNT(*) FROM public.sr_reviews r WHERE r.student_id = :'student_id' AND r.completed_at IS NULL) as total_pending_reviews,
    (SELECT COUNT(*) FROM public.sr_progress WHERE student_id = :'student_id') as progress_records_count,
    -- Timezone mismatch count
    (
        SELECT COUNT(*)
        FROM public.sr_reviews r
        WHERE r.student_id = :'student_id'
          AND r.completed_at IS NOT NULL
          AND r.completed_at::DATE != (r.completed_at AT TIME ZONE 'Europe/Warsaw')::DATE
    ) as timezone_date_mismatches;