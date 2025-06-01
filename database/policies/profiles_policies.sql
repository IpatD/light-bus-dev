-- ============================================================================
-- PROFILES TABLE - RLS POLICIES
-- ============================================================================
-- Table: profiles
-- RLS Status: ENABLED
-- Policies: 4 total
-- Security Level: Standard
-- ============================================================================

-- Enable RLS for profiles table
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- POLICY 1: Users can view their own profile
-- ============================================================================
-- Purpose: Allow users to access their personal profile information
-- Scope: SELECT operations
-- Security: User ownership validation

CREATE POLICY "Users can view own profile" ON profiles
    FOR SELECT
    USING (id = auth.uid());

-- ============================================================================
-- POLICY 2: Users can update their own profile
-- ============================================================================
-- Purpose: Allow users to modify their personal information
-- Scope: UPDATE operations
-- Security: User ownership validation

CREATE POLICY "Users can update own profile" ON profiles
    FOR UPDATE
    USING (id = auth.uid());

-- ============================================================================
-- POLICY 3: Teachers can view student profiles in their lessons
-- ============================================================================
-- Purpose: Allow teachers to see profile information of their students
-- Scope: SELECT operations
-- Security: Teacher-student relationship validation through lesson participation

CREATE POLICY "Teachers can view student profiles" ON profiles
    FOR SELECT
    USING (
        id IN (
            SELECT user_id FROM lesson_participants 
            WHERE lesson_id IN (
                SELECT id FROM lessons WHERE teacher_id = auth.uid()
            )
        )
    );

-- ============================================================================
-- POLICY 4: Public profiles are viewable by authenticated users
-- ============================================================================
-- Purpose: Allow discovery of public user profiles for educational networking
-- Scope: SELECT operations
-- Security: Public flag validation + authentication required

CREATE POLICY "Public profiles viewable" ON profiles
    FOR SELECT
    USING (is_public = true AND auth.uid() IS NOT NULL);

-- ============================================================================
-- SECURITY NOTES
-- ============================================================================
/*
Security Model for profiles:
- Standard RLS (not forced) allows for system-level operations
- Users have full control over their own profile
- Teachers can view profiles of students in their lessons
- Public profiles discoverable by authenticated users
- No profile creation policy (handled by auth system)

Access Patterns:
1. User manages their own profile
2. Teacher views student information for classroom management
3. Educational networking through public profiles
4. System administration (bypasses RLS when needed)

Privacy Features:
- Private profiles only visible to owner and connected teachers
- Public profiles require authentication
- Teacher access limited to actual students
- No anonymous profile browsing

Data Protection:
- Personal information protected by ownership
- Educational relationship validation
- Public/private visibility controls
- Authentication requirement for all access

Profile Relationship Matrix:
- Self: Full access (view/update)
- Teachers: View only for enrolled students
- Other users: View only if profile is public
- Anonymous: No access
*/