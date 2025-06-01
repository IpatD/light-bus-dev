-- =====================================================
-- TABLE: sr_progress
-- Description: Aggregated progress tracking for students per lesson
-- =====================================================

CREATE TABLE sr_progress (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    student_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
    cards_total INTEGER DEFAULT 0,
    cards_reviewed INTEGER DEFAULT 0,
    cards_mastered INTEGER DEFAULT 0, -- Cards with ease_factor > threshold
    first_review_date TIMESTAMP WITH TIME ZONE,
    last_review_date TIMESTAMP WITH TIME ZONE,
    next_review_date TIMESTAMP WITH TIME ZONE,
    average_quality_rating DECIMAL(3,2),
    total_review_time_ms BIGINT DEFAULT 0,
    UNIQUE(student_id, lesson_id)
);

-- Indexes
CREATE INDEX idx_sr_progress_student_lesson ON sr_progress(student_id, lesson_id);
CREATE INDEX idx_sr_progress_next_review ON sr_progress(next_review_date);

-- Triggers
CREATE TRIGGER update_sr_progress_updated_at 
    BEFORE UPDATE ON sr_progress 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Comments
COMMENT ON TABLE sr_progress IS 'Aggregated progress tracking for students per lesson';
COMMENT ON COLUMN sr_progress.cards_mastered IS 'Number of cards considered mastered (high ease factor)';
COMMENT ON COLUMN sr_progress.average_quality_rating IS 'Average quality rating across all reviews for this lesson';
COMMENT ON COLUMN sr_progress.total_review_time_ms IS 'Total time spent reviewing cards for this lesson in milliseconds';