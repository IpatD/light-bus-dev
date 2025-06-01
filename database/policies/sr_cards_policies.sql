-- ============================================================================
-- SR_CARDS TABLE - RLS POLICIES
-- ============================================================================
-- Table: sr_cards
-- RLS Status: ENABLED
-- Policies: 8 total
-- Security Level: Standard (Core Learning Content)
-- ============================================================================

-- Enable RLS for sr_cards table
ALTER TABLE sr_cards ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- POLICY 1: Users can view their own cards
-- ============================================================================
-- Purpose: Allow users to access flashcards they created
-- Scope: SELECT operations
-- Security: User ownership validation

CREATE POLICY "Users can view own cards" ON sr_cards
    FOR SELECT
    USING (user_id = auth.uid());

-- ============================================================================
-- POLICY 2: Students can view cards in lessons they participate in
-- ============================================================================
-- Purpose: Allow students to study cards shared in their enrolled lessons
-- Scope: SELECT operations
-- Security: Lesson participation validation

CREATE POLICY "Students can view lesson cards" ON sr_cards
    FOR SELECT
    USING (
        lesson_id IN (
            SELECT lesson_id FROM lesson_participants 
            WHERE user_id = auth.uid()
        )
    );

-- ============================================================================
-- POLICY 3: Teachers can view cards in their lessons
-- ============================================================================
-- Purpose: Allow teachers to access all cards in lessons they teach
-- Scope: SELECT operations
-- Security: Teacher-lesson ownership validation

CREATE POLICY "Teachers can view lesson cards" ON sr_cards
    FOR SELECT
    USING (
        lesson_id IN (
            SELECT id FROM lessons WHERE teacher_id = auth.uid()
        )
    );

-- ============================================================================
-- POLICY 4: Users can create cards in lessons they participate in
-- ============================================================================
-- Purpose: Allow students to create study cards in their enrolled lessons
-- Scope: INSERT operations
-- Security: User ownership + lesson participation validation

CREATE POLICY "Users can create lesson cards" ON sr_cards
    FOR INSERT
    WITH CHECK (
        user_id = auth.uid() AND
        (lesson_id IS NULL OR lesson_id IN (
            SELECT lesson_id FROM lesson_participants 
            WHERE user_id = auth.uid()
        ))
    );

-- ============================================================================
-- POLICY 5: Teachers can create cards in their lessons
-- ============================================================================
-- Purpose: Allow teachers to create educational content for their lessons
-- Scope: INSERT operations
-- Security: Teacher-lesson ownership validation

CREATE POLICY "Teachers can create cards in lessons" ON sr_cards
    FOR INSERT
    WITH CHECK (
        lesson_id IN (
            SELECT id FROM lessons WHERE teacher_id = auth.uid()
        )
    );

-- ============================================================================
-- POLICY 6: Users can update their own cards
-- ============================================================================
-- Purpose: Allow users to edit and improve their own flashcards
-- Scope: UPDATE operations
-- Security: User ownership validation

CREATE POLICY "Users can update own cards" ON sr_cards
    FOR UPDATE
    USING (user_id = auth.uid());

-- ============================================================================
-- POLICY 7: Teachers can update cards in their lessons
-- ============================================================================
-- Purpose: Allow teachers to edit any cards in their lessons for quality control
-- Scope: UPDATE operations
-- Security: Teacher-lesson ownership validation

CREATE POLICY "Teachers can update lesson cards" ON sr_cards
    FOR UPDATE
    USING (
        lesson_id IN (
            SELECT id FROM lessons WHERE teacher_id = auth.uid()
        )
    );

-- ============================================================================
-- POLICY 8: Public cards are viewable by authenticated users
-- ============================================================================
-- Purpose: Allow discovery and sharing of high-quality educational content
-- Scope: SELECT operations
-- Security: Public flag validation + authentication required

CREATE POLICY "Public cards viewable by all" ON sr_cards
    FOR SELECT
    USING (is_public = true AND auth.uid() IS NOT NULL);

-- ============================================================================
-- SECURITY NOTES
-- ============================================================================
/*
Security Model for sr_cards:
- Core learning content with flexible sharing
- Users own their created cards
- Lesson-based sharing for collaborative learning
- Teacher oversight within their lessons
- Public cards for knowledge sharing

Content Access Levels:
1. Personal: User's own cards (full access)
2. Lesson: Cards shared within enrolled lessons
3. Public: Community-shared educational content
4. Teacher: Administrative access within their lessons

Card Creation Rules:
- Users can create personal cards (lesson_id = NULL)
- Users can create cards in lessons they participate in
- Teachers can create cards in any of their lessons
- All card creation requires authentication

Content Management:
- Users manage their own cards (CRUD)
- Teachers can edit any cards in their lessons
- Public cards discoverable by all authenticated users
- Private cards remain user/lesson restricted

Learning Scenarios:
1. Student creates personal study cards
2. Student shares cards in class lesson
3. Teacher creates lesson-specific content
4. Community shares public educational resources

Security Features:
- Ownership validation prevents unauthorized access
- Lesson participation ensures appropriate sharing
- Teacher authority within their classroom scope
- Public content requires authentication
- No anonymous access to any cards

Access Control Matrix:
- Card Owner: Full CRUD access
- Lesson Participants: View lesson cards
- Lesson Teacher: Full access to lesson cards
- Authenticated Users: View public cards only
- Anonymous Users: No access
*/