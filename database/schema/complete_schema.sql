-- =====================================================
-- Complete Database Schema for Spaced Repetition Learning System
-- Generated: 2025-05-30
-- Description: Complete schema for a spaced repetition learning system
--             with lessons, transcripts, summaries, and flashcards
-- =====================================================

-- Enable UUID extension for primary keys
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- TABLE: profiles
-- Description: User profiles with roles (teachers, students, admins)
-- =====================================================
CREATE TABLE profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    name TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('teacher', 'student', 'admin')),
    email TEXT UNIQUE NOT NULL
);

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
    resolved_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(card_id, student_id, flag_type)
);

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
    interaction_type TEXT DEFAULT 'view' CHECK (interaction_type IN ('view', 'study', 'review', 'complete')),
    UNIQUE(student_id, lesson_id)
);

-- =====================================================
-- INDEXES for Performance Optimization
-- =====================================================

-- Profiles indexes
CREATE INDEX idx_profiles_email ON profiles(email);
CREATE INDEX idx_profiles_role ON profiles(role);

-- Lessons indexes
CREATE INDEX idx_lessons_teacher_id ON lessons(teacher_id);
CREATE INDEX idx_lessons_date ON lessons(date);
CREATE INDEX idx_lessons_created_at ON lessons(created_at);

-- Lesson participants indexes
CREATE INDEX idx_lesson_participants_student_id ON lesson_participants(student_id);
CREATE INDEX idx_lesson_participants_assigned_at ON lesson_participants(assigned_at);

-- Transcripts indexes
CREATE INDEX idx_transcripts_lesson_id ON transcripts(lesson_id);

-- Summaries indexes
CREATE INDEX idx_summaries_lesson_id ON summaries(lesson_id);

-- SR Cards indexes
CREATE INDEX idx_sr_cards_lesson_id ON sr_cards(lesson_id);
CREATE INDEX idx_sr_cards_created_by ON sr_cards(created_by);
CREATE INDEX idx_sr_cards_status ON sr_cards(status);
CREATE INDEX idx_sr_cards_difficulty ON sr_cards(difficulty_level);

-- SR Card flags indexes
CREATE INDEX idx_sr_card_flags_card_id ON sr_card_flags(card_id);
CREATE INDEX idx_sr_card_flags_student_id ON sr_card_flags(student_id);
CREATE INDEX idx_sr_card_flags_status ON sr_card_flags(status);

-- SR Reviews indexes
CREATE INDEX idx_sr_reviews_card_id ON sr_reviews(card_id);
CREATE INDEX idx_sr_reviews_student_id ON sr_reviews(student_id);
CREATE INDEX idx_sr_reviews_scheduled_for ON sr_reviews(scheduled_for);
CREATE INDEX idx_sr_reviews_completed_at ON sr_reviews(completed_at);

-- SR Progress indexes
CREATE INDEX idx_sr_progress_student_lesson ON sr_progress(student_id, lesson_id);
CREATE INDEX idx_sr_progress_next_review ON sr_progress(next_review_date);

-- Student lesson interactions indexes
CREATE INDEX idx_student_interactions_student_lesson ON student_lesson_interactions(student_id, lesson_id);
CREATE INDEX idx_student_interactions_last_viewed ON student_lesson_interactions(last_viewed_at);

-- =====================================================
-- UPDATED_AT TRIGGERS
-- =====================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply updated_at triggers to relevant tables
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_sr_cards_updated_at BEFORE UPDATE ON sr_cards FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_sr_card_flags_updated_at BEFORE UPDATE ON sr_card_flags FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_sr_progress_updated_at BEFORE UPDATE ON sr_progress FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_student_interactions_updated_at BEFORE UPDATE ON student_lesson_interactions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- RELATIONSHIP DOCUMENTATION
-- =====================================================

-- Core Entity Relationships:
-- profiles (1) → (M) lessons [teacher_id]
-- lessons (1) → (M) lesson_participants [lesson_id]
-- profiles (1) → (M) lesson_participants [student_id]
-- lessons (1) → (1) transcripts [lesson_id]
-- lessons (1) → (1) summaries [lesson_id]
-- lessons (1) → (M) sr_cards [lesson_id]
-- sr_cards (1) → (M) sr_card_flags [card_id]
-- profiles (1) → (M) sr_card_flags [student_id, resolved_by]
-- sr_cards (1) → (M) sr_reviews [card_id]
-- profiles (1) → (M) sr_reviews [student_id]
-- profiles (1) → (M) sr_progress [student_id]
-- lessons (1) → (M) sr_progress [lesson_id]
-- profiles (1) → (M) student_lesson_interactions [student_id]
-- lessons (1) → (M) student_lesson_interactions [lesson_id]
-- profiles (1) → (M) sr_cards [created_by, approved_by]

-- Unique Constraints Summary:
-- sr_card_flags: UNIQUE(card_id, student_id, flag_type)
-- sr_progress: UNIQUE(student_id, lesson_id)
-- student_lesson_interactions: UNIQUE(student_id, lesson_id)
-- profiles: UNIQUE(email)
-- lesson_participants: PRIMARY KEY(lesson_id, student_id)

-- For detailed constraint definitions, see: database/schema/constraints.sql

-- =====================================================
-- COMMENTS for Documentation
-- =====================================================

COMMENT ON TABLE profiles IS 'User profiles including teachers, students, and administrators';
COMMENT ON TABLE lessons IS 'Core lesson records with metadata and processing status';
COMMENT ON TABLE lesson_participants IS 'Many-to-many relationship between lessons and students';
COMMENT ON TABLE transcripts IS 'Transcribed content from lesson recordings';
COMMENT ON TABLE summaries IS 'AI-generated or manual summaries of lessons';
COMMENT ON TABLE sr_cards IS 'Flashcards for spaced repetition learning system';
COMMENT ON TABLE sr_card_flags IS 'Quality control flags for spaced repetition cards';
COMMENT ON TABLE sr_reviews IS 'Individual review sessions tracking spaced repetition progress';
COMMENT ON TABLE sr_progress IS 'Aggregated progress tracking for students per lesson';
COMMENT ON TABLE student_lesson_interactions IS 'Track student engagement and interaction patterns with lessons';

-- =====================================================
-- SCHEMA VERSION
-- =====================================================
CREATE TABLE IF NOT EXISTS schema_version (
    version VARCHAR(20) PRIMARY KEY,
    applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    description TEXT
);

INSERT INTO schema_version (version, description) 
VALUES ('1.0.0', 'Initial schema for spaced repetition learning system');