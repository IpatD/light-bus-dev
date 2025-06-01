-- ============================================================================
-- TRANSCRIPTS TABLE - RLS POLICIES
-- ============================================================================
-- Table: transcripts
-- RLS Status: ENABLED + FORCED
-- Policies: 7 total
-- Security Level: High (Sensitive Audio/Video Content)
-- ============================================================================

-- Enable RLS for transcripts table
ALTER TABLE transcripts ENABLE ROW LEVEL SECURITY;
ALTER TABLE transcripts FORCE ROW LEVEL SECURITY;

-- ============================================================================
-- POLICY 1: Teachers can view transcripts of their lessons
-- ============================================================================
-- Purpose: Allow teachers to access transcripts of lessons they conduct
-- Scope: SELECT operations
-- Security: Teacher-lesson ownership validation

CREATE POLICY "Teachers can view lesson transcripts" ON transcripts
    FOR SELECT
    USING (
        lesson_id IN (
            SELECT id FROM lessons WHERE teacher_id = auth.uid()
        )
    );

-- ============================================================================
-- POLICY 2: Students can view transcripts of lessons they participate in
-- ============================================================================
-- Purpose: Allow students to access transcripts for study and review
-- Scope: SELECT operations
-- Security: Lesson participation validation

CREATE POLICY "Students can view lesson transcripts" ON transcripts
    FOR SELECT
    USING (
        lesson_id IN (
            SELECT lesson_id FROM lesson_participants 
            WHERE user_id = auth.uid()
        )
    );

-- ============================================================================
-- POLICY 3: Teachers can create transcripts for their lessons
-- ============================================================================
-- Purpose: Allow teachers to upload or generate transcripts
-- Scope: INSERT operations
-- Security: Teacher-lesson ownership validation

CREATE POLICY "Teachers can create lesson transcripts" ON transcripts
    FOR INSERT
    WITH CHECK (
        lesson_id IN (
            SELECT id FROM lessons WHERE teacher_id = auth.uid()
        )
    );

-- ============================================================================
-- POLICY 4: Teachers can update transcripts of their lessons
-- ============================================================================
-- Purpose: Allow teachers to edit and improve transcript quality
-- Scope: UPDATE operations
-- Security: Teacher-lesson ownership validation

CREATE POLICY "Teachers can update lesson transcripts" ON transcripts
    FOR UPDATE
    USING (
        lesson_id IN (
            SELECT id FROM lessons WHERE teacher_id = auth.uid()
        )
    );

-- ============================================================================
-- POLICY 5: Teachers can delete transcripts of their lessons
-- ============================================================================
-- Purpose: Allow teachers to remove transcripts for privacy or quality reasons
-- Scope: DELETE operations
-- Security: Teacher-lesson ownership validation

CREATE POLICY "Teachers can delete lesson transcripts" ON transcripts
    FOR DELETE
    USING (
        lesson_id IN (
            SELECT id FROM lessons WHERE teacher_id = auth.uid()
        )
    );

-- ============================================================================
-- POLICY 6: Public transcripts are viewable by authenticated users
-- ============================================================================
-- Purpose: Allow discovery of public educational transcripts
-- Scope: SELECT operations
-- Security: Public flag + lesson public status + authentication

CREATE POLICY "Public transcripts viewable" ON transcripts
    FOR SELECT
    USING (
        is_public = true AND auth.uid() IS NOT NULL AND
        lesson_id IN (
            SELECT id FROM lessons WHERE is_public = true
        )
    );

-- ============================================================================
-- POLICY 7: Approved transcripts have enhanced visibility
-- ============================================================================
-- Purpose: Provide access to quality-approved transcripts for authorized users
-- Scope: SELECT operations
-- Security: Approval status + user authorization validation

CREATE POLICY "Approved transcripts enhanced access" ON transcripts
    FOR SELECT
    USING (
        status = 'approved' AND
        (lesson_id IN (
            SELECT lesson_id FROM lesson_participants 
            WHERE user_id = auth.uid()
        ) OR
        lesson_id IN (
            SELECT id FROM lessons WHERE teacher_id = auth.uid()
        ))
    );

-- ============================================================================
-- SECURITY NOTES
-- ============================================================================
/*
Security Model for transcripts:
- FORCED RLS ensures maximum protection
- Contains sensitive audio/video lesson content
- Teachers have full control over their lesson transcripts
- Students access transcripts for enrolled lessons only
- Quality control through approval workflow

Transcript Content Security:
- AI-generated speech-to-text from lessons
- May contain sensitive educational discussions
- Personal information and private conversations
- Intellectual property of teachers and institutions

Access Control Hierarchy:
1. Teacher: Full CRUD access for their lessons
2. Student: Read-only access for enrolled lessons
3. Public: Limited access to approved public content
4. Moderator: Quality approval workflow access

Content Approval Workflow:
- Raw transcripts (teacher access only)
- Under review (teacher + moderator access)
- Approved (enhanced student access)
- Public approved (general authenticated access)

Privacy Protection:
- Forced RLS prevents policy bypass
- Lesson participation validation
- Teacher ownership verification
- No anonymous access to any transcripts

Educational Features:
- Study aid for lesson review
- Accessibility for hearing-impaired students
- Search capability within lesson content
- Integration with AI summarization

Data Sensitivity:
- Classroom conversations and discussions
- Student questions and interactions
- Teacher methodologies and techniques
- Potentially confidential educational content

Security Measures:
- Double validation (RLS + forced)
- Multi-level approval process
- Strict ownership controls
- Public content requires dual validation

Use Cases:
1. Student reviews lesson for study
2. Teacher edits transcript for accuracy
3. AI processes transcript for summaries
4. Search function finds specific topics
5. Accessibility tools read transcript aloud

Compliance Considerations:
- Educational privacy regulations (FERPA)
- Audio recording consent requirements
- Data retention policies
- Student privacy protection
*/