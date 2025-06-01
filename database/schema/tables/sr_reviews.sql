-- =====================================================
-- TABLE: sr_reviews
-- Description: Individual review sessions for spaced repetition cards
-- =====================================================

CREATE TABLE sr_reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    card_id UUID NOT NULL REFERENCES sr_cards(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    scheduled_for TIMESTAMP WITH TIME ZONE NOT NULL,
    completed_at TIMESTAMP WITH TIME ZONE,
    quality_rating INTEGER CHECK (quality_rating >= 0 AND quality_rating <= 5), -- SM-2 algorithm rating
    interval_days INTEGER, -- Days until next review
    ease_factor DECIMAL(3,2) DEFAULT 2.50, -- SM-2 algorithm ease factor
    repetition_count INTEGER DEFAULT 0,
    response_time_ms INTEGER, -- Time taken to respond in milliseconds
    notes TEXT
);

-- Indexes
CREATE INDEX idx_sr_reviews_card_id ON sr_reviews(card_id);
CREATE INDEX idx_sr_reviews_student_id ON sr_reviews(student_id);
CREATE INDEX idx_sr_reviews_scheduled_for ON sr_reviews(scheduled_for);
CREATE INDEX idx_sr_reviews_completed_at ON sr_reviews(completed_at);

-- Comments
COMMENT ON TABLE sr_reviews IS 'Individual review sessions tracking spaced repetition progress';
COMMENT ON COLUMN sr_reviews.quality_rating IS 'SM-2 algorithm quality rating (0-5): 0=blackout, 1=incorrect, 2=incorrect but remembered, 3=correct with difficulty, 4=correct, 5=perfect';
COMMENT ON COLUMN sr_reviews.interval_days IS 'Number of days until the next scheduled review';
COMMENT ON COLUMN sr_reviews.ease_factor IS 'SM-2 algorithm ease factor (minimum 1.30)';
COMMENT ON COLUMN sr_reviews.response_time_ms IS 'Time taken to respond in milliseconds';