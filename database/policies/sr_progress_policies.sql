-- ============================================================================
-- SR_PROGRESS TABLE - RLS POLICIES
-- ============================================================================
-- Table: sr_progress
-- RLS Status: ENABLED
-- Policies: 3 total
-- Security Level: Standard (Personal Learning Data)
-- ============================================================================

-- Enable RLS for sr_progress table
ALTER TABLE sr_progress ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- POLICY 1: Users can view their own progress
-- ============================================================================
-- Purpose: Allow users to track their personal learning progress
-- Scope: SELECT operations
-- Security: User ownership validation

CREATE POLICY "Users can view own progress" ON sr_progress
    FOR SELECT
    USING (user_id = auth.uid());

-- ============================================================================
-- POLICY 2: Teachers can view progress in their lessons
-- ============================================================================
-- Purpose: Allow teachers to monitor student progress in their lessons
-- Scope: SELECT operations
-- Security: Teacher-lesson ownership validation through cards

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

-- ============================================================================
-- POLICY 3: Users can update their own progress
-- ============================================================================
-- Purpose: Allow users to record study sessions and progress updates
-- Scope: ALL operations (INSERT, UPDATE, DELETE)
-- Security: User ownership validation for all operations

CREATE POLICY "Users can update own progress" ON sr_progress
    FOR ALL
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- ============================================================================
-- SECURITY NOTES
-- ============================================================================
/*
Security Model for sr_progress:
- Personal learning data with teacher oversight
- Users have full control over their progress records
- Teachers can monitor student progress in their lessons
- Progress data is always private to user + their teachers

Data Privacy:
- Progress records are personal and sensitive
- Only user and their teachers can access
- No public or cross-user access
- Spaced repetition algorithm data protected

Learning Analytics:
- Users track their own learning patterns
- Teachers monitor class progress for instruction
- Algorithm uses progress for optimal scheduling
- Data supports personalized learning paths

Progress Operations:
- Users create progress records during study
- Users update progress when reviewing cards
- Users can delete incorrect progress entries
- Teachers view aggregated progress in their lessons

Security Features:
- User ownership validation for all operations
- Teacher access limited to their lesson cards
- No anonymous access to progress data
- Private progress prevents competitive pressure

Access Patterns:
1. Student studies cards and records progress
2. Algorithm queries progress for scheduling
3. Teacher reviews class progress for insights
4. User analyzes personal learning patterns

Data Sensitivity:
- Performance data (accuracy, timing)
- Study habits and patterns
- Learning difficulty indicators
- Personal motivation metrics

Protection Goals:
- Maintain student privacy
- Enable teacher classroom insights
- Support algorithm functionality
- Prevent data misuse or sharing
*/