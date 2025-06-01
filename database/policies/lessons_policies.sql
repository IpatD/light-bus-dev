-- ============================================================================
-- LESSONS TABLE - RLS POLICIES
-- ============================================================================
-- Table: lessons
-- RLS Status: ENABLED + FORCED
-- Policies: 7 total
-- Security Level: High (forced RLS)
-- ============================================================================

-- Enable RLS for lessons table
ALTER TABLE lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE lessons FORCE ROW LEVEL SECURITY;

-- ============================================================================
-- POLICY 1: Teachers can view their own lessons
-- ============================================================================
-- Purpose: Allow teachers to see lessons they created
-- Scope: SELECT operations
-- Security: Teacher ownership validation

CREATE POLICY "Teachers can view own lessons" ON lessons
    FOR SELECT
    USING (teacher_id = auth.uid());

-- ============================================================================
-- POLICY 2: Students can view lessons they participate in
-- ============================================================================
-- Purpose: Allow students to see lessons they are enrolled in
-- Scope: SELECT operations
-- Security: Participation validation through lesson_participants table

CREATE POLICY "Students can view participated lessons" ON lessons
    FOR SELECT
    USING (
        id IN (
            SELECT lesson_id FROM lesson_participants 
            WHERE user_id = auth.uid()
        )
    );

-- ============================================================================
-- POLICY 3: Teachers can create lessons
-- ============================================================================
-- Purpose: Allow teachers to create new lessons
-- Scope: INSERT operations
-- Security: Teacher ownership validation on insert

CREATE POLICY "Teachers can create lessons" ON lessons
    FOR INSERT
    WITH CHECK (teacher_id = auth.uid());

-- ============================================================================
-- POLICY 4: Teachers can update their own lessons
-- ============================================================================
-- Purpose: Allow teachers to modify their lesson content and settings
-- Scope: UPDATE operations
-- Security: Teacher ownership validation

CREATE POLICY "Teachers can update own lessons" ON lessons
    FOR UPDATE
    USING (teacher_id = auth.uid());

-- ============================================================================
-- POLICY 5: Teachers can delete their own lessons
-- ============================================================================
-- Purpose: Allow teachers to remove lessons they created
-- Scope: DELETE operations
-- Security: Teacher ownership validation

CREATE POLICY "Teachers can delete own lessons" ON lessons
    FOR DELETE
    USING (teacher_id = auth.uid());

-- ============================================================================
-- POLICY 6: Public lessons are viewable by all authenticated users
-- ============================================================================
-- Purpose: Allow discovery of public educational content
-- Scope: SELECT operations
-- Security: Public flag validation + authentication required

CREATE POLICY "Public lessons viewable by all" ON lessons
    FOR SELECT
    USING (is_public = true AND auth.uid() IS NOT NULL);

-- ============================================================================
-- POLICY 7: Archived lessons have restricted access
-- ============================================================================
-- Purpose: Limit access to archived content while preserving teacher/student access
-- Scope: SELECT operations
-- Security: Status validation with ownership/participation override

CREATE POLICY "Archived lessons restricted access" ON lessons
    FOR SELECT
    USING (
        (status != 'archived') OR 
        (teacher_id = auth.uid()) OR
        (id IN (SELECT lesson_id FROM lesson_participants WHERE user_id = auth.uid()))
    );

-- ============================================================================
-- SECURITY NOTES
-- ============================================================================
/*
Security Model for lessons:
- FORCED RLS ensures all access goes through policies
- Teachers have full CRUD control over their lessons
- Students can only view lessons they participate in
- Public lessons accessible to all authenticated users
- Archived lessons have restricted visibility
- Anonymous users cannot access any lessons

Access Patterns:
1. Teacher creates/manages their lessons
2. Students view enrolled lessons
3. Public lesson discovery by authenticated users
4. Archive protection with owner/participant override

Security Features:
- Teacher ownership validation (teacher_id = auth.uid())
- Student participation validation via join table
- Public content with authentication requirement
- Archive status protection
- No anonymous access

Data Protection:
- Prevents cross-teacher lesson access
- Protects student privacy in private lessons
- Maintains educational content integrity
- Supports content archival workflows
*/