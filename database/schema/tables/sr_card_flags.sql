-- =====================================================
-- TABLE: sr_card_flags
-- Description: Quality control flags for spaced repetition cards
-- =====================================================

CREATE TABLE sr_card_flags (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    card_id UUID NOT NULL REFERENCES sr_cards(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    flag_type TEXT NOT NULL CHECK (flag_type IN ('incorrect', 'unclear', 'duplicate', 'inappropriate', 'outdated')),
    comments TEXT,
    date_flagged TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    status TEXT DEFAULT 'open' CHECK (status IN ('open', 'resolved', 'dismissed')),
    resolution_notes TEXT,
    resolved_by UUID REFERENCES profiles(id),
    resolved_at TIMESTAMP WITH TIME ZONE
);

-- Indexes
CREATE INDEX idx_sr_card_flags_card_id ON sr_card_flags(card_id);
CREATE INDEX idx_sr_card_flags_student_id ON sr_card_flags(student_id);
CREATE INDEX idx_sr_card_flags_status ON sr_card_flags(status);

-- Triggers
CREATE TRIGGER update_sr_card_flags_updated_at 
    BEFORE UPDATE ON sr_card_flags 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Comments
COMMENT ON TABLE sr_card_flags IS 'Quality control flags for spaced repetition cards';
COMMENT ON COLUMN sr_card_flags.flag_type IS 'Type of issue: incorrect, unclear, duplicate, inappropriate, or outdated';
COMMENT ON COLUMN sr_card_flags.status IS 'Flag status: open, resolved, or dismissed';
COMMENT ON COLUMN sr_card_flags.resolution_notes IS 'Notes on how the flag was resolved';