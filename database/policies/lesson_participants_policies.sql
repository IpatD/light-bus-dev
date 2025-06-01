-- ============================================================================
-- LESSON_PARTICIPANTS TABLE - RLS POLICIES
-- ============================================================================
-- Table: lesson_participants
-- RLS Status: ENABLED + FORCED
-- Policies: 5 total
-- Security Level: High (forced RLS)
-- ============================================================================

-- Enable RLS for lesson_participants table
ALTER TABLE lesson_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE lesson_participants FORCE ROW LEVEL SECURITY;

-- ============================================================================
-- POLICY 1: Students can view their own participations
-- ============================================================================
-- Purpose: Allow students to see lessons they are enrolled in
-- Scope: SELECT operations
-- Security: User ownership validation

CREATE POLICY "Students can view own participations" ON lesson_participants
    FOR SELECT
    USING (user_id = auth.uid());

-- ============================================================================
-- POLICY 2: Teachers can view participations in their lessons
-- ============================================================================
-- Purpose: Allow teachers to see who is enrolled in their lessons
-- Scope: SELECT operations
-- Security: Teacher-lesson ownership validation

CREATE POLICY "Teachers can view lesson participations" ON lesson_participants
    FOR SELECT
    USING (
        lesson_id IN (
            SELECT id FROM lessons WHERE teacher_id = auth.uid()
        )
    );

-- ============================================================================
-- POLICY 3: Teachers can insert participants to their lessons
-- ============================================================================
-- Purpose: Allow teachers to enroll students in their lessons
-- Scope: INSERT operations
-- Security: Teacher-lesson ownership validation

CREATE POLICY "Teachers can add participants" ON lesson_participants
    FOR INSERT
    WITH CHECK (
        lesson_id IN (
            SELECT id FROM lessons WHERE teacher_id = auth.uid()
        )
    );

-- ============================================================================
-- POLICY 4: Teachers can update participation status in their lessons
-- ============================================================================
-- Purpose: Allow teachers to update enrollment status, attendance, etc.
-- Scope: UPDATE operations
-- Security: Teacher-lesson ownership validation

CREATE POLICY "Teachers can update participation status" ON lesson_participants
    FOR UPDATE
    USING (
        lesson_id IN (
            SELECT id FROM lessons WHERE teacher_id = auth.uid()
        )
    );

-- ============================================================================
-- POLICY 5: Teachers can remove participants from their lessons
-- ============================================================================
-- Purpose: Allow teachers to unenroll students from their lessons
-- Scope: DELETE operations
-- Security: Teacher-lesson ownership validation

CREATE POLICY "Teachers can remove participants" ON lesson_participants
    FOR DELETE
    USING (
        lesson_id IN (
            SELECT id FROM lessons WHERE teacher_id = auth.uid()
        )
    );

-- ============================================================================
-- SECURITY NOTES
-- ============================================================================
/*
Security Model for lesson_participants:
- FORCED RLS ensures all access goes through policies
- Students can only see their own enrollments
- Teachers have full control over their lesson participants
- No public access - all operations require authentication
- Prevents cross-lesson data leakage
- Enforces teacher-student relationship boundaries

Common Use Cases:
1. Student views their enrolled lessons
2. Teacher manages class roster
3. Teacher updates attendance records
4. Teacher removes disruptive students
5. System tracks lesson participation

Security Validation:
- All policies require auth.uid() (authenticated users only)
- Teacher policies validate lesson ownership
- Student policies validate participation ownership
- No anonymous access permitted
*/