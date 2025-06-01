-- ============================================================================
-- SR_CARD_FLAGS TABLE - RLS POLICIES
-- ============================================================================
-- Table: sr_card_flags
-- RLS Status: ENABLED
-- Policies: 7 total
-- Security Level: Standard (Content Moderation)
-- ============================================================================

-- Enable RLS for sr_card_flags table
ALTER TABLE sr_card_flags ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- POLICY 1: Users can view flags on their own cards
-- ============================================================================
-- Purpose: Allow users to see flags raised on cards they created
-- Scope: SELECT operations
-- Security: Card ownership validation through sr_cards table

CREATE POLICY "Users can view own card flags" ON sr_card_flags
    FOR SELECT
    USING (
        card_id IN (
            SELECT id FROM sr_cards WHERE user_id = auth.uid()
        )
    );

-- ============================================================================
-- POLICY 2: Teachers can view flags on cards in their lessons
-- ============================================================================
-- Purpose: Allow teachers to monitor content quality in their lessons
-- Scope: SELECT operations
-- Security: Teacher-lesson ownership validation through cards

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

-- ============================================================================
-- POLICY 3: Users can create flags on their own cards
-- ============================================================================
-- Purpose: Allow users to flag their own cards for review/improvement
-- Scope: INSERT operations
-- Security: Card ownership + flagger validation

CREATE POLICY "Users can flag own cards" ON sr_card_flags
    FOR INSERT
    WITH CHECK (
        card_id IN (
            SELECT id FROM sr_cards WHERE user_id = auth.uid()
        ) AND flagger_id = auth.uid()
    );

-- ============================================================================
-- POLICY 4: Teachers can create flags on lesson cards
-- ============================================================================
-- Purpose: Allow teachers to flag inappropriate or incorrect cards in their lessons
-- Scope: INSERT operations
-- Security: Teacher-lesson ownership + flagger validation

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

-- ============================================================================
-- POLICY 5: Moderators can view all flags
-- ============================================================================
-- Purpose: Allow content moderators to review all flagged content
-- Scope: SELECT operations
-- Security: Moderator role validation

CREATE POLICY "Moderators can view all flags" ON sr_card_flags
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'moderator'
        )
    );

-- ============================================================================
-- POLICY 6: Moderators can update flag status
-- ============================================================================
-- Purpose: Allow moderators to resolve flags and update their status
-- Scope: UPDATE operations
-- Security: Moderator role validation

CREATE POLICY "Moderators can update flags" ON sr_card_flags
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND role = 'moderator'
        )
    );

-- ============================================================================
-- POLICY 7: Users can update their own flags
-- ============================================================================
-- Purpose: Allow flag creators to update or resolve their own flags
-- Scope: UPDATE operations
-- Security: Flagger ownership validation

CREATE POLICY "Users can update own flags" ON sr_card_flags
    FOR UPDATE
    USING (flagger_id = auth.uid());

-- ============================================================================
-- SECURITY NOTES
-- ============================================================================
/*
Security Model for sr_card_flags:
- Multi-tier content moderation system
- Users can flag content they own or encounter
- Teachers monitor lesson content quality
- Moderators have platform-wide oversight
- Flag ownership allows self-management

Moderation Hierarchy:
1. User Level: Flag own cards, update own flags
2. Teacher Level: Flag/view cards in their lessons
3. Moderator Level: Full flag management access

Flag Lifecycle:
1. User/Teacher creates flag on problematic content
2. Flag appears in moderation queue
3. Moderator reviews and updates status
4. Original flagger can track resolution

Security Features:
- Card ownership validation prevents unauthorized flagging
- Teacher scope limited to their lessons
- Moderator role validation for privileged operations
- Flagger identity tracking for accountability

Content Protection:
- Prevents spam flagging of unrelated content
- Maintains teacher classroom authority
- Enables platform-wide quality control
- Supports educational content standards

Access Control Matrix:
- Card Owner: View flags on own cards, flag own content
- Teacher: View/flag cards in their lessons
- Moderator: Full access to all flags
- Other Users: No access to flags
*/