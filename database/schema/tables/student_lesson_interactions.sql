-- =====================================================
-- TABLE: student_lesson_interactions
-- Description: Track student engagement with lessons
-- =====================================================

CREATE TABLE student_lesson_interactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    student_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
    first_viewed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_viewed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    view_count INTEGER DEFAULT 1,
    interaction_type TEXT DEFAULT 'view' CHECK (interaction_type IN ('view', 'study', 'review', 'complete'))
);

-- Indexes
CREATE INDEX idx_student_interactions_student_lesson ON student_lesson_interactions(student_id, lesson_id);
CREATE INDEX idx_student_interactions_last_viewed ON student_lesson_interactions(last_viewed_at);

-- Triggers
CREATE TRIGGER update_student_interactions_updated_at 
    BEFORE UPDATE ON student_lesson_interactions 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Comments
COMMENT ON TABLE student_lesson_interactions IS 'Track student engagement and interaction patterns with lessons';
COMMENT ON COLUMN student_lesson_interactions.interaction_type IS 'Type of interaction: view, study, review, or complete';
COMMENT ON COLUMN student_lesson_interactions.view_count IS 'Number of times the student has accessed this lesson';