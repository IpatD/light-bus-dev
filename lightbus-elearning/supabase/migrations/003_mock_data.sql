-- Phase 1: Mock Data for Testing and Development
-- This migration creates sample data to test the spaced repetition system

-- Insert sample teacher profile (for development)
INSERT INTO public.profiles (id, name, email, role)
VALUES 
  ('12345678-1234-1234-1234-123456789012', 'Dr. Sarah Johnson', 'teacher@lightbus.edu', 'teacher')
ON CONFLICT (id) DO NOTHING;

-- Insert sample student profiles (for development)
INSERT INTO public.profiles (id, name, email, role)
VALUES 
  ('87654321-4321-4321-4321-210987654321', 'Alex Student', 'alex@student.edu', 'student'),
  ('11111111-2222-3333-4444-555555555555', 'Jamie Learner', 'jamie@student.edu', 'student')
ON CONFLICT (id) DO NOTHING;

-- Insert sample lessons
INSERT INTO public.lessons (id, teacher_id, name, description, scheduled_at, duration_minutes, has_audio)
VALUES 
  (
    '01234567-89ab-cdef-0123-456789abcdef',
    '12345678-1234-1234-1234-123456789012',
    'Introduction to Spanish Vocabulary',
    'Basic Spanish words and phrases for beginners',
    NOW() - INTERVAL '7 days',
    45,
    true
  ),
  (
    '12345678-9abc-def0-1234-56789abcdef0',
    '12345678-1234-1234-1234-123456789012',
    'Spanish Grammar Fundamentals',
    'Essential grammar rules and sentence structure',
    NOW() - INTERVAL '5 days',
    60,
    true
  ),
  (
    '23456789-abcd-ef01-2345-6789abcdef01',
    '12345678-1234-1234-1234-123456789012',
    'Advanced Spanish Conversation',
    'Practical conversation skills and idioms',
    NOW() - INTERVAL '3 days',
    50,
    true
  )
ON CONFLICT (id) DO NOTHING;

-- Enroll students in lessons
INSERT INTO public.lesson_participants (lesson_id, student_id)
VALUES 
  ('01234567-89ab-cdef-0123-456789abcdef', '87654321-4321-4321-4321-210987654321'),
  ('12345678-9abc-def0-1234-56789abcdef0', '87654321-4321-4321-4321-210987654321'),
  ('23456789-abcd-ef01-2345-6789abcdef01', '87654321-4321-4321-4321-210987654321'),
  ('01234567-89ab-cdef-0123-456789abcdef', '11111111-2222-3333-4444-555555555555'),
  ('12345678-9abc-def0-1234-56789abcdef0', '11111111-2222-3333-4444-555555555555')
ON CONFLICT (lesson_id, student_id) DO NOTHING;

-- Insert sample spaced repetition cards
INSERT INTO public.sr_cards (id, lesson_id, created_by, front_content, back_content, card_type, difficulty_level, tags, status, approved_by, approved_at)
VALUES 
  -- Spanish Vocabulary Cards
  (
    'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
    '01234567-89ab-cdef-0123-456789abcdef',
    '12345678-1234-1234-1234-123456789012',
    'How do you say "Hello" in Spanish?',
    'Hola',
    'basic',
    1,
    ARRAY['greeting', 'basic'],
    'approved',
    '12345678-1234-1234-1234-123456789012',
    NOW() - INTERVAL '6 days'
  ),
  (
    'bbbbbbbb-cccc-dddd-eeee-ffffffffffff',
    '01234567-89ab-cdef-0123-456789abcdef',
    '12345678-1234-1234-1234-123456789012',
    'What is "Thank you" in Spanish?',
    'Gracias',
    'basic',
    1,
    ARRAY['politeness', 'basic'],
    'approved',
    '12345678-1234-1234-1234-123456789012',
    NOW() - INTERVAL '6 days'
  ),
  (
    'cccccccc-dddd-eeee-ffff-000000000000',
    '01234567-89ab-cdef-0123-456789abcdef',
    '12345678-1234-1234-1234-123456789012',
    'How do you say "Good morning" in Spanish?',
    'Buenos días',
    'basic',
    2,
    ARRAY['greeting', 'time'],
    'approved',
    '12345678-1234-1234-1234-123456789012',
    NOW() - INTERVAL '6 days'
  ),
  (
    'dddddddd-eeee-ffff-0000-111111111111',
    '01234567-89ab-cdef-0123-456789abcdef',
    '12345678-1234-1234-1234-123456789012',
    'What does "Por favor" mean?',
    'Please',
    'basic',
    1,
    ARRAY['politeness', 'basic'],
    'approved',
    '12345678-1234-1234-1234-123456789012',
    NOW() - INTERVAL '6 days'
  ),
  (
    'eeeeeeee-ffff-0000-1111-222222222222',
    '01234567-89ab-cdef-0123-456789abcdef',
    '12345678-1234-1234-1234-123456789012',
    'How do you say "Goodbye" in Spanish?',
    'Adiós',
    'basic',
    1,
    ARRAY['farewell', 'basic'],
    'approved',
    '12345678-1234-1234-1234-123456789012',
    NOW() - INTERVAL '6 days'
  ),
  
  -- Grammar Cards
  (
    'ffffffff-0000-1111-2222-333333333333',
    '12345678-9abc-def0-1234-56789abcdef0',
    '12345678-1234-1234-1234-123456789012',
    'What is the Spanish word for "the" (masculine singular)?',
    'el',
    'basic',
    2,
    ARRAY['grammar', 'articles'],
    'approved',
    '12345678-1234-1234-1234-123456789012',
    NOW() - INTERVAL '4 days'
  ),
  (
    '00000000-1111-2222-3333-444444444444',
    '12345678-9abc-def0-1234-56789abcdef0',
    '12345678-1234-1234-1234-123456789012',
    'What is the Spanish word for "the" (feminine singular)?',
    'la',
    'basic',
    2,
    ARRAY['grammar', 'articles'],
    'approved',
    '12345678-1234-1234-1234-123456789012',
    NOW() - INTERVAL '4 days'
  ),
  (
    '11111111-2222-3333-4444-555555555556',
    '12345678-9abc-def0-1234-56789abcdef0',
    '12345678-1234-1234-1234-123456789012',
    'How do you conjugate "ser" (to be) for "I am"?',
    'soy',
    'basic',
    3,
    ARRAY['grammar', 'verbs', 'ser'],
    'approved',
    '12345678-1234-1234-1234-123456789012',
    NOW() - INTERVAL '4 days'
  ),
  (
    '22222222-3333-4444-5555-666666666666',
    '12345678-9abc-def0-1234-56789abcdef0',
    '12345678-1234-1234-1234-123456789012',
    'What is the plural form of "niño" (boy)?',
    'niños',
    'basic',
    3,
    ARRAY['grammar', 'plurals', 'nouns'],
    'approved',
    '12345678-1234-1234-1234-123456789012',
    NOW() - INTERVAL '4 days'
  ),
  
  -- Advanced Conversation Cards
  (
    '33333333-4444-5555-6666-777777777777',
    '23456789-abcd-ef01-2345-6789abcdef01',
    '12345678-1234-1234-1234-123456789012',
    'What does "¿Cómo estás?" mean and how would you respond?',
    'It means "How are you?" You can respond with "Bien, gracias" (Fine, thanks)',
    'basic',
    4,
    ARRAY['conversation', 'greetings', 'responses'],
    'approved',
    '12345678-1234-1234-1234-123456789012',
    NOW() - INTERVAL '2 days'
  ),
  (
    '44444444-5555-6666-7777-888888888888',
    '23456789-abcd-ef01-2345-6789abcdef01',
    '12345678-1234-1234-1234-123456789012',
    'How do you ask "What time is it?" in Spanish?',
    '¿Qué hora es?',
    'basic',
    4,
    ARRAY['conversation', 'time', 'questions'],
    'approved',
    '12345678-1234-1234-1234-123456789012',
    NOW() - INTERVAL '2 days'
  ),
  (
    '55555555-6666-7777-8888-999999999999',
    '23456789-abcd-ef01-2345-6789abcdef01',
    '12345678-1234-1234-1234-123456789012',
    'What is a common way to express "I don''t understand" in Spanish?',
    'No entiendo',
    'basic',
    3,
    ARRAY['conversation', 'comprehension', 'phrases'],
    'approved',
    '12345678-1234-1234-1234-123456789012',
    NOW() - INTERVAL '2 days'
  )
ON CONFLICT (id) DO NOTHING;

-- Create some historical review data to show progress
-- This simulates past study sessions with varying quality ratings

-- Insert historical reviews for Alex Student
DO $$
DECLARE
    card_record RECORD;
    review_date TIMESTAMP;
    quality_rating INTEGER;
    response_time INTEGER;
    days_back INTEGER;
BEGIN
    -- Loop through approved cards and create review history
    FOR card_record IN 
        SELECT id, lesson_id FROM public.sr_cards WHERE status = 'approved'
    LOOP
        -- Create reviews for the past 14 days with varying patterns
        FOR days_back IN 1..14 LOOP
            review_date := NOW() - (days_back || ' days')::INTERVAL;
            
            -- Simulate realistic study patterns (not every day)
            IF random() > 0.3 THEN
                -- Simulate improving performance over time
                IF days_back > 10 THEN
                    quality_rating := floor(random() * 3) + 1; -- 1-3 for older reviews
                ELSIF days_back > 5 THEN
                    quality_rating := floor(random() * 3) + 2; -- 2-4 for recent reviews
                ELSE
                    quality_rating := floor(random() * 2) + 3; -- 3-4 for latest reviews
                END IF;
                
                -- Simulate response times (2-15 seconds)
                response_time := (random() * 13000 + 2000)::INTEGER;
                
                -- Insert review record
                INSERT INTO public.sr_reviews (
                    card_id, 
                    student_id, 
                    scheduled_for, 
                    completed_at, 
                    quality_rating, 
                    response_time_ms, 
                    interval_days, 
                    ease_factor, 
                    repetition_count
                ) VALUES (
                    card_record.id,
                    '87654321-4321-4321-4321-210987654321',
                    review_date - INTERVAL '1 hour',
                    review_date,
                    quality_rating,
                    response_time,
                    CASE 
                        WHEN quality_rating >= 3 THEN LEAST(days_back, 30)
                        ELSE 1
                    END,
                    GREATEST(1.3, 2.5 + (quality_rating - 3) * 0.1),
                    GREATEST(1, days_back / 7)
                );
            END IF;
        END LOOP;
    END LOOP;
END $$;

-- Create some due cards for today and upcoming days
INSERT INTO public.sr_reviews (card_id, student_id, scheduled_for, interval_days, ease_factor, repetition_count)
SELECT 
    id as card_id,
    '87654321-4321-4321-4321-210987654321' as student_id,
    CASE 
        WHEN random() < 0.4 THEN NOW() - INTERVAL '1 hour'  -- 40% are overdue
        WHEN random() < 0.7 THEN NOW() + INTERVAL '2 hours' -- 30% due today
        ELSE NOW() + (floor(random() * 3) + 1 || ' days')::INTERVAL -- 30% due in next few days
    END as scheduled_for,
    CASE 
        WHEN random() < 0.3 THEN 1
        WHEN random() < 0.7 THEN floor(random() * 5) + 2
        ELSE floor(random() * 20) + 7
    END as interval_days,
    1.3 + random() * 1.7 as ease_factor, -- 1.3 to 3.0
    floor(random() * 5) as repetition_count
FROM public.sr_cards 
WHERE status = 'approved'
AND id NOT IN (
    SELECT card_id FROM public.sr_reviews 
    WHERE student_id = '87654321-4321-4321-4321-210987654321' 
    AND completed_at IS NULL
);

-- Update progress records based on the review data
INSERT INTO public.sr_progress (student_id, lesson_id, cards_total, cards_reviewed, cards_learned, average_quality, study_streak, last_review_date, next_review_date)
SELECT 
    '87654321-4321-4321-4321-210987654321' as student_id,
    l.id as lesson_id,
    COUNT(DISTINCT c.id) as cards_total,
    COUNT(DISTINCT CASE WHEN r.completed_at IS NOT NULL THEN c.id END) as cards_reviewed,
    COUNT(DISTINCT CASE WHEN r.completed_at IS NOT NULL AND r.quality_rating >= 4 THEN c.id END) as cards_learned,
    COALESCE(AVG(CASE WHEN r.completed_at IS NOT NULL THEN r.quality_rating END), 0) as average_quality,
    7 as study_streak, -- Mock 7-day streak
    CURRENT_DATE as last_review_date,
    CURRENT_DATE + 1 as next_review_date
FROM public.lessons l
LEFT JOIN public.sr_cards c ON l.id = c.lesson_id AND c.status = 'approved'
LEFT JOIN public.sr_reviews r ON c.id = r.card_id AND r.student_id = '87654321-4321-4321-4321-210987654321'
WHERE l.id IN (
    SELECT lesson_id FROM public.lesson_participants 
    WHERE student_id = '87654321-4321-4321-4321-210987654321'
)
GROUP BY l.id
ON CONFLICT (student_id, lesson_id) 
DO UPDATE SET
    cards_total = EXCLUDED.cards_total,
    cards_reviewed = EXCLUDED.cards_reviewed,
    cards_learned = EXCLUDED.cards_learned,
    average_quality = EXCLUDED.average_quality,
    study_streak = EXCLUDED.study_streak,
    last_review_date = EXCLUDED.last_review_date,
    next_review_date = EXCLUDED.next_review_date,
    updated_at = NOW();

-- Create similar data for Jamie Learner (with different patterns)
INSERT INTO public.sr_progress (student_id, lesson_id, cards_total, cards_reviewed, cards_learned, average_quality, study_streak, last_review_date, next_review_date)
SELECT 
    '11111111-2222-3333-4444-555555555555' as student_id,
    l.id as lesson_id,
    COUNT(DISTINCT c.id) as cards_total,
    FLOOR(COUNT(DISTINCT c.id) * 0.6) as cards_reviewed, -- 60% completion rate
    FLOOR(COUNT(DISTINCT c.id) * 0.3) as cards_learned,  -- 30% mastery rate
    2.8 as average_quality, -- Lower average quality
    3 as study_streak, -- 3-day streak
    CURRENT_DATE - 1 as last_review_date,
    CURRENT_DATE + 2 as next_review_date
FROM public.lessons l
LEFT JOIN public.sr_cards c ON l.id = c.lesson_id AND c.status = 'approved'
WHERE l.id IN (
    SELECT lesson_id FROM public.lesson_participants 
    WHERE student_id = '11111111-2222-3333-4444-555555555555'
)
GROUP BY l.id
ON CONFLICT (student_id, lesson_id) 
DO UPDATE SET
    cards_total = EXCLUDED.cards_total,
    cards_reviewed = EXCLUDED.cards_reviewed,
    cards_learned = EXCLUDED.cards_learned,
    average_quality = EXCLUDED.average_quality,
    study_streak = EXCLUDED.study_streak,
    last_review_date = EXCLUDED.last_review_date,
    next_review_date = EXCLUDED.next_review_date,
    updated_at = NOW();

-- Add some transcripts and summaries for completeness
INSERT INTO public.transcripts (lesson_id, content, transcript_type, confidence_score)
VALUES 
  (
    '01234567-89ab-cdef-0123-456789abcdef',
    'Welcome to our Spanish vocabulary lesson. Today we will learn basic greetings and polite expressions. Let''s start with "Hola" which means hello in Spanish.',
    'auto',
    0.95
  ),
  (
    '12345678-9abc-def0-1234-56789abcdef0',
    'In this grammar lesson, we focus on articles and basic verb conjugation. The definite articles in Spanish are "el" for masculine singular and "la" for feminine singular.',
    'auto',
    0.92
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.summaries (lesson_id, content, summary_type)
VALUES 
  (
    '01234567-89ab-cdef-0123-456789abcdef',
    'Key Spanish vocabulary covered: Hola (Hello), Gracias (Thank you), Buenos días (Good morning), Por favor (Please), Adiós (Goodbye). Focus on pronunciation and practical usage in daily conversations.',
    'auto'
  ),
  (
    '12345678-9abc-def0-1234-56789abcdef0',
    'Grammar fundamentals: Definite articles (el/la), basic verb "ser" conjugation (soy = I am), noun pluralization rules. Essential building blocks for Spanish sentence construction.',
    'auto'
  )
ON CONFLICT (id) DO NOTHING;