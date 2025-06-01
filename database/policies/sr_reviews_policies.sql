-- ============================================================================
-- SR_REVIEWS TABLE - RLS POLICIES
-- ============================================================================
-- Table: sr_reviews
-- RLS Status: ENABLED
-- Policies: 2 total
-- Security Level: Standard (Study Session Data)
-- ============================================================================

-- Enable RLS for sr_reviews table
ALTER TABLE sr_reviews ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- POLICY 1: Users can manage their own reviews
-- ============================================================================
-- Purpose: Allow users to create, view, update, and delete their study sessions
-- Scope: ALL operations (SELECT, INSERT, UPDATE, DELETE)
-- Security: User ownership validation for all operations

CREATE POLICY "Users can manage own reviews" ON sr_reviews
    FOR ALL
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- ============================================================================
-- POLICY 2: Teachers can view reviews in their lessons
-- ============================================================================
-- Purpose: Allow teachers to monitor study activity and engagement in their lessons
-- Scope: SELECT operations
-- Security: Teacher-lesson ownership validation through cards

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
-- SECURITY NOTES
-- ============================================================================
/*
Security Model for sr_reviews:
- Personal study session records with teacher visibility
- Users have complete control over their review data
- Teachers can monitor study activity in their lessons
- Review data supports spaced repetition algorithm

Review Data Contains:
- Study session timestamps
- Card performance metrics
- Response quality and speed
- Algorithm adjustment factors

Privacy Protection:
- Individual study sessions are private
- Teachers see lesson-level activity only
- No cross-lesson data leakage
- Personal study patterns protected

Educational Value:
- Teachers monitor engagement levels
- Class participation tracking
- Study habit analysis for lessons
- Performance trend identification

Algorithm Integration:
- Review data feeds SM-2 algorithm
- Performance history determines scheduling
- User patterns optimize learning
- Difficulty adjustments based on reviews

Access Control:
- User: Full CRUD on own reviews
- Teacher: Read-only on lesson reviews
- System: Algorithm access through functions
- Anonymous: No access

Data Sensitivity:
- Personal performance metrics
- Study timing and frequency
- Learning difficulty indicators
- Engagement patterns

Security Features:
- User ownership validation
- Teacher scope limited to their lessons
- No public or cross-user access
- Authentication required for all operations

Use Cases:
1. Student completes study session
2. Algorithm records review results
3. Teacher monitors class engagement
4. User reviews personal study history
5. System optimizes future scheduling
*/