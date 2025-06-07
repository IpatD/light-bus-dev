-- =============================================================================
-- DATE DISCREPANCY DIAGNOSTIC TOOLS
-- =============================================================================
-- 
-- This file contains comprehensive diagnostic queries to investigate date 
-- discrepancies in the student dashboard's learning analytics panel.
--
-- USAGE: Run these queries in Supabase SQL Editor to diagnose date issues
-- =============================================================================

-- =============================================================================
-- 1. TIMEZONE AND DATE BOUNDARY ANALYSIS
-- =============================================================================

-- Show current database timezone settings and date boundaries
SELECT 
    'Database Timezone Info' as analysis_type,
    current_setting('timezone') as database_timezone,
    NOW() as current_utc_timestamp,
    NOW()::DATE as current_utc_date,
    (NOW() AT TIME ZONE 'Europe/Warsaw') as current_warsaw_timestamp,
    (NOW() AT TIME ZONE 'Europe/Warsaw')::DATE as current_warsaw_date,
    CASE 
        WHEN NOW()::DATE != (NOW() AT TIME ZONE 'Europe/Warsaw')::DATE 
        THEN 'DATE_MISMATCH_DETECTED'
        ELSE 'DATE_ALIGNED'
    END as timezone_date_status;

-- =============================================================================
-- 2. STUDENT REVIEW DATE ANALYSIS
-- =============================================================================

-- Analyze review completion dates vs what should be displayed
CREATE OR REPLACE FUNCTION debug_student_review_dates(p_student_id UUID DEFAULT NULL)
RETURNS TABLE(
    student_id UUID,
    student_name TEXT,
    review_id UUID,
    card_front TEXT,
    lesson_name TEXT,
    
    -- Raw timestamps
    completed_at_utc TIMESTAMPTZ,
    created_at_utc TIMESTAMPTZ,
    scheduled_for_utc TIMESTAMPTZ,
    
    -- Date conversions
    completed_date_utc DATE,
    completed_date_warsaw DATE,
    
    -- Time zone analysis
    completed_time_utc TIME,
    completed_time_warsaw TIME,
    
    -- Potential discrepancy indicators
    date_differs_by_timezone BOOLEAN,
    hours_difference_from_midnight DECIMAL,
    
    -- Progress tracking dates
    progress_last_review_date DATE,
    progress_next_review_date DATE,
    
    -- Discrepancy flags
    discrepancy_type TEXT,
    potential_issue TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH review_analysis AS (
        SELECT 
            r.student_id,
            p.name as student_name,
            r.id as review_id,
            c.front_content as card_front,
            l.name as lesson_name,
            
            -- Raw timestamps
            r.completed_at as completed_at_utc,
            r.created_at as created_at_utc,
            r.scheduled_for as scheduled_for_utc,
            
            -- Date conversions
            r.completed_at::DATE as completed_date_utc,
            (r.completed_at AT TIME ZONE 'Europe/Warsaw')::DATE as completed_date_warsaw,
            
            -- Time analysis
            r.completed_at::TIME as completed_time_utc,
            (r.completed_at AT TIME ZONE 'Europe/Warsaw')::TIME as completed_time_warsaw,
            
            -- Timezone date comparison
            (r.completed_at::DATE != (r.completed_at AT TIME ZONE 'Europe/Warsaw')::DATE) as date_differs_by_timezone,
            
            -- Hours from midnight analysis
            EXTRACT(EPOCH FROM (r.completed_at::TIME)) / 3600.0 as hours_difference_from_midnight,
            
            -- Progress dates
            sp.last_review_date as progress_last_review_date,
            sp.next_review_date as progress_next_review_date
            
        FROM public.sr_reviews r
        INNER JOIN public.sr_cards c ON r.card_id = c.id
        INNER JOIN public.lessons l ON c.lesson_id = l.id
        INNER JOIN public.profiles p ON r.student_id = p.id
        LEFT JOIN public.sr_progress sp ON r.student_id = sp.student_id AND c.lesson_id = sp.lesson_id
        WHERE r.completed_at IS NOT NULL
          AND (p_student_id IS NULL OR r.student_id = p_student_id)
        ORDER BY r.completed_at DESC
        LIMIT 50
    )
    SELECT 
        ra.*,
        -- Discrepancy classification
        CASE 
            WHEN ra.date_differs_by_timezone THEN 'TIMEZONE_DATE_MISMATCH'
            WHEN ra.completed_date_utc != ra.progress_last_review_date THEN 'PROGRESS_DATE_MISMATCH'
            WHEN ra.hours_difference_from_midnight < 2 OR ra.hours_difference_from_midnight > 22 THEN 'MIDNIGHT_BOUNDARY_RISK'
            ELSE 'NO_OBVIOUS_DISCREPANCY'
        END as discrepancy_type,
        
        -- Potential issue description
        CASE 
            WHEN ra.date_differs_by_timezone THEN 
                'Review completed on different dates in UTC vs client timezone'
            WHEN ra.completed_date_utc != ra.progress_last_review_date THEN 
                'Progress table date does not match review completion date'
            WHEN ra.hours_difference_from_midnight < 2 THEN 
                'Review completed near midnight - potential timezone date shift'
            WHEN ra.hours_difference_from_midnight > 22 THEN 
                'Review completed near end of day - potential timezone date shift'
            ELSE 'No obvious date discrepancy detected'
        END as potential_issue
        
    FROM review_analysis ra;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- 3. TODAY'S STATISTICS VALIDATION
-- =============================================================================

-- Compare different "today" calculations
CREATE OR REPLACE FUNCTION debug_today_statistics_discrepancy(p_student_id UUID)
RETURNS TABLE(
    analysis_type TEXT,
    utc_date DATE,
    warsaw_date DATE,
    count_utc_date BIGINT,
    count_warsaw_date BIGINT,
    discrepancy_detected BOOLEAN,
    details JSONB
) AS $$
DECLARE
    v_utc_today DATE := CURRENT_DATE;
    v_warsaw_today DATE := (NOW() AT TIME ZONE 'Europe/Warsaw')::DATE;
BEGIN
    -- Analysis 1: Reviews completed "today" by different timezone interpretations
    RETURN QUERY
    SELECT 
        'Reviews Completed Today'::TEXT,
        v_utc_today,
        v_warsaw_today,
        
        -- Count using UTC date
        (SELECT COUNT(*) 
         FROM public.sr_reviews r 
         INNER JOIN public.sr_cards c ON r.card_id = c.id
         INNER JOIN public.lesson_participants lp ON c.lesson_id = lp.lesson_id
         WHERE r.student_id = p_student_id 
           AND lp.student_id = p_student_id
           AND r.completed_at IS NOT NULL 
           AND r.completed_at::DATE = v_utc_today) as count_utc_date,
        
        -- Count using Warsaw timezone date
        (SELECT COUNT(*) 
         FROM public.sr_reviews r 
         INNER JOIN public.sr_cards c ON r.card_id = c.id
         INNER JOIN public.lesson_participants lp ON c.lesson_id = lp.lesson_id
         WHERE r.student_id = p_student_id 
           AND lp.student_id = p_student_id
           AND r.completed_at IS NOT NULL 
           AND (r.completed_at AT TIME ZONE 'Europe/Warsaw')::DATE = v_warsaw_today) as count_warsaw_date,
        
        -- Check if there's a discrepancy
        (SELECT COUNT(*) 
         FROM public.sr_reviews r 
         INNER JOIN public.sr_cards c ON r.card_id = c.id
         INNER JOIN public.lesson_participants lp ON c.lesson_id = lp.lesson_id
         WHERE r.student_id = p_student_id 
           AND lp.student_id = p_student_id
           AND r.completed_at IS NOT NULL 
           AND r.completed_at::DATE = v_utc_today) !=
        (SELECT COUNT(*) 
         FROM public.sr_reviews r 
         INNER JOIN public.sr_cards c ON r.card_id = c.id
         INNER JOIN public.lesson_participants lp ON c.lesson_id = lp.lesson_id
         WHERE r.student_id = p_student_id 
           AND lp.student_id = p_student_id
           AND r.completed_at IS NOT NULL 
           AND (r.completed_at AT TIME ZONE 'Europe/Warsaw')::DATE = v_warsaw_today) as discrepancy_detected,
        
        -- Detailed breakdown
        jsonb_build_object(
            'utc_timezone_reviews', (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'review_id', r.id,
                        'completed_at_utc', r.completed_at,
                        'completed_at_warsaw', r.completed_at AT TIME ZONE 'Europe/Warsaw',
                        'date_utc', r.completed_at::DATE,
                        'date_warsaw', (r.completed_at AT TIME ZONE 'Europe/Warsaw')::DATE
                    )
                )
                FROM public.sr_reviews r 
                INNER JOIN public.sr_cards c ON r.card_id = c.id
                INNER JOIN public.lesson_participants lp ON c.lesson_id = lp.lesson_id
                WHERE r.student_id = p_student_id 
                  AND lp.student_id = p_student_id
                  AND r.completed_at IS NOT NULL 
                  AND r.completed_at::DATE = v_utc_today
                LIMIT 10
            )
        ) as details;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- 4. PROGRESS TABLE VS REVIEWS CONSISTENCY CHECK
-- =============================================================================

-- Check consistency between sr_progress dates and actual review dates
CREATE OR REPLACE FUNCTION debug_progress_date_consistency(p_student_id UUID DEFAULT NULL)
RETURNS TABLE(
    student_id UUID,
    lesson_id UUID,
    lesson_name TEXT,
    
    -- Progress table dates
    progress_last_review_date DATE,
    progress_next_review_date DATE,
    progress_updated_at TIMESTAMPTZ,
    
    -- Actual review dates
    actual_last_review_date DATE,
    actual_last_review_timestamp TIMESTAMPTZ,
    actual_next_scheduled_date DATE,
    actual_next_scheduled_timestamp TIMESTAMPTZ,
    
    -- Consistency flags
    last_date_matches BOOLEAN,
    next_date_matches BOOLEAN,
    consistency_status TEXT,
    days_difference_last INTEGER,
    days_difference_next INTEGER
) AS $$
BEGIN
    RETURN QUERY
    WITH progress_vs_actual AS (
        SELECT 
            sp.student_id,
            sp.lesson_id,
            l.name as lesson_name,
            
            -- Progress table data
            sp.last_review_date as progress_last_review_date,
            sp.next_review_date as progress_next_review_date,
            sp.updated_at as progress_updated_at,
            
            -- Actual last review
            (SELECT r.completed_at::DATE 
             FROM public.sr_reviews r 
             INNER JOIN public.sr_cards c ON r.card_id = c.id
             WHERE r.student_id = sp.student_id 
               AND c.lesson_id = sp.lesson_id 
               AND r.completed_at IS NOT NULL
             ORDER BY r.completed_at DESC 
             LIMIT 1) as actual_last_review_date,
            
            (SELECT r.completed_at 
             FROM public.sr_reviews r 
             INNER JOIN public.sr_cards c ON r.card_id = c.id
             WHERE r.student_id = sp.student_id 
               AND c.lesson_id = sp.lesson_id 
               AND r.completed_at IS NOT NULL
             ORDER BY r.completed_at DESC 
             LIMIT 1) as actual_last_review_timestamp,
            
            -- Actual next scheduled review
            (SELECT r.scheduled_for::DATE 
             FROM public.sr_reviews r 
             INNER JOIN public.sr_cards c ON r.card_id = c.id
             WHERE r.student_id = sp.student_id 
               AND c.lesson_id = sp.lesson_id 
               AND r.completed_at IS NULL
             ORDER BY r.scheduled_for ASC 
             LIMIT 1) as actual_next_scheduled_date,
            
            (SELECT r.scheduled_for 
             FROM public.sr_reviews r 
             INNER JOIN public.sr_cards c ON r.card_id = c.id
             WHERE r.student_id = sp.student_id 
               AND c.lesson_id = sp.lesson_id 
               AND r.completed_at IS NULL
             ORDER BY r.scheduled_for ASC 
             LIMIT 1) as actual_next_scheduled_timestamp
            
        FROM public.sr_progress sp
        INNER JOIN public.lessons l ON sp.lesson_id = l.id
        WHERE (p_student_id IS NULL OR sp.student_id = p_student_id)
    )
    SELECT 
        pva.*,
        
        -- Consistency checks
        (pva.progress_last_review_date = pva.actual_last_review_date) as last_date_matches,
        (pva.progress_next_review_date = pva.actual_next_scheduled_date) as next_date_matches,
        
        -- Status classification
        CASE 
            WHEN pva.progress_last_review_date = pva.actual_last_review_date 
                 AND pva.progress_next_review_date = pva.actual_next_scheduled_date 
            THEN 'CONSISTENT'
            WHEN pva.progress_last_review_date != pva.actual_last_review_date 
                 AND pva.progress_next_review_date != pva.actual_next_scheduled_date 
            THEN 'BOTH_DATES_INCONSISTENT'
            WHEN pva.progress_last_review_date != pva.actual_last_review_date 
            THEN 'LAST_DATE_INCONSISTENT'
            WHEN pva.progress_next_review_date != pva.actual_next_scheduled_date 
            THEN 'NEXT_DATE_INCONSISTENT'
            ELSE 'UNKNOWN'
        END as consistency_status,
        
        -- Calculate date differences
        CASE 
            WHEN pva.actual_last_review_date IS NOT NULL 
            THEN pva.actual_last_review_date - pva.progress_last_review_date
            ELSE NULL
        END as days_difference_last,
        
        CASE 
            WHEN pva.actual_next_scheduled_date IS NOT NULL 
            THEN pva.actual_next_scheduled_date - pva.progress_next_review_date
            ELSE NULL
        END as days_difference_next
        
    FROM progress_vs_actual pva;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- 5. FRONTEND DATA VALIDATION
-- =============================================================================

-- Simulate what frontend components receive and how they process dates
CREATE OR REPLACE FUNCTION debug_frontend_date_processing(p_student_id UUID)
RETURNS TABLE(
    component_name TEXT,
    function_name TEXT,
    raw_data JSONB,
    processed_result JSONB,
    potential_issues TEXT[]
) AS $$
BEGIN
    -- Simulate ProgressChart component data processing
    RETURN QUERY
    SELECT 
        'ProgressChart'::TEXT as component_name,
        'get_user_stats'::TEXT as function_name,
        
        -- Raw data that frontend receives
        (SELECT row_to_json(stats)
         FROM (
             SELECT * FROM public.get_user_stats(p_student_id) LIMIT 1
         ) stats)::JSONB as raw_data,
        
        -- Simulated frontend processing
        jsonb_build_object(
            'weekly_chart_data', (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'day_index', idx,
                        'expected_date_client', (CURRENT_DATE - (6 - idx)),
                        'expected_date_warsaw', ((NOW() AT TIME ZONE 'Europe/Warsaw')::DATE - (6 - idx)),
                        'reviews_count', COALESCE(stats.weekly_progress[idx + 1], 0)
                    )
                )
                FROM generate_series(0, 6) as idx,
                     (SELECT * FROM public.get_user_stats(p_student_id) LIMIT 1) stats
            )
        ) as processed_result,
        
        -- Potential issues
        ARRAY[
            CASE WHEN (SELECT study_streak FROM public.get_user_stats(p_student_id) LIMIT 1) = 0 
                 THEN 'Study streak is 0 - check streak calculation'
                 ELSE 'Study streak appears normal' END,
            CASE WHEN (SELECT array_length(weekly_progress, 1) FROM public.get_user_stats(p_student_id) LIMIT 1) != 7
                 THEN 'Weekly progress array length incorrect'
                 ELSE 'Weekly progress array length correct' END,
            CASE WHEN CURRENT_DATE != (NOW() AT TIME ZONE 'Europe/Warsaw')::DATE
                 THEN 'Server date differs from client timezone date'
                 ELSE 'Server and client dates aligned' END
        ] as potential_issues;
    
    -- Simulate DueCardsSection today's stats
    RETURN QUERY
    SELECT 
        'DueCardsSection'::TEXT as component_name,
        'get_today_study_stats'::TEXT as function_name,
        
        -- Raw data
        (SELECT row_to_json(stats)
         FROM (
             SELECT * FROM public.get_today_study_stats(p_student_id) LIMIT 1
         ) stats)::JSONB as raw_data,
        
        -- Processing simulation
        jsonb_build_object(
            'today_server_date', CURRENT_DATE,
            'today_client_date', (NOW() AT TIME ZONE 'Europe/Warsaw')::DATE,
            'date_boundary_risk', CURRENT_DATE != (NOW() AT TIME ZONE 'Europe/Warsaw')::DATE
        ) as processed_result,
        
        -- Issues
        ARRAY[
            CASE WHEN (SELECT cards_studied_today FROM public.get_today_study_stats(p_student_id) LIMIT 1) = 0
                 THEN 'No cards studied today - verify date filtering'
                 ELSE 'Cards studied today count normal' END,
            CASE WHEN EXTRACT(HOUR FROM NOW()) < 2 OR EXTRACT(HOUR FROM NOW()) > 22
                 THEN 'Current time near midnight - high risk for date boundary issues'
                 ELSE 'Current time safe from midnight boundary issues' END
        ] as potential_issues;
        
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- 6. COMPREHENSIVE DATE DISCREPANCY REPORT
-- =============================================================================

-- Generate a comprehensive report of all potential date discrepancies
CREATE OR REPLACE FUNCTION generate_date_discrepancy_report(p_student_id UUID DEFAULT NULL)
RETURNS TABLE(
    report_section TEXT,
    severity TEXT,
    issue_count BIGINT,
    description TEXT,
    sample_data JSONB,
    recommended_action TEXT
) AS $$
DECLARE
    v_total_students BIGINT;
    v_total_reviews BIGINT;
    v_timezone_mismatches BIGINT;
    v_progress_inconsistencies BIGINT;
    v_midnight_boundary_risks BIGINT;
BEGIN
    -- Get counts for analysis
    SELECT COUNT(DISTINCT id) INTO v_total_students FROM public.profiles WHERE role = 'student';
    SELECT COUNT(*) INTO v_total_reviews FROM public.sr_reviews WHERE completed_at IS NOT NULL;
    
    -- Count timezone-related date mismatches
    SELECT COUNT(*) INTO v_timezone_mismatches
    FROM public.sr_reviews 
    WHERE completed_at IS NOT NULL 
      AND completed_at::DATE != (completed_at AT TIME ZONE 'Europe/Warsaw')::DATE
      AND (p_student_id IS NULL OR student_id = p_student_id);
    
    -- Count progress table inconsistencies
    SELECT COUNT(*) INTO v_progress_inconsistencies
    FROM debug_progress_date_consistency(p_student_id)
    WHERE consistency_status != 'CONSISTENT';
    
    -- Count midnight boundary risks
    SELECT COUNT(*) INTO v_midnight_boundary_risks
    FROM public.sr_reviews r
    WHERE r.completed_at IS NOT NULL 
      AND (EXTRACT(EPOCH FROM (r.completed_at::TIME)) / 3600.0 < 2 
           OR EXTRACT(EPOCH FROM (r.completed_at::TIME)) / 3600.0 > 22)
      AND (p_student_id IS NULL OR r.student_id = p_student_id);

    -- Report Section 1: Timezone Date Mismatches
    RETURN QUERY
    SELECT 
        'Timezone Date Mismatches'::TEXT as report_section,
        CASE 
            WHEN v_timezone_mismatches = 0 THEN 'LOW'
            WHEN v_timezone_mismatches < 10 THEN 'MEDIUM'
            ELSE 'HIGH'
        END as severity,
        v_timezone_mismatches as issue_count,
        'Reviews where completion date differs between UTC and client timezone'::TEXT as description,
        (SELECT jsonb_agg(
            jsonb_build_object(
                'review_id', r.id,
                'completed_at_utc', r.completed_at,
                'date_utc', r.completed_at::DATE,
                'date_warsaw', (r.completed_at AT TIME ZONE 'Europe/Warsaw')::DATE,
                'student_id', r.student_id
            )
        )
        FROM public.sr_reviews r
        WHERE r.completed_at IS NOT NULL 
          AND r.completed_at::DATE != (r.completed_at AT TIME ZONE 'Europe/Warsaw')::DATE
          AND (p_student_id IS NULL OR r.student_id = p_student_id)
        LIMIT 5) as sample_data,
        'Implement timezone-aware date handling in frontend and consistent UTC date storage'::TEXT as recommended_action;

    -- Report Section 2: Progress Table Inconsistencies
    RETURN QUERY
    SELECT 
        'Progress Table Date Inconsistencies'::TEXT,
        CASE 
            WHEN v_progress_inconsistencies = 0 THEN 'LOW'
            WHEN v_progress_inconsistencies < 5 THEN 'MEDIUM'
            ELSE 'HIGH'
        END as severity,
        v_progress_inconsistencies as issue_count,
        'sr_progress table dates do not match actual review completion dates'::TEXT as description,
        (SELECT jsonb_agg(
            jsonb_build_object(
                'student_id', student_id,
                'lesson_id', lesson_id,
                'progress_last_date', progress_last_review_date,
                'actual_last_date', actual_last_review_date,
                'consistency_status', consistency_status
            )
        )
        FROM debug_progress_date_consistency(p_student_id)
        WHERE consistency_status != 'CONSISTENT'
        LIMIT 5) as sample_data,
        'Fix record_sr_review function to use consistent timezone for date updates'::TEXT as recommended_action;

    -- Report Section 3: Midnight Boundary Risks
    RETURN QUERY
    SELECT 
        'Midnight Boundary Date Risks'::TEXT,
        CASE 
            WHEN v_midnight_boundary_risks = 0 THEN 'LOW'
            WHEN v_midnight_boundary_risks < 20 THEN 'MEDIUM'
            ELSE 'HIGH'
        END as severity,
        v_midnight_boundary_risks as issue_count,
        'Reviews completed within 2 hours of midnight (high risk for date boundary issues)'::TEXT as description,
        (SELECT jsonb_agg(
            jsonb_build_object(
                'review_id', r.id,
                'completed_at', r.completed_at,
                'hour_of_day', EXTRACT(HOUR FROM r.completed_at),
                'risk_type', CASE 
                    WHEN EXTRACT(EPOCH FROM (r.completed_at::TIME)) / 3600.0 < 2 THEN 'early_morning'
                    ELSE 'late_night' 
                END
            )
        )
        FROM public.sr_reviews r
        WHERE r.completed_at IS NOT NULL 
          AND (EXTRACT(EPOCH FROM (r.completed_at::TIME)) / 3600.0 < 2 
               OR EXTRACT(EPOCH FROM (r.completed_at::TIME)) / 3600.0 > 22)
          AND (p_student_id IS NULL OR r.student_id = p_student_id)
        LIMIT 5) as sample_data,
        'Monitor these reviews and implement timezone-aware date comparisons'::TEXT as recommended_action;

    -- Report Section 4: Database Configuration
    RETURN QUERY
    SELECT 
        'Database Configuration'::TEXT,
        'INFO'::TEXT,
        1::BIGINT as issue_count,
        'Current database timezone and configuration settings'::TEXT as description,
        jsonb_build_object(
            'database_timezone', current_setting('timezone'),
            'current_utc_time', NOW(),
            'current_utc_date', NOW()::DATE,
            'current_warsaw_time', NOW() AT TIME ZONE 'Europe/Warsaw',
            'current_warsaw_date', (NOW() AT TIME ZONE 'Europe/Warsaw')::DATE,
            'date_boundary_aligned', NOW()::DATE = (NOW() AT TIME ZONE 'Europe/Warsaw')::DATE
        ) as sample_data,
        'Ensure consistent timezone handling across all date operations'::TEXT as recommended_action;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- 7. GRANT PERMISSIONS
-- =============================================================================

GRANT EXECUTE ON FUNCTION debug_student_review_dates(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION debug_today_statistics_discrepancy(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION debug_progress_date_consistency(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION debug_frontend_date_processing(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION generate_date_discrepancy_report(UUID) TO authenticated;

-- =============================================================================
-- 8. USAGE EXAMPLES
-- =============================================================================

/*
-- Example 1: Check specific student's date issues
SELECT * FROM debug_student_review_dates('student-uuid-here');

-- Example 2: Validate today's statistics for timezone discrepancies
SELECT * FROM debug_today_statistics_discrepancy('student-uuid-here');

-- Example 3: Check progress table consistency
SELECT * FROM debug_progress_date_consistency('student-uuid-here');

-- Example 4: Simulate frontend date processing
SELECT * FROM debug_frontend_date_processing('student-uuid-here');

-- Example 5: Generate comprehensive report for all students
SELECT * FROM generate_date_discrepancy_report();

-- Example 6: Generate report for specific student
SELECT * FROM generate_date_discrepancy_report('student-uuid-here');

-- Example 7: Quick timezone boundary check
SELECT 
    'Current Date Boundary Check' as check_type,
    NOW() as utc_now,
    NOW()::DATE as utc_date,
    (NOW() AT TIME ZONE 'Europe/Warsaw') as warsaw_now,
    (NOW() AT TIME ZONE 'Europe/Warsaw')::DATE as warsaw_date,
    CASE 
        WHEN NOW()::DATE = (NOW() AT TIME ZONE 'Europe/Warsaw')::DATE 
        THEN 'ALIGNED' 
        ELSE 'MISALIGNED - HIGH RISK FOR DATE DISCREPANCIES' 
    END as status;
*/