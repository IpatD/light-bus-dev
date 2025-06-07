-- =============================================================================
-- DEBUGGING SESSION 001: STUDENT PROFILE INVESTIGATION
-- =============================================================================
-- 
-- Student ID: 46246124-a43f-4980-b05e-97670eed3f32
-- Date: 2025-06-07
-- Purpose: Investigate student profile and basic information
-- =============================================================================

-- 1. STUDENT BASIC INFO AND PROFILE
SELECT 
    '=== STUDENT PROFILE INFORMATION ===' as section,
    p.id as student_id,
    p.name as student_name,
    p.email as student_email,
    p.role,
    p.created_at as account_created,
    p.updated_at as last_profile_update
FROM public.profiles p
WHERE p.id = '46246124-a43f-4980-b05e-97670eed3f32';