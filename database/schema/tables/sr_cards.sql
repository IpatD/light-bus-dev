-- =====================================================
-- TABLE: sr_cards (Spaced Repetition Cards)
-- Description: Flashcards created from lesson content for spaced repetition
-- =====================================================

CREATE TABLE sr_cards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
    front_content TEXT NOT NULL,
    back_content TEXT NOT NULL,
    card_type TEXT DEFAULT 'basic' CHECK (card_type IN ('basic', 'cloze', 'multiple_choice', 'true_false')),
    difficulty_level INTEGER DEFAULT 1 CHECK (difficulty_level >= 1 AND difficulty_level <= 5),
    created_by UUID NOT NULL REFERENCES profiles(id),
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'archived')),
    approved_by UUID REFERENCES profiles(id),
    approved_at TIMESTAMP WITH TIME ZONE,
    tags TEXT[], -- Array of tags for categorization
    notes TEXT
);

-- Indexes
CREATE INDEX idx_sr_cards_lesson_id ON sr_cards(lesson_id);
CREATE INDEX idx_sr_cards_created_by ON sr_cards(created_by);
CREATE INDEX idx_sr_cards_status ON sr_cards(status);
CREATE INDEX idx_sr_cards_difficulty ON sr_cards(difficulty_level);

-- Triggers
CREATE TRIGGER update_sr_cards_updated_at 
    BEFORE UPDATE ON sr_cards 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Comments
COMMENT ON TABLE sr_cards IS 'Flashcards for spaced repetition learning system';
COMMENT ON COLUMN sr_cards.card_type IS 'Type of card: basic, cloze (fill-in-the-blank), multiple_choice, or true_false';
COMMENT ON COLUMN sr_cards.difficulty_level IS 'Difficulty rating from 1 (easy) to 5 (very hard)';
COMMENT ON COLUMN sr_cards.status IS 'Review status: pending, approved, rejected, or archived';
COMMENT ON COLUMN sr_cards.tags IS 'Array of tags for categorization and filtering';