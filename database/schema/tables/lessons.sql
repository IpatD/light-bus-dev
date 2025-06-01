-- =====================================================
-- TABLE: lessons
-- Description: Core lesson records with metadata and processing status
-- =====================================================

CREATE TABLE lessons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    date DATE NOT NULL,
    teacher_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    duration INTEGER, -- Duration in seconds
    file_size BIGINT, -- File size in bytes
    upload_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    has_audio BOOLEAN DEFAULT FALSE,
    has_transcript BOOLEAN DEFAULT FALSE,
    has_summary BOOLEAN DEFAULT FALSE,
    name TEXT NOT NULL,
    recording_path TEXT,
    transcription_progress INTEGER DEFAULT 0 CHECK (transcription_progress >= 0 AND transcription_progress <= 100)
);

-- Indexes
CREATE INDEX idx_lessons_teacher_id ON lessons(teacher_id);
CREATE INDEX idx_lessons_date ON lessons(date);
CREATE INDEX idx_lessons_created_at ON lessons(created_at);

-- Comments
COMMENT ON TABLE lessons IS 'Core lesson records with metadata and processing status';
COMMENT ON COLUMN lessons.duration IS 'Lesson duration in seconds';
COMMENT ON COLUMN lessons.file_size IS 'Recording file size in bytes';
COMMENT ON COLUMN lessons.transcription_progress IS 'Progress percentage (0-100) of transcription process';
COMMENT ON COLUMN lessons.recording_path IS 'Path to the lesson recording file';