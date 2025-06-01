-- ============================================================================
-- STUDENT_LESSON_INTERACTIONS TABLE - RLS POLICIES
-- ============================================================================
-- Table: student_lesson_interactions
-- RLS Status: ENABLED
-- Policies: 4 total
-- Security Level: Standard (Classroom Activity Data)
-- ============================================================================

-- Enable RLS for student_lesson_interactions table
ALTER TABLE student_lesson_interactions ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- POLICY 1: Students can view their own interactions
-- ============================================================================
-- Purpose: Allow students to see their personal classroom activity history
-- Scope: SELECT operations
-- Security: Student ownership validation

CREATE POLICY "Students can view own interactions" ON student_lesson_interactions
    FOR SELECT
    USING (student_id = auth.uid());

-- ============================================================================
-- POLICY 2: Teachers can view interactions in their lessons
-- ============================================================================
-- Purpose: Allow teachers to monitor student engagement and participation
-- Scope: SELECT operations
-- Security: Teacher-lesson ownership validation

CREATE POLICY "Teachers can view lesson interactions" ON student_lesson_interactions
    FOR SELECT
    USING (
        lesson_id IN (
            SELECT id FROM lessons WHERE teacher_id = auth.uid()
        )
    );

-- ============================================================================
-- POLICY 3: Students can create interactions in their lessons
-- ============================================================================
-- Purpose: Allow students to record activity in lessons they participate in
-- Scope: INSERT operations
-- Security: Student ownership + lesson participation validation

CREATE POLICY "Students can create interactions" ON student_lesson_interactions
    FOR INSERT
    WITH CHECK (
        student_id = auth.uid() AND
        lesson_id IN (
            SELECT lesson_id FROM lesson_participants 
            WHERE user_id = auth.uid()
        )
    );

-- ============================================================================
-- POLICY 4: Students can update their own interactions
-- ============================================================================
-- Purpose: Allow students to modify their interaction records (e.g., add notes)
-- Scope: UPDATE operations
-- Security: Student ownership validation

CREATE POLICY "Students can update own interactions" ON student_lesson_interactions
    FOR UPDATE
    USING (student_id = auth.uid());

-- ============================================================================
-- SECURITY NOTES
-- ============================================================================
/*
Security Model for student_lesson_interactions:
- Real-time classroom activity tracking
- Students control their interaction data
- Teachers monitor engagement in their lessons
- Participation validation ensures appropriate access

Interaction Types Tracked:
- Question asking/answering
- Discussion participation
- Resource access events
- Assignment submissions
- Attention and engagement metrics

Privacy Features:
- Students see only their own activity
- Teachers see all activity in their lessons
- No cross-lesson data visibility
- Personal learning behavior protected

Educational Analytics:
- Teacher monitors class engagement
- Student tracks personal participation
- Identifies learning pattern trends
- Supports personalized instruction

Data Security:
- Student ownership prevents cross-access
- Lesson participation validation
- Teacher scope limited to their classes
- Authentication required for all operations

Classroom Management:
- Real-time engagement monitoring
- Participation pattern analysis
- Student behavior insights
- Interactive learning support

Access Patterns:
1. Student participates in lesson activity
2. System records interaction automatically
3. Teacher reviews engagement analytics
4. Student views personal activity history

Data Types:
- Participation timestamps
- Interaction quality metrics
- Engagement duration
- Activity context information

Protection Goals:
- Maintain student activity privacy
- Enable teacher classroom insights
- Support engagement optimization
- Prevent unauthorized access

Security Validation:
- All operations require authentication
- Student must be enrolled in lesson
- Teacher must own the lesson
- No anonymous interaction recording
*/