-- =====================================================
-- TABLE: summaries
-- Description: AI-generated or manual summaries of lessons
-- =====================================================

CREATE TABLE summaries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
    content TEXT NOT NULL
);

-- Indexes
CREATE INDEX idx_summaries_lesson_id ON summaries(lesson_id);

-- Comments
COMMENT ON TABLE summaries IS 'AI-generated or manual summaries of lessons';
COMMENT ON COLUMN summaries.content IS 'Summary content of the lesson';