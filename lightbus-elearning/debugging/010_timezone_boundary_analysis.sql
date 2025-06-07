-- =============================================================================
-- DEBUGGING SESSION 010: TIMEZONE BOUNDARY ANALYSIS
-- =============================================================================
-- 
-- Student ID: 46246124-a43f-4980-b05e-97670eed3f32
-- Date: 2025-06-07
-- Purpose: Analyze current timezone boundaries and alignment status
-- =============================================================================

-- 10. TIMEZONE BOUNDARY ANALYSIS
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