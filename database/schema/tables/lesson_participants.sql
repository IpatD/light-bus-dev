-- =====================================================
-- TABLE: lesson_participants
-- Description: Many-to-many relationship between lessons and students
-- =====================================================

CREATE TABLE lesson_participants (
    lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (lesson_id, student_id)
);

-- Indexes
CREATE INDEX idx_lesson_participants_student_id ON lesson_participants(student_id);
CREATE INDEX idx_lesson_participants_assigned_at ON lesson_participants(assigned_at);

-- Comments
COMMENT ON TABLE lesson_participants IS 'Many-to-many relationship between lessons and students';
COMMENT ON COLUMN lesson_participants.assigned_at IS 'When the student was assigned to this lesson';