-- =====================================================
-- TABLE: transcripts
-- Description: Transcribed content from lesson recordings
-- =====================================================

CREATE TABLE transcripts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    transcript_type TEXT DEFAULT 'auto' CHECK (transcript_type IN ('auto', 'manual', 'corrected'))
);

-- Indexes
CREATE INDEX idx_transcripts_lesson_id ON transcripts(lesson_id);

-- Comments
COMMENT ON TABLE transcripts IS 'Transcribed content from lesson recordings';
COMMENT ON COLUMN transcripts.transcript_type IS 'Type of transcript: auto (AI generated), manual (human created), or corrected (AI + human reviewed)';
COMMENT ON COLUMN transcripts.content IS 'Full text content of the lesson transcript';