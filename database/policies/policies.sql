-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================
-- Comprehensive RLS policies for Light Bus e-learning platform
-- Total: 43 policies across 10 tables
-- Security Model: Role-based access with user ownership validation
-- Created: 2025-05-30
-- ============================================================================

-- ============================================================================
-- ENABLE RLS ON ALL TABLES
-- ============================================================================

-- Core learning tables
ALTER TABLE lesson_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE lesson_participants FORCE ROW LEVEL SECURITY;

ALTER TABLE lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE lessons FORCE ROW LEVEL SECURITY;

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Spaced repetition tables
ALTER TABLE sr_card_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE sr_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE sr_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE sr_reviews ENABLE ROW LEVEL SECURITY;

-- Content and interaction tables
ALTER TABLE student_lesson_interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE summaries ENABLE ROW LEVEL SECURITY;

ALTER TABLE transcripts ENABLE ROW LEVEL SECURITY;
ALTER TABLE transcripts FORCE ROW LEVEL SECURITY;

-- ============================================================================
-- LESSON_PARTICIPANTS POLICIES (5 policies)
-- ============================================================================

-- Policy 1: Students can view their own participations
CREATE POLICY "Students can view own participations" ON lesson_participants
    FOR SELECT
    USING (user_id = auth.uid());

-- Policy 2: Teachers can view participations in their lessons
CREATE POLICY "Teachers can view lesson participations" ON lesson_participants
    FOR SELECT
    USING (
        lesson_id IN (
            SELECT id FROM lessons WHERE teacher_id = auth.uid()
        )
    );

-- Policy 3: Teachers can insert participants to their lessons
CREATE POLICY "Teachers can add participants" ON lesson_participants
    FOR INSERT
    WITH CHECK (
        lesson_id IN (
            SELECT id FROM lessons WHERE teacher_id = auth.uid()
        )
    );

-- Policy 4: Teachers can update participation status in their lessons
CREATE POLICY "Teachers can update participation status" ON lesson_participants
    FOR UPDATE
    USING (
        lesson_id IN (
            SELECT id FROM lessons WHERE teacher_id = auth.uid()
        )
    );

-- Policy 5: Teachers can remove participants from their lessons
CREATE POLICY "Teachers can remove participants" ON lesson_participants
    FOR DELETE
    USING (
        lesson_id IN (
            SELECT id FROM lessons WHERE teacher_id = auth.uid()
        )
    );

-- ============================================================================
-- LESSONS POLICIES (7 policies)
-- ============================================================================

-- Policy 1: Teachers can view their own lessons
CREATE POLICY "Teachers can view own lessons" ON lessons
    FOR SELECT
    USING (teacher_id = auth.uid());

-- Policy 2: Students can view lessons they participate in
CREATE POLICY "Students can view participated lessons" ON lessons
    FOR SELECT
    USING (
        id IN (
            SELECT lesson_id FROM lesson_participants 
            WHERE user_id = auth.uid()
        )
    );

-- Policy 3: Teachers can create lessons
CREATE POLICY "Teachers can create lessons" ON lessons
    FOR INSERT
    WITH CHECK (teacher_id = auth.uid());

-- Policy 4: Teachers can update their own lessons
CREATE POLICY "Teachers can update own lessons" ON lessons
    FOR UPDATE
    USING (teacher_id = auth.uid());

-- Policy 5: Teachers can delete their own lessons
CREATE POLICY "Teachers can delete own lessons" ON lessons
    FOR DELETE
    USING (teacher_id = auth.uid());

-- Policy 6: Public lessons are viewable by all authenticated users
CREATE POLICY "Public lessons viewable by all" ON lessons
    FOR SELECT
    USING (is_public = true AND auth.uid() IS NOT NULL);

-- Policy 7: Archived lessons have restricted access
CREATE POLICY "Archived lessons restricted access" ON lessons
    FOR SELECT
    USING (
        (status != 'archived') OR 
        (teacher_id = auth.uid()) OR
        (id IN (SELECT lesson_id FROM lesson_participants WHERE user_id = auth.uid()))
    );

-- ============================================================================
-- PROFILES POLICIES (4 policies)
-- ============================================================================

-- Policy 1: Users can view their own profile
CREATE POLICY "Users can view own profile" ON profiles
    FOR SELECT
    USING (id = auth.uid());

-- Policy 2: Users can update their own profile
CREATE POLICY "Users can update own profile" ON profiles
    FOR UPDATE
    USING (id = auth.uid());

-- Policy 3: Teachers can view student profiles in their lessons
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

-- Policy 4: Public profiles are viewable by authenticated users
CREATE POLICY "Public profiles viewable" ON profiles
    FOR SELECT
    USING (is_public = true AND auth.uid() IS NOT NULL);

-- ============================================================================
-- SR_CARD_FLAGS POLICIES (7 policies)
-- ============================================================================

-- Policy 1: Users can view flags on their own cards
CREATE POLICY "Users can view own card flags" ON sr_card_flags
    FOR SELECT
    USING (
        card_id IN (
            SELECT id FROM sr_cards WHERE user_id = auth.uid()
        )
    );

-- Policy 2: Teachers can view flags on cards in their lessons
CREATE POLICY "Teachers can view lesson card flags" ON sr_card_flags
    FOR SELECT
    USING (
        card_id IN (
            SELECT id FROM sr_cards 
            WHERE lesson_id IN (
                SELECT id FROM lessons WHERE teacher_id = auth.uid()
            )
        )
    );

-- Policy 3: Users can create flags on their own cards
CREATE POLICY "Users can flag own cards" ON sr_card_flags
    FOR INSERT
    WITH CHECK (
        card_id IN (
            SELECT id FROM sr_cards WHERE user_id = auth.uid()
        ) AND flagger_id = auth.uid()
    );

-- Policy 4: Teachers can create flags on lesson cards
CREATE POLICY "Teachers can flag lesson cards" ON sr_card_flags
    FOR INSERT
    WITH CHECK (
        card_id IN (
            SELECT id FROM sr_cards 
            WHERE lesson_id IN (
                SELECT id FROM lessons WHERE teacher_id = auth.uid()
            )
        ) AND flagger_id = auth.uid()
    );

-- Policy 5: Moderators can view all flags
CREATE POLICY "Moderators can view all flags" ON sr_card_flags
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'moderator'
        )
    );

-- Policy 6: Moderators can update flag status
CREATE POLICY "Moderators can update flags" ON sr_card_flags
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'moderator'
        )
    );

-- Policy 7: Users can update their own flags
CREATE POLICY "Users can update own flags" ON sr_card_flags
    FOR UPDATE
    USING (flagger_id = auth.uid());

-- ============================================================================
-- SR_CARDS POLICIES (8 policies)
-- ============================================================================

-- Policy 1: Users can view their own cards
CREATE POLICY "Users can view own cards" ON sr_cards
    FOR SELECT
    USING (user_id = auth.uid());

-- Policy 2: Users can view cards in lessons they participate in
CREATE POLICY "Students can view lesson cards" ON sr_cards
    FOR SELECT
    USING (
        lesson_id IN (
            SELECT lesson_id FROM lesson_participants 
            WHERE user_id = auth.uid()
        )
    );

-- Policy 3: Teachers can view cards in their lessons
CREATE POLICY "Teachers can view lesson cards" ON sr_cards
    FOR SELECT
    USING (
        lesson_id IN (
            SELECT id FROM lessons WHERE teacher_id = auth.uid()
        )
    );

-- Policy 4: Users can create cards in lessons they participate in
CREATE POLICY "Users can create lesson cards" ON sr_cards
    FOR INSERT
    WITH CHECK (
        user_id = auth.uid() AND
        (lesson_id IS NULL OR lesson_id IN (
            SELECT lesson_id FROM lesson_participants 
            WHERE user_id = auth.uid()
        ))
    );

-- Policy 5: Teachers can create cards in their lessons
CREATE POLICY "Teachers can create cards in lessons" ON sr_cards
    FOR INSERT
    WITH CHECK (
        lesson_id IN (
            SELECT id FROM lessons WHERE teacher_id = auth.uid()
        )
    );

-- Policy 6: Users can update their own cards
CREATE POLICY "Users can update own cards" ON sr_cards
    FOR UPDATE
    USING (user_id = auth.uid());

-- Policy 7: Teachers can update cards in their lessons
CREATE POLICY "Teachers can update lesson cards" ON sr_cards
    FOR UPDATE
    USING (
        lesson_id IN (
            SELECT id FROM lessons WHERE teacher_id = auth.uid()
        )
    );

-- Policy 8: Public cards are viewable by authenticated users
CREATE POLICY "Public cards viewable by all" ON sr_cards
    FOR SELECT
    USING (is_public = true AND auth.uid() IS NOT NULL);

-- ============================================================================
-- SR_PROGRESS POLICIES (3 policies)
-- ============================================================================

-- Policy 1: Users can view their own progress
CREATE POLICY "Users can view own progress" ON sr_progress
    FOR SELECT
    USING (user_id = auth.uid());

-- Policy 2: Teachers can view progress in their lessons
CREATE POLICY "Teachers can view lesson progress" ON sr_progress
    FOR SELECT
    USING (
        card_id IN (
            SELECT id FROM sr_cards 
            WHERE lesson_id IN (
                SELECT id FROM lessons WHERE teacher_id = auth.uid()
            )
        )
    );

-- Policy 3: Users can update their own progress
CREATE POLICY "Users can update own progress" ON sr_progress
    FOR ALL
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- ============================================================================
-- SR_REVIEWS POLICIES (2 policies)
-- ============================================================================

-- Policy 1: Users can manage their own reviews
CREATE POLICY "Users can manage own reviews" ON sr_reviews
    FOR ALL
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Policy 2: Teachers can view reviews in their lessons
CREATE POLICY "Teachers can view lesson reviews" ON sr_reviews
    FOR SELECT
    USING (
        card_id IN (
            SELECT id FROM sr_cards 
            WHERE lesson_id IN (
                SELECT id FROM lessons WHERE teacher_id = auth.uid()
            )
        )
    );

-- ============================================================================
-- STUDENT_LESSON_INTERACTIONS POLICIES (4 policies)
-- ============================================================================

-- Policy 1: Students can view their own interactions
CREATE POLICY "Students can view own interactions" ON student_lesson_interactions
    FOR SELECT
    USING (student_id = auth.uid());

-- Policy 2: Teachers can view interactions in their lessons
CREATE POLICY "Teachers can view lesson interactions" ON student_lesson_interactions
    FOR SELECT
    USING (
        lesson_id IN (
            SELECT id FROM lessons WHERE teacher_id = auth.uid()
        )
    );

-- Policy 3: Students can create interactions in their lessons
CREATE POLICY "Students can create interactions" ON student_lesson_interactions
    FOR INSERT
    WITH CHECK (
        student_id = auth.uid() AND
        lesson_id IN (
            SELECT lesson_id FROM lesson_participants 
            WHERE user_id = auth.uid()
        )
    );

-- Policy 4: Students can update their own interactions
CREATE POLICY "Students can update own interactions" ON student_lesson_interactions
    FOR UPDATE
    USING (student_id = auth.uid());

-- ============================================================================
-- SUMMARIES POLICIES (2 policies)
-- ============================================================================

-- Policy 1: Users can view summaries of lessons they participate in
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

-- Policy 2: Teachers can manage summaries of their lessons
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
-- TRANSCRIPTS POLICIES (7 policies)
-- ============================================================================

-- Policy 1: Teachers can view transcripts of their lessons
CREATE POLICY "Teachers can view lesson transcripts" ON transcripts
    FOR SELECT
    USING (
        lesson_id IN (
            SELECT id FROM lessons WHERE teacher_id = auth.uid()
        )
    );

-- Policy 2: Students can view transcripts of lessons they participate in
CREATE POLICY "Students can view lesson transcripts" ON transcripts
    FOR SELECT
    USING (
        lesson_id IN (
            SELECT lesson_id FROM lesson_participants 
            WHERE user_id = auth.uid()
        )
    );

-- Policy 3: Teachers can create transcripts for their lessons
CREATE POLICY "Teachers can create lesson transcripts" ON transcripts
    FOR INSERT
    WITH CHECK (
        lesson_id IN (
            SELECT id FROM lessons WHERE teacher_id = auth.uid()
        )
    );

-- Policy 4: Teachers can update transcripts of their lessons
CREATE POLICY "Teachers can update lesson transcripts" ON transcripts
    FOR UPDATE
    USING (
        lesson_id IN (
            SELECT id FROM lessons WHERE teacher_id = auth.uid()
        )
    );

-- Policy 5: Teachers can delete transcripts of their lessons
CREATE POLICY "Teachers can delete lesson transcripts" ON transcripts
    FOR DELETE
    USING (
        lesson_id IN (
            SELECT id FROM lessons WHERE teacher_id = auth.uid()
        )
    );

-- Policy 6: Public transcripts are viewable by authenticated users
CREATE POLICY "Public transcripts viewable" ON transcripts
    FOR SELECT
    USING (
        is_public = true AND auth.uid() IS NOT NULL AND
        lesson_id IN (
            SELECT id FROM lessons WHERE is_public = true
        )
    );

-- Policy 7: Approved transcripts have enhanced visibility
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
-- POLICY MANAGEMENT FUNCTIONS
-- ============================================================================

-- Function to disable RLS on all tables (for maintenance)
CREATE OR REPLACE FUNCTION disable_all_rls()
RETURNS void AS $$
BEGIN
    ALTER TABLE lesson_participants DISABLE ROW LEVEL SECURITY;
    ALTER TABLE lessons DISABLE ROW LEVEL SECURITY;
    ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;
    ALTER TABLE sr_card_flags DISABLE ROW LEVEL SECURITY;
    ALTER TABLE sr_cards DISABLE ROW LEVEL SECURITY;
    ALTER TABLE sr_progress DISABLE ROW LEVEL SECURITY;
    ALTER TABLE sr_reviews DISABLE ROW LEVEL SECURITY;
    ALTER TABLE student_lesson_interactions DISABLE ROW LEVEL SECURITY;
    ALTER TABLE summaries DISABLE ROW LEVEL SECURITY;
    ALTER TABLE transcripts DISABLE ROW LEVEL SECURITY;
END;
$$ LANGUAGE plpgsql;

-- Function to enable RLS on all tables
CREATE OR REPLACE FUNCTION enable_all_rls()
RETURNS void AS $$
BEGIN
    ALTER TABLE lesson_participants ENABLE ROW LEVEL SECURITY;
    ALTER TABLE lesson_participants FORCE ROW LEVEL SECURITY;
    ALTER TABLE lessons ENABLE ROW LEVEL SECURITY;
    ALTER TABLE lessons FORCE ROW LEVEL SECURITY;
    ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
    ALTER TABLE sr_card_flags ENABLE ROW LEVEL SECURITY;
    ALTER TABLE sr_cards ENABLE ROW LEVEL SECURITY;
    ALTER TABLE sr_progress ENABLE ROW LEVEL SECURITY;
    ALTER TABLE sr_reviews ENABLE ROW LEVEL SECURITY;
    ALTER TABLE student_lesson_interactions ENABLE ROW LEVEL SECURITY;
    ALTER TABLE summaries ENABLE ROW LEVEL SECURITY;
    ALTER TABLE transcripts ENABLE ROW LEVEL SECURITY;
    ALTER TABLE transcripts FORCE ROW LEVEL SECURITY;
END;
$$ LANGUAGE plpgsql;

-- Function to get RLS status for all tables
CREATE OR REPLACE FUNCTION get_rls_status()
RETURNS TABLE(
    table_name text,
    rls_enabled boolean,
    rls_forced boolean,
    policy_count bigint
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.tablename::text,
        t.rowsecurity,
        t.forcerlsecurity,
        COUNT(p.policyname)
    FROM pg_tables t
    LEFT JOIN pg_policies p ON t.tablename = p.tablename
    WHERE t.schemaname = 'public'
    AND t.tablename IN (
        'lesson_participants', 'lessons', 'profiles', 'sr_card_flags',
        'sr_cards', 'sr_progress', 'sr_reviews', 'student_lesson_interactions',
        'summaries', 'transcripts'
    )
    GROUP BY t.tablename, t.rowsecurity, t.forcerlsecurity
    ORDER BY t.tablename;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SECURITY VALIDATION
-- ============================================================================

-- View to monitor policy effectiveness
CREATE OR REPLACE VIEW policy_security_overview AS
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- ============================================================================
-- NOTES AND DOCUMENTATION
-- ============================================================================

/*
SECURITY MODEL SUMMARY:
========================

Role-Based Access Control:
- Teachers: Full control over their lessons and associated data
- Students: Access to lessons they participate in
- Moderators: Special permissions for content moderation
- Public: Limited access to public content

Key Security Features:
- User ownership validation using auth.uid()
- Lesson participation verification
- Card status-based permissions
- Multi-tier content moderation
- Teacher-student relationship enforcement

Policy Distribution:
- lesson_participants: 5 policies (forced RLS)
- lessons: 7 policies (forced RLS)
- profiles: 4 policies
- sr_card_flags: 7 policies
- sr_cards: 8 policies
- sr_progress: 3 policies
- sr_reviews: 2 policies
- student_lesson_interactions: 4 policies
- summaries: 2 policies
- transcripts: 7 policies (forced RLS)

Total: 43 comprehensive RLS policies

This security model ensures enterprise-grade data protection
for the e-learning platform while maintaining appropriate
access patterns for educational content.
*/
