-- =====================================================
-- Database Constraints for Spaced Repetition Learning System
-- Generated: 2025-05-30
-- Description: All constraints, foreign keys, and relationships
-- =====================================================

-- =====================================================
-- PRIMARY KEY CONSTRAINTS
-- =====================================================

-- All tables have UUID primary keys (already defined in table creation)
-- lesson_participants has composite primary key (lesson_id, student_id)

-- =====================================================
-- FOREIGN KEY CONSTRAINTS
-- =====================================================

-- lesson_participants relationships
ALTER TABLE lesson_participants 
ADD CONSTRAINT fk_lesson_participants_lesson 
FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE;

ALTER TABLE lesson_participants 
ADD CONSTRAINT fk_lesson_participants_student 
FOREIGN KEY (student_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- lessons relationships
ALTER TABLE lessons 
ADD CONSTRAINT fk_lessons_teacher 
FOREIGN KEY (teacher_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- sr_card_flags relationships
ALTER TABLE sr_card_flags 
ADD CONSTRAINT fk_sr_card_flags_card 
FOREIGN KEY (card_id) REFERENCES sr_cards(id) ON DELETE CASCADE;

ALTER TABLE sr_card_flags 
ADD CONSTRAINT fk_sr_card_flags_student 
FOREIGN KEY (student_id) REFERENCES profiles(id) ON DELETE CASCADE;

ALTER TABLE sr_card_flags 
ADD CONSTRAINT fk_sr_card_flags_resolved_by 
FOREIGN KEY (resolved_by) REFERENCES profiles(id);

-- sr_cards relationships
ALTER TABLE sr_cards 
ADD CONSTRAINT fk_sr_cards_lesson 
FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE;

ALTER TABLE sr_cards 
ADD CONSTRAINT fk_sr_cards_created_by 
FOREIGN KEY (created_by) REFERENCES profiles(id);

ALTER TABLE sr_cards 
ADD CONSTRAINT fk_sr_cards_approved_by 
FOREIGN KEY (approved_by) REFERENCES profiles(id);

-- sr_progress relationships
ALTER TABLE sr_progress 
ADD CONSTRAINT fk_sr_progress_lesson 
FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE;

ALTER TABLE sr_progress 
ADD CONSTRAINT fk_sr_progress_student 
FOREIGN KEY (student_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- sr_reviews relationships
ALTER TABLE sr_reviews 
ADD CONSTRAINT fk_sr_reviews_card 
FOREIGN KEY (card_id) REFERENCES sr_cards(id) ON DELETE CASCADE;

ALTER TABLE sr_reviews 
ADD CONSTRAINT fk_sr_reviews_student 
FOREIGN KEY (student_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- student_lesson_interactions relationships
ALTER TABLE student_lesson_interactions 
ADD CONSTRAINT fk_student_interactions_lesson 
FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE;

ALTER TABLE student_lesson_interactions 
ADD CONSTRAINT fk_student_interactions_student 
FOREIGN KEY (student_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- summaries relationships
ALTER TABLE summaries 
ADD CONSTRAINT fk_summaries_lesson 
FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE;

-- transcripts relationships
ALTER TABLE transcripts 
ADD CONSTRAINT fk_transcripts_lesson 
FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE;

-- =====================================================
-- UNIQUE CONSTRAINTS
-- =====================================================

-- sr_card_flags: unique on (card_id, student_id, flag_type)
ALTER TABLE sr_card_flags 
ADD CONSTRAINT uk_sr_card_flags_card_student_type 
UNIQUE (card_id, student_id, flag_type);

-- sr_progress: unique on (student_id, lesson_id) - already exists in schema
-- ALTER TABLE sr_progress ADD CONSTRAINT uk_sr_progress_student_lesson UNIQUE (student_id, lesson_id);

-- student_lesson_interactions: unique on (student_id, lesson_id)
ALTER TABLE student_lesson_interactions 
ADD CONSTRAINT uk_student_interactions_student_lesson 
UNIQUE (student_id, lesson_id);

-- profiles: unique email constraint (already exists)
-- ALTER TABLE profiles ADD CONSTRAINT uk_profiles_email UNIQUE (email);

-- =====================================================
-- CHECK CONSTRAINTS
-- =====================================================

-- profiles role constraint (already exists)
-- ALTER TABLE profiles ADD CONSTRAINT chk_profiles_role CHECK (role IN ('teacher', 'student', 'admin'));

-- lessons transcription progress constraint (already exists)
-- ALTER TABLE lessons ADD CONSTRAINT chk_lessons_transcription_progress CHECK (transcription_progress >= 0 AND transcription_progress <= 100);

-- transcripts type constraint (already exists)
-- ALTER TABLE transcripts ADD CONSTRAINT chk_transcripts_type CHECK (transcript_type IN ('auto', 'manual', 'corrected'));

-- sr_cards constraints (already exist)
-- ALTER TABLE sr_cards ADD CONSTRAINT chk_sr_cards_type CHECK (card_type IN ('basic', 'cloze', 'multiple_choice', 'true_false'));
-- ALTER TABLE sr_cards ADD CONSTRAINT chk_sr_cards_difficulty CHECK (difficulty_level >= 1 AND difficulty_level <= 5);
-- ALTER TABLE sr_cards ADD CONSTRAINT chk_sr_cards_status CHECK (status IN ('pending', 'approved', 'rejected', 'archived'));

-- sr_card_flags constraints (already exist)
-- ALTER TABLE sr_card_flags ADD CONSTRAINT chk_sr_card_flags_type CHECK (flag_type IN ('incorrect', 'unclear', 'duplicate', 'inappropriate', 'outdated'));
-- ALTER TABLE sr_card_flags ADD CONSTRAINT chk_sr_card_flags_status CHECK (status IN ('open', 'resolved', 'dismissed'));

-- sr_reviews quality rating constraint (already exists)
-- ALTER TABLE sr_reviews ADD CONSTRAINT chk_sr_reviews_quality CHECK (quality_rating >= 0 AND quality_rating <= 5);

-- student_lesson_interactions type constraint (already exists)
-- ALTER TABLE student_lesson_interactions ADD CONSTRAINT chk_student_interactions_type CHECK (interaction_type IN ('view', 'study', 'review', 'complete'));

-- =====================================================
-- NOT NULL CONSTRAINTS
-- =====================================================

-- Most NOT NULL constraints are already defined in table creation
-- Additional NOT NULL constraints can be added here if needed

-- =====================================================
-- CONSTRAINT DOCUMENTATION
-- =====================================================

COMMENT ON CONSTRAINT fk_lesson_participants_lesson ON lesson_participants IS 'Links lesson participants to specific lessons';
COMMENT ON CONSTRAINT fk_lesson_participants_student ON lesson_participants IS 'Links lesson participants to student profiles';
COMMENT ON CONSTRAINT fk_lessons_teacher ON lessons IS 'Links lessons to their assigned teacher';
COMMENT ON CONSTRAINT fk_sr_card_flags_card ON sr_card_flags IS 'Links flags to specific flashcards';
COMMENT ON CONSTRAINT fk_sr_card_flags_student ON sr_card_flags IS 'Links flags to the student who reported them';
COMMENT ON CONSTRAINT fk_sr_card_flags_resolved_by ON sr_card_flags IS 'Links flags to the user who resolved them';
COMMENT ON CONSTRAINT fk_sr_cards_lesson ON sr_cards IS 'Links flashcards to their source lesson';
COMMENT ON CONSTRAINT fk_sr_cards_created_by ON sr_cards IS 'Links flashcards to their creator';
COMMENT ON CONSTRAINT fk_sr_cards_approved_by ON sr_cards IS 'Links flashcards to the user who approved them';
COMMENT ON CONSTRAINT fk_sr_progress_lesson ON sr_progress IS 'Links progress tracking to specific lessons';
COMMENT ON CONSTRAINT fk_sr_progress_student ON sr_progress IS 'Links progress tracking to specific students';
COMMENT ON CONSTRAINT fk_sr_reviews_card ON sr_reviews IS 'Links reviews to specific flashcards';
COMMENT ON CONSTRAINT fk_sr_reviews_student ON sr_reviews IS 'Links reviews to the student who performed them';
COMMENT ON CONSTRAINT fk_student_interactions_lesson ON student_lesson_interactions IS 'Links interactions to specific lessons';
COMMENT ON CONSTRAINT fk_student_interactions_student ON student_lesson_interactions IS 'Links interactions to specific students';
COMMENT ON CONSTRAINT fk_summaries_lesson ON summaries IS 'Links summaries to their source lesson';
COMMENT ON CONSTRAINT fk_transcripts_lesson ON transcripts IS 'Links transcripts to their source lesson';
COMMENT ON CONSTRAINT uk_sr_card_flags_card_student_type ON sr_card_flags IS 'Ensures a student can only flag a card once per flag type';
COMMENT ON CONSTRAINT uk_student_interactions_student_lesson ON student_lesson_interactions IS 'Ensures only one interaction record per student-lesson pair';