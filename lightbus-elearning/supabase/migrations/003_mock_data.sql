-- Phase 1: Mock Data for Testing and Development
-- This migration creates sample data to test the spaced repetition system

-- IMPORTANT: This migration creates sample profiles for development/testing.
-- These profiles will only work if corresponding Supabase Auth users exist.
--
-- To create working demo users, run:
--   PowerShell: .\scripts\create-demo-users.ps1
--   Node.js: node scripts/create-demo-users.js
--
-- Demo credentials will be:
--   Teacher: demo.teacher@lightbus.edu / demo123456
--   Student: demo.student@lightbus.edu / demo123456

-- Create a function to generate mock data only if no profiles exist
DO $$
DECLARE
    teacher_id UUID := 'f47b7e4c-7b1e-4f8c-8b3a-1234567890ab'::UUID;  -- Fixed UUID for demo teacher
    student1_id UUID := 'f47b7e4c-7b1e-4f8c-8b3a-1234567890ac'::UUID; -- Fixed UUID for demo student
    student2_id UUID := 'f47b7e4c-7b1e-4f8c-8b3a-1234567890ad'::UUID; -- Fixed UUID for alex student
    lesson1_id UUID := gen_random_uuid();
    lesson2_id UUID := gen_random_uuid();
    lesson3_id UUID := gen_random_uuid();
BEGIN
    -- Only create mock data if no profiles exist (to avoid issues in production)
    IF NOT EXISTS (SELECT 1 FROM public.profiles LIMIT 1) THEN
        
        -- NOTE: We do NOT insert into auth.users here because:
        -- 1. Supabase Auth manages that table exclusively
        -- 2. Users need passwords which can't be set via SQL
        -- 3. Use the demo user creation scripts instead
        
        -- Insert sample profiles (these will be linked to auth users when they're created)
        INSERT INTO public.profiles (id, name, email, role)
        VALUES
            (teacher_id, 'Demo Teacher', 'demo.teacher@lightbus.edu', 'teacher'),
            (student1_id, 'Demo Student', 'demo.student@lightbus.edu', 'student'),
            (student2_id, 'Alex Student', 'alex.student@lightbus.edu', 'student')
        ON CONFLICT (id) DO NOTHING;

        -- Insert sample lessons
        INSERT INTO public.lessons (id, teacher_id, name, description, scheduled_at, duration_minutes, has_audio)
        VALUES
          (
            lesson1_id,
            teacher_id,
            'Introduction to Spanish Vocabulary',
            'Basic Spanish words and phrases for beginners',
            NOW() - INTERVAL '7 days',
            45,
            true
          ),
          (
            lesson2_id,
            teacher_id,
            'Spanish Grammar Fundamentals',
            'Essential grammar rules and sentence structure',
            NOW() - INTERVAL '5 days',
            60,
            true
          ),
          (
            lesson3_id,
            teacher_id,
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
          (lesson1_id, student1_id),
          (lesson2_id, student1_id),
          (lesson3_id, student1_id),
          (lesson1_id, student2_id),
          (lesson2_id, student2_id)
        ON CONFLICT (lesson_id, student_id) DO NOTHING;

        -- Insert sample spaced repetition cards
        INSERT INTO public.sr_cards (lesson_id, created_by, front_content, back_content, card_type, difficulty_level, tags, status, approved_by, approved_at)
        VALUES
          -- Spanish Vocabulary Cards
          (
            lesson1_id,
            teacher_id,
            'How do you say "Hello" in Spanish?',
            'Hola',
            'basic',
            1,
            ARRAY['greeting', 'basic'],
            'approved',
            teacher_id,
            NOW() - INTERVAL '6 days'
          ),
          (
            lesson1_id,
            teacher_id,
            'What is "Thank you" in Spanish?',
            'Gracias',
            'basic',
            1,
            ARRAY['politeness', 'basic'],
            'approved',
            teacher_id,
            NOW() - INTERVAL '6 days'
          ),
          (
            lesson1_id,
            teacher_id,
            'How do you say "Good morning" in Spanish?',
            'Buenos días',
            'basic',
            2,
            ARRAY['greeting', 'time'],
            'approved',
            teacher_id,
            NOW() - INTERVAL '6 days'
          ),
          (
            lesson1_id,
            teacher_id,
            'What does "Por favor" mean?',
            'Please',
            'basic',
            1,
            ARRAY['politeness', 'basic'],
            'approved',
            teacher_id,
            NOW() - INTERVAL '6 days'
          ),
          (
            lesson1_id,
            teacher_id,
            'How do you say "Goodbye" in Spanish?',
            'Adiós',
            'basic',
            1,
            ARRAY['farewell', 'basic'],
            'approved',
            teacher_id,
            NOW() - INTERVAL '6 days'
          ),
          
          -- Grammar Cards
          (
            lesson2_id,
            teacher_id,
            'What is the Spanish word for "the" (masculine singular)?',
            'el',
            'basic',
            2,
            ARRAY['grammar', 'articles'],
            'approved',
            teacher_id,
            NOW() - INTERVAL '4 days'
          ),
          (
            lesson2_id,
            teacher_id,
            'What is the Spanish word for "the" (feminine singular)?',
            'la',
            'basic',
            2,
            ARRAY['grammar', 'articles'],
            'approved',
            teacher_id,
            NOW() - INTERVAL '4 days'
          ),
          (
            lesson2_id,
            teacher_id,
            'How do you conjugate "ser" (to be) for "I am"?',
            'soy',
            'basic',
            3,
            ARRAY['grammar', 'verbs', 'ser'],
            'approved',
            teacher_id,
            NOW() - INTERVAL '4 days'
          ),
          (
            lesson2_id,
            teacher_id,
            'What is the plural form of "niño" (boy)?',
            'niños',
            'basic',
            3,
            ARRAY['grammar', 'plurals', 'nouns'],
            'approved',
            teacher_id,
            NOW() - INTERVAL '4 days'
          ),
          
          -- Advanced Conversation Cards
          (
            lesson3_id,
            teacher_id,
            'What does "¿Cómo estás?" mean and how would you respond?',
            'It means "How are you?" You can respond with "Bien, gracias" (Fine, thanks)',
            'basic',
            4,
            ARRAY['conversation', 'greetings', 'responses'],
            'approved',
            teacher_id,
            NOW() - INTERVAL '2 days'
          ),
          (
            lesson3_id,
            teacher_id,
            'How do you ask "What time is it?" in Spanish?',
            '¿Qué hora es?',
            'basic',
            4,
            ARRAY['conversation', 'time', 'questions'],
            'approved',
            teacher_id,
            NOW() - INTERVAL '2 days'
          ),
          (
            lesson3_id,
            teacher_id,
            'What is a common way to express "I don''t understand" in Spanish?',
            'No entiendo',
            'basic',
            3,
            ARRAY['conversation', 'comprehension', 'phrases'],
            'approved',
            teacher_id,
            NOW() - INTERVAL '2 days'
          );

        -- Create some historical review data to show progress
        -- This simulates past study sessions with varying quality ratings
        
        -- Insert historical reviews for Alex Student (student1_id)
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
                            student1_id,
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

            -- Create some due cards for today and upcoming days
            INSERT INTO public.sr_reviews (card_id, student_id, scheduled_for, interval_days, ease_factor, repetition_count)
            SELECT
                id as card_id,
                student1_id as student_id,
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
                WHERE student_id = student1_id
                AND completed_at IS NULL
            );

            -- Update progress records based on the review data
            INSERT INTO public.sr_progress (student_id, lesson_id, cards_total, cards_reviewed, cards_learned, average_quality, study_streak, last_review_date, next_review_date)
            SELECT
                student1_id as student_id,
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
            LEFT JOIN public.sr_reviews r ON c.id = r.card_id AND r.student_id = student1_id
            WHERE l.id IN (
                SELECT lesson_id FROM public.lesson_participants
                WHERE student_id = student1_id
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
                student2_id as student_id,
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
                WHERE student_id = student2_id
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
                lesson1_id,
                'Welcome to our Spanish vocabulary lesson. Today we will learn basic greetings and polite expressions. Let''s start with "Hola" which means hello in Spanish.',
                'auto',
                0.95
              ),
              (
                lesson2_id,
                'In this grammar lesson, we focus on articles and basic verb conjugation. The definite articles in Spanish are "el" for masculine singular and "la" for feminine singular.',
                'auto',
                0.92
              )
            ON CONFLICT (id) DO NOTHING;

            INSERT INTO public.summaries (lesson_id, content, summary_type)
            VALUES
              (
                lesson1_id,
                'Key Spanish vocabulary covered: Hola (Hello), Gracias (Thank you), Buenos días (Good morning), Por favor (Please), Adiós (Goodbye). Focus on pronunciation and practical usage in daily conversations.',
                'auto'
              ),
              (
                lesson2_id,
                'Grammar fundamentals: Definite articles (el/la), basic verb "ser" conjugation (soy = I am), noun pluralization rules. Essential building blocks for Spanish sentence construction.',
                'auto'
              )
            ON CONFLICT (id) DO NOTHING;
            
        END;
    END IF;
END $$;