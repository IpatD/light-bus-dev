-- ============================================================================
-- SUMMARIES TABLE - RLS POLICIES
-- ============================================================================
-- Table: summaries
-- RLS Status: ENABLED
-- Policies: 2 total
-- Security Level: Standard (Lesson Content)
-- ============================================================================

-- Enable RLS for summaries table
ALTER TABLE summaries ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- POLICY 1: Users can view summaries of lessons they participate in
-- ============================================================================
-- Purpose: Allow students and teachers to access lesson summaries
-- Scope: SELECT operations
-- Security: Lesson participation + teacher ownership validation

CREATE POLICY "Users can view lesson summaries" ON summaries
    FOR SELECT
    USING (
        lesson_id IN (
            SELECT lesson_id FROM lesson_participants 
            WHERE user_id = auth.uid()
        ) OR
        lesson_id IN (
            SELECT id FROM lessons WHERE teacher_id = auth.uid()
        )
    );

-- ============================================================================
-- POLICY 2: Teachers can manage summaries of their lessons
-- ============================================================================
-- Purpose: Allow teachers to create, update, and delete lesson summaries
-- Scope: ALL operations (SELECT, INSERT, UPDATE, DELETE)
-- Security: Teacher-lesson ownership validation

CREATE POLICY "Teachers can manage lesson summaries" ON summaries
    FOR ALL
    USING (
        lesson_id IN (
            SELECT id FROM lessons WHERE teacher_id = auth.uid()
        )
    )
    WITH CHECK (
        lesson_id IN (
            SELECT id FROM lessons WHERE teacher_id = auth.uid()
        )
    );

-- ============================================================================
-- SECURITY NOTES
-- ============================================================================
/*
Security Model for summaries:
- AI-generated lesson content summaries
- Teachers have full control over their lesson summaries
- Students can view summaries of lessons they attend
- Content serves as study aids and review material

Summary Content:
- Key points from lesson transcripts
- Important concepts and topics
- Action items and assignments
- Study recommendations

Access Control:
- Teachers: Full CRUD access for their lessons
- Students: Read-only access for enrolled lessons
- Public: No access to summaries
- Anonymous: No access

Educational Value:
- Students review lesson highlights
- Teachers edit and enhance AI summaries
- Study guide creation from content
- Knowledge retention support

Content Management:
- Teachers can edit AI-generated summaries
- Quality control over lesson materials
- Customization for specific learning needs
- Integration with learning objectives

Security Features:
- Lesson participation validation
- Teacher ownership verification
- No cross-lesson access
- Authentication required

Data Flow:
1. AI processes lesson transcript
2. System generates initial summary
3. Teacher reviews and edits content
4. Students access for study purposes

Privacy Protection:
- Summaries inherit lesson privacy settings
- Private lessons have private summaries
- Student access through enrollment only
- Teacher control over content visibility

Use Cases:
- Post-lesson study material
- Quick lesson review
- Absent student catch-up
- Learning reinforcement tool
- Course content organization
*/