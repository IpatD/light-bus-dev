-- =============================================================================
-- TEST 002: STUDENT PROFILE CHECK
-- =============================================================================
-- Check student profile and basic info
-- Student ID: 46246124-a43f-4980-b05e-97670eed3f32

-- Check student profile
SELECT 
    'Student Profile' as test_section,
    id,
    name,
    email,
    role,
    created_at
FROM public.profiles
WHERE id = '46246124-a43f-4980-b05e-97670eed3f32'::UUID;