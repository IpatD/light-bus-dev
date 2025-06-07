-- =============================================================================
-- DATE DISCREPANCY TEST SCRIPT
-- =============================================================================
-- 
-- This script demonstrates how to run the diagnostic tools and interpret results
-- to identify date discrepancies in the student dashboard learning analytics.
--
-- INSTRUCTIONS:
-- 1. First run debug_date_discrepancies.sql to create the diagnostic functions
-- 2. Then run this script to execute the tests and see sample results
-- 3. Replace 'YOUR_STUDENT_UUID_HERE' with actual student UUIDs from your database
-- =============================================================================

-- =============================================================================
-- STEP 1: QUICK TIMEZONE BOUNDARY CHECK
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '=== DATE DISCREPANCY INVESTIGATION STARTED ===';
    RAISE NOTICE 'Current time: %', NOW();
    RAISE NOTICE 'Database timezone: %', current_setting('timezone');
    RAISE NOTICE '================================================';
END $$;

-- Check current date boundary alignment
SELECT 
    '🕐 TIMEZONE BOUNDARY CHECK' as test_type,
    NOW() as utc_now,
    NOW()::DATE as utc_date,
    (NOW() AT TIME ZONE 'Europe/Warsaw') as warsaw_now,
    (NOW() AT TIME ZONE 'Europe/Warsaw')::DATE as warsaw_date,
    CASE 
        WHEN NOW()::DATE = (NOW() AT TIME ZONE 'Europe/Warsaw')::DATE 
        THEN '✅ ALIGNED - Low risk for date discrepancies' 
        ELSE '⚠️  MISALIGNED - HIGH RISK FOR DATE DISCREPANCIES' 
    END as alignment_status,
    CASE 
        WHEN EXTRACT(HOUR FROM NOW()) BETWEEN 22 AND 23 OR EXTRACT(HOUR FROM NOW()) BETWEEN 0 AND 2
        THEN '🚨 MIDNIGHT BOUNDARY RISK - Test during this time may show discrepancies'
        ELSE '🟢 Safe testing time'
    END as testing_time_status;

-- =============================================================================
-- STEP 2: GET SAMPLE STUDENT DATA
-- =============================================================================

-- Get some student UUIDs for testing
WITH sample_students AS (
    SELECT 
        p.id as student_id,
        p.name as student_name,
        COUNT(r.id) as review_count,
        MAX(r.completed_at) as last_review
    FROM public.profiles p
    LEFT JOIN public.sr_reviews r ON p.id = r.student_id AND r.completed_at IS NOT NULL
    WHERE p.role = 'student'
    GROUP BY p.id, p.name
    HAVING COUNT(r.id) > 0
    ORDER BY COUNT(r.id) DESC
    LIMIT 3
)
SELECT 
    '👥 SAMPLE STUDENTS FOR TESTING' as info,
    student_id,
    student_name,
    review_count,
    last_review,
    'Use this UUID in the following tests' as instruction
FROM sample_students;

-- =============================================================================
-- STEP 3: COMPREHENSIVE DATE DISCREPANCY ANALYSIS
-- =============================================================================

-- Test 1: Generate comprehensive report (all students)
SELECT '📊 COMPREHENSIVE DATE DISCREPANCY REPORT (ALL STUDENTS)' as test_title;
SELECT * FROM generate_date_discrepancy_report() ORDER BY 
    CASE severity 
        WHEN 'HIGH' THEN 1 
        WHEN 'MEDIUM' THEN 2 
        WHEN 'LOW' THEN 3 
        ELSE 4 
    END;

-- =============================================================================
-- STEP 4: DETAILED ANALYSIS FOR SPECIFIC STUDENT
-- =============================================================================

-- Note: Replace with actual student UUID from the sample students above
DO $$
DECLARE
    sample_student_id UUID;
BEGIN
    -- Get a student with recent activity
    SELECT p.id INTO sample_student_id
    FROM public.profiles p
    INNER JOIN public.sr_reviews r ON p.id = r.student_id
    WHERE p.role = 'student' AND r.completed_at IS NOT NULL
    ORDER BY r.completed_at DESC
    LIMIT 1;
    
    IF sample_student_id IS NOT NULL THEN
        RAISE NOTICE 'Testing with student ID: %', sample_student_id;
        
        -- You can manually run these queries with the student ID:
        RAISE NOTICE 'Run these queries manually with student ID: %', sample_student_id;
        RAISE NOTICE 'SELECT * FROM debug_student_review_dates(''%'');', sample_student_id;
        RAISE NOTICE 'SELECT * FROM debug_today_statistics_discrepancy(''%'');', sample_student_id;
        RAISE NOTICE 'SELECT * FROM debug_progress_date_consistency(''%'');', sample_student_id;
        RAISE NOTICE 'SELECT * FROM debug_frontend_date_processing(''%'');', sample_student_id;
    ELSE
        RAISE NOTICE 'No students with review data found for testing';
    END IF;
END $$;

-- =============================================================================
-- STEP 5: MANUAL TEST QUERIES (Replace UUID as needed)
-- =============================================================================

-- UNCOMMENT AND REPLACE 'YOUR_STUDENT_UUID_HERE' WITH ACTUAL UUID FROM STEP 2

/*
-- Test A: Student Review Date Analysis
SELECT '🔍 STUDENT REVIEW DATE ANALYSIS' as test_title;
SELECT * FROM debug_student_review_dates('YOUR_STUDENT_UUID_HERE')
ORDER BY completed_at_utc DESC;

-- Test B: Today's Statistics Validation
SELECT '📅 TODAY''S STATISTICS VALIDATION' as test_title;
SELECT * FROM debug_today_statistics_discrepancy('YOUR_STUDENT_UUID_HERE');

-- Test C: Progress Date Consistency Check
SELECT '📈 PROGRESS DATE CONSISTENCY CHECK' as test_title;
SELECT * FROM debug_progress_date_consistency('YOUR_STUDENT_UUID_HERE');

-- Test D: Frontend Date Processing Simulation
SELECT '💻 FRONTEND DATE PROCESSING SIMULATION' as test_title;
SELECT * FROM debug_frontend_date_processing('YOUR_STUDENT_UUID_HERE');

-- Test E: Comprehensive Report for Specific Student
SELECT '📋 COMPREHENSIVE REPORT FOR STUDENT' as test_title;
SELECT * FROM generate_date_discrepancy_report('YOUR_STUDENT_UUID_HERE')
ORDER BY CASE severity WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END;
*/

-- =============================================================================
-- STEP 6: COMMON DATE DISCREPANCY PATTERNS
-- =============================================================================

-- Check for reviews with timezone date mismatches
SELECT 
    '⚠️  TIMEZONE DATE MISMATCHES DETECTED' as issue_type,
    COUNT(*) as affected_reviews,
    COUNT(DISTINCT student_id) as affected_students,
    MIN(completed_at) as earliest_mismatch,
    MAX(completed_at) as latest_mismatch
FROM public.sr_reviews 
WHERE completed_at IS NOT NULL 
  AND completed_at::DATE != (completed_at AT TIME ZONE 'Europe/Warsaw')::DATE;

-- Check for midnight boundary risks
SELECT 
    '🌙 MIDNIGHT BOUNDARY RISKS' as issue_type,
    COUNT(*) as risky_reviews,
    COUNT(DISTINCT student_id) as affected_students,
    COUNT(*) FILTER (WHERE EXTRACT(HOUR FROM completed_at) BETWEEN 0 AND 2) as early_morning_reviews,
    COUNT(*) FILTER (WHERE EXTRACT(HOUR FROM completed_at) BETWEEN 22 AND 23) as late_night_reviews
FROM public.sr_reviews 
WHERE completed_at IS NOT NULL 
  AND (EXTRACT(HOUR FROM completed_at) BETWEEN 0 AND 2 
       OR EXTRACT(HOUR FROM completed_at) BETWEEN 22 AND 23);

-- Check for progress table inconsistencies
WITH consistency_check AS (
    SELECT 
        consistency_status,
        COUNT(*) as count,
        COUNT(DISTINCT student_id) as affected_students
    FROM debug_progress_date_consistency()
    GROUP BY consistency_status
)
SELECT 
    '📊 PROGRESS TABLE CONSISTENCY' as check_type,
    consistency_status,
    count,
    affected_students,
    ROUND(100.0 * count / SUM(count) OVER (), 2) as percentage
FROM consistency_check
ORDER BY count DESC;

-- =============================================================================
-- STEP 7: REMEDIATION RECOMMENDATIONS
-- =============================================================================

SELECT '🔧 REMEDIATION RECOMMENDATIONS' as section;

WITH issue_summary AS (
    SELECT 
        'Timezone Date Mismatches' as issue_type,
        COUNT(*) as count,
        'HIGH' as priority
    FROM public.sr_reviews 
    WHERE completed_at IS NOT NULL 
      AND completed_at::DATE != (completed_at AT TIME ZONE 'Europe/Warsaw')::DATE
    
    UNION ALL
    
    SELECT 
        'Progress Table Inconsistencies' as issue_type,
        COUNT(*) as count,
        'MEDIUM' as priority
    FROM debug_progress_date_consistency()
    WHERE consistency_status != 'CONSISTENT'
    
    UNION ALL
    
    SELECT 
        'Midnight Boundary Risks' as issue_type,
        COUNT(*) as count,
        'MEDIUM' as priority
    FROM public.sr_reviews 
    WHERE completed_at IS NOT NULL 
      AND (EXTRACT(HOUR FROM completed_at) BETWEEN 0 AND 2 
           OR EXTRACT(HOUR FROM completed_at) BETWEEN 22 AND 23)
)
SELECT 
    issue_type,
    count,
    priority,
    CASE issue_type
        WHEN 'Timezone Date Mismatches' THEN 
            'Fix: Implement timezone-aware date handling in record_sr_review() and frontend components'
        WHEN 'Progress Table Inconsistencies' THEN 
            'Fix: Update progress tracking to use consistent timezone date conversion'
        WHEN 'Midnight Boundary Risks' THEN 
            'Fix: Add timezone context to all date comparisons and use TIMESTAMPTZ consistently'
        ELSE 'Unknown issue'
    END as recommended_action
FROM issue_summary
WHERE count > 0
ORDER BY 
    CASE priority WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END,
    count DESC;

-- =============================================================================
-- STEP 8: TEST COMPLETION
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '=== DATE DISCREPANCY INVESTIGATION COMPLETED ===';
    RAISE NOTICE 'Review the results above to identify specific date issues.';
    RAISE NOTICE 'Run the specific student tests by uncommenting Step 5 queries.';
    RAISE NOTICE 'Check the recommendations for fixing identified issues.';
    RAISE NOTICE '=================================================';
END $$;

-- =============================================================================
-- ADDITIONAL DEBUGGING QUERIES FOR MANUAL INVESTIGATION
-- =============================================================================

-- Query to find students with recent activity for testing
SELECT 
    'Students with Recent Activity (for manual testing)' as info,
    p.id as student_id,
    p.name as student_name,
    COUNT(r.id) as total_reviews,
    COUNT(r.id) FILTER (WHERE r.completed_at::DATE = CURRENT_DATE) as reviews_today,
    COUNT(r.id) FILTER (WHERE r.completed_at >= CURRENT_DATE - INTERVAL '7 days') as reviews_this_week,
    MAX(r.completed_at) as last_activity
FROM public.profiles p
LEFT JOIN public.sr_reviews r ON p.id = r.student_id AND r.completed_at IS NOT NULL
WHERE p.role = 'student'
GROUP BY p.id, p.name
HAVING COUNT(r.id) > 0
ORDER BY MAX(r.completed_at) DESC
LIMIT 10;

-- Show timezone impact on review dates
SELECT 
    'Timezone Impact Analysis' as analysis,
    date_trunc('hour', completed_at) as review_hour_utc,
    date_trunc('hour', completed_at AT TIME ZONE 'Europe/Warsaw') as review_hour_warsaw,
    completed_at::DATE as date_utc,
    (completed_at AT TIME ZONE 'Europe/Warsaw')::DATE as date_warsaw,
    COUNT(*) as review_count,
    COUNT(*) FILTER (WHERE completed_at::DATE != (completed_at AT TIME ZONE 'Europe/Warsaw')::DATE) as date_mismatches
FROM public.sr_reviews 
WHERE completed_at IS NOT NULL 
  AND completed_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY 
    date_trunc('hour', completed_at),
    date_trunc('hour', completed_at AT TIME ZONE 'Europe/Warsaw'),
    completed_at::DATE,
    (completed_at AT TIME ZONE 'Europe/Warsaw')::DATE
HAVING COUNT(*) FILTER (WHERE completed_at::DATE != (completed_at AT TIME ZONE 'Europe/Warsaw')::DATE) > 0
ORDER BY review_hour_utc DESC;