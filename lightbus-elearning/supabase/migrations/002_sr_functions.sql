-- Phase 1: SM-2 Algorithm Implementation and Enhanced Spaced Repetition Functions
-- This migration adds the core SM-2 algorithm functions and optimizations

-- Add missing indexes for optimal query performance
CREATE INDEX IF NOT EXISTS idx_sr_reviews_completed_at ON public.sr_reviews(completed_at);
CREATE INDEX IF NOT EXISTS idx_sr_reviews_quality_rating ON public.sr_reviews(quality_rating);
CREATE INDEX IF NOT EXISTS idx_sr_progress_next_review_date ON public.sr_progress(next_review_date);
CREATE INDEX IF NOT EXISTS idx_sr_progress_last_review_date ON public.sr_progress(last_review_date);
CREATE INDEX IF NOT EXISTS idx_sr_progress_study_streak ON public.sr_progress(study_streak);

-- Function: Calculate SM-2 interval based on quality rating
-- This implements the core SM-2 algorithm for spaced repetition
CREATE OR REPLACE FUNCTION calculate_sr_interval(
    current_interval INT,
    easiness_factor DECIMAL,
    quality INT
) RETURNS TABLE(
    new_interval INT,
    new_easiness_factor DECIMAL,
    new_repetition_count INT
) AS $$
DECLARE
    ef DECIMAL := easiness_factor;
    interval_days INT := current_interval;
    rep_count INT := 1;
BEGIN
    -- Validate quality rating (0-5)
    IF quality < 0 OR quality > 5 THEN
        RAISE EXCEPTION 'Quality rating must be between 0 and 5';
    END IF;

    -- SM-2 Algorithm Implementation
    -- If quality < 3, reset to beginning (interval = 1)
    IF quality < 3 THEN
        interval_days := 1;
        rep_count := 0;
    ELSE
        -- Calculate new easiness factor
        ef := ef + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
        
        -- Ensure easiness factor doesn't go below 1.3
        IF ef < 1.3 THEN
            ef := 1.3;
        END IF;
        
        -- Calculate new interval based on repetition count
        IF current_interval = 1 THEN
            interval_days := 6;  -- First successful review: 6 days
            rep_count := 1;
        ELSE
            interval_days := ROUND(current_interval * ef);
            rep_count := GREATEST(current_interval / 6, 1) + 1;
        END IF;
    END IF;

    -- Return the calculated values
    RETURN QUERY SELECT interval_days, ef, rep_count;
END;
$$ LANGUAGE plpgsql;

-- Function: Record a spaced repetition review and calculate next review date
CREATE OR REPLACE FUNCTION record_sr_review(
    p_user_id UUID,
    p_card_id UUID,
    p_quality INT,
    p_response_time_ms INT
) RETURNS TABLE(
    review_id UUID,
    next_review_date TIMESTAMPTZ,
    new_interval INT,
    success BOOLEAN
) AS $$
DECLARE
    v_review_id UUID;
    v_current_review public.sr_reviews%ROWTYPE;
    v_card public.sr_cards%ROWTYPE;
    v_lesson_id UUID;
    v_progress public.sr_progress%ROWTYPE;
    v_calc_result RECORD;
    v_next_date TIMESTAMPTZ;
BEGIN
    -- Get the current scheduled review
    SELECT * INTO v_current_review
    FROM public.sr_reviews
    WHERE card_id = p_card_id 
      AND student_id = p_user_id 
      AND completed_at IS NULL
      AND scheduled_for <= NOW()
    ORDER BY scheduled_for ASC
    LIMIT 1;

    -- If no pending review found, create initial review
    IF v_current_review.id IS NULL THEN
        SELECT * INTO v_card FROM public.sr_cards WHERE id = p_card_id;
        
        IF v_card.id IS NULL THEN
            RAISE EXCEPTION 'Card not found: %', p_card_id;
        END IF;

        -- Create initial review record
        INSERT INTO public.sr_reviews (
            card_id, student_id, scheduled_for, interval_days, ease_factor, repetition_count
        ) VALUES (
            p_card_id, p_user_id, NOW(), 1, 2.5, 0
        ) RETURNING * INTO v_current_review;
    END IF;

    -- Calculate new interval using SM-2 algorithm
    SELECT * INTO v_calc_result
    FROM calculate_sr_interval(
        v_current_review.interval_days,
        v_current_review.ease_factor,
        p_quality
    );

    -- Calculate next review date
    v_next_date := NOW() + (v_calc_result.new_interval || ' days')::INTERVAL;

    -- Update current review with completion data
    UPDATE public.sr_reviews
    SET 
        completed_at = NOW(),
        quality_rating = p_quality,
        response_time_ms = p_response_time_ms
    WHERE id = v_current_review.id;

    v_review_id := v_current_review.id;

    -- Create next review record (unless quality was too low)
    IF p_quality >= 3 THEN
        INSERT INTO public.sr_reviews (
            card_id,
            student_id,
            scheduled_for,
            interval_days,
            ease_factor,
            repetition_count
        ) VALUES (
            p_card_id,
            p_user_id,
            v_next_date,
            v_calc_result.new_interval,
            v_calc_result.new_easiness_factor,
            v_calc_result.new_repetition_count
        );
    ELSE
        -- For low quality ratings, schedule immediate re-review
        INSERT INTO public.sr_reviews (
            card_id,
            student_id,
            scheduled_for,
            interval_days,
            ease_factor,
            repetition_count
        ) VALUES (
            p_card_id,
            p_user_id,
            NOW() + '10 minutes'::INTERVAL,
            1,
            v_current_review.ease_factor,
            0
        );
        v_next_date := NOW() + '10 minutes'::INTERVAL;
    END IF;

    -- Update progress tracking
    SELECT * INTO v_card FROM public.sr_cards WHERE id = p_card_id;
    v_lesson_id := v_card.lesson_id;

    -- Get or create progress record
    SELECT * INTO v_progress
    FROM public.sr_progress
    WHERE student_id = p_user_id AND lesson_id = v_lesson_id;

    IF v_progress.id IS NULL THEN
        INSERT INTO public.sr_progress (
            student_id, lesson_id, cards_total, cards_reviewed, cards_learned,
            average_quality, study_streak, last_review_date, next_review_date
        ) VALUES (
            p_user_id, v_lesson_id, 1, 1, CASE WHEN p_quality >= 4 THEN 1 ELSE 0 END,
            p_quality, 1, CURRENT_DATE, v_next_date::DATE
        );
    ELSE
        -- Update existing progress
        UPDATE public.sr_progress
        SET
            cards_reviewed = cards_reviewed + 1,
            cards_learned = CASE 
                WHEN p_quality >= 4 THEN cards_learned + 1 
                ELSE cards_learned 
            END,
            average_quality = (
                (average_quality * (cards_reviewed - 1) + p_quality) / 
                GREATEST(cards_reviewed, 1.0)
            ),
            study_streak = CASE
                WHEN last_review_date = CURRENT_DATE THEN study_streak
                WHEN last_review_date = CURRENT_DATE - 1 THEN study_streak + 1
                ELSE 1
            END,
            last_review_date = CURRENT_DATE,
            next_review_date = LEAST(next_review_date, v_next_date::DATE),
            updated_at = NOW()
        WHERE id = v_progress.id;
    END IF;

    -- Return results
    RETURN QUERY SELECT 
        v_review_id,
        v_next_date,
        v_calc_result.new_interval,
        TRUE;

EXCEPTION WHEN OTHERS THEN
    -- Return error state
    RETURN QUERY SELECT 
        NULL::UUID,
        NULL::TIMESTAMPTZ,
        NULL::INT,
        FALSE;
END;
$$ LANGUAGE plpgsql;

-- Function: Get cards due for review for a specific user
CREATE OR REPLACE FUNCTION get_cards_due(
    p_user_id UUID,
    p_limit_count INT DEFAULT 20,
    p_lesson_id UUID DEFAULT NULL
) RETURNS TABLE(
    card_id UUID,
    lesson_id UUID,
    front_content TEXT,
    back_content TEXT,
    difficulty_level INT,
    tags TEXT[],
    scheduled_for TIMESTAMPTZ,
    review_id UUID,
    repetition_count INT,
    ease_factor DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id as card_id,
        c.lesson_id,
        c.front_content,
        c.back_content,
        c.difficulty_level,
        c.tags,
        r.scheduled_for,
        r.id as review_id,
        r.repetition_count,
        r.ease_factor
    FROM public.sr_cards c
    INNER JOIN public.sr_reviews r ON c.id = r.card_id
    INNER JOIN public.lesson_participants lp ON c.lesson_id = lp.lesson_id
    WHERE r.student_id = p_user_id
      AND lp.student_id = p_user_id
      AND c.status = 'approved'
      AND r.completed_at IS NULL
      AND r.scheduled_for <= NOW()
      AND (p_lesson_id IS NULL OR c.lesson_id = p_lesson_id)
    ORDER BY r.scheduled_for ASC, c.difficulty_level ASC
    LIMIT p_limit_count;
END;
$$ LANGUAGE plpgsql;

-- Function: Get comprehensive user statistics for dashboard
CREATE OR REPLACE FUNCTION get_user_stats(
    p_user_id UUID
) RETURNS TABLE(
    total_reviews BIGINT,
    average_quality DECIMAL,
    study_streak INT,
    cards_learned BIGINT,
    cards_due_today BIGINT,
    next_review_date DATE,
    weekly_progress BIGINT[],
    monthly_progress BIGINT[],
    total_lessons BIGINT,
    lessons_with_progress BIGINT
) AS $$
DECLARE
    v_stats RECORD;
    v_weekly BIGINT[];
    v_monthly BIGINT[];
    i INT;
    review_date DATE;
    day_offset INT;
BEGIN
    -- Initialize arrays
    v_weekly := ARRAY[0,0,0,0,0,0,0];
    v_monthly := ARRAY_FILL(0, ARRAY[30]);

    -- Get basic statistics
    SELECT
        COALESCE(COUNT(CASE WHEN r.completed_at IS NOT NULL THEN 1 END), 0) as tot_reviews,
        COALESCE(AVG(CASE WHEN r.completed_at IS NOT NULL THEN r.quality_rating END), 0.0) as avg_quality,
        COALESCE(MAX(p.study_streak), 0) as max_streak,
        COALESCE(SUM(p.cards_learned), 0) as learned_cards,
        COALESCE(COUNT(CASE WHEN r.completed_at IS NULL AND r.scheduled_for <= NOW() THEN 1 END), 0) as due_today,
        MIN(CASE WHEN r.completed_at IS NULL THEN r.scheduled_for::DATE END) as next_review,
        COUNT(DISTINCT p.lesson_id) as lessons_progress,
        COUNT(DISTINCT lp.lesson_id) as total_lessons_count
    INTO v_stats
    FROM public.lesson_participants lp
    LEFT JOIN public.sr_progress p ON lp.lesson_id = p.lesson_id AND lp.student_id = p.student_id
    LEFT JOIN public.sr_reviews r ON r.student_id = lp.student_id
    LEFT JOIN public.sr_cards c ON r.card_id = c.id AND c.lesson_id = lp.lesson_id
    WHERE lp.student_id = p_user_id;

    -- Build weekly progress (last 7 days)
    SELECT ARRAY_AGG(daily_count ORDER BY day_index) INTO v_weekly
    FROM (
        SELECT
            i AS day_index,
            COALESCE(COUNT(r.id), 0) as daily_count
        FROM generate_series(0, 6) AS i
        LEFT JOIN public.sr_reviews r ON r.student_id = p_user_id
            AND r.completed_at::DATE = CURRENT_DATE - i
            AND EXISTS (
                SELECT 1 FROM public.sr_cards c
                JOIN public.lesson_participants lp ON c.lesson_id = lp.lesson_id
                WHERE c.id = r.card_id AND lp.student_id = p_user_id
            )
        GROUP BY i
        ORDER BY i
    ) weekly_data;

    -- Build monthly progress (last 30 days)
    SELECT ARRAY_AGG(daily_count ORDER BY day_index) INTO v_monthly
    FROM (
        SELECT
            i AS day_index,
            COALESCE(COUNT(r.id), 0) as daily_count
        FROM generate_series(0, 29) AS i
        LEFT JOIN public.sr_reviews r ON r.student_id = p_user_id
            AND r.completed_at::DATE = CURRENT_DATE - i
            AND EXISTS (
                SELECT 1 FROM public.sr_cards c
                JOIN public.lesson_participants lp ON c.lesson_id = lp.lesson_id
                WHERE c.id = r.card_id AND lp.student_id = p_user_id
            )
        GROUP BY i
        ORDER BY i
    ) monthly_data;

    -- Return comprehensive stats
    RETURN QUERY SELECT
        v_stats.tot_reviews,
        v_stats.avg_quality,
        v_stats.max_streak,
        v_stats.learned_cards,
        v_stats.due_today,
        v_stats.next_review,
        v_weekly,
        v_monthly,
        v_stats.total_lessons_count,
        v_stats.lessons_progress;
END;
$$ LANGUAGE plpgsql;

-- Function: Initialize spaced repetition for a new lesson participant
CREATE OR REPLACE FUNCTION initialize_sr_for_participant(
    p_student_id UUID,
    p_lesson_id UUID
) RETURNS BOOLEAN AS $$
DECLARE
    v_card RECORD;
    v_progress_exists BOOLEAN;
BEGIN
    -- Check if progress already exists
    SELECT EXISTS(
        SELECT 1 FROM public.sr_progress 
        WHERE student_id = p_student_id AND lesson_id = p_lesson_id
    ) INTO v_progress_exists;

    -- Create progress record if it doesn't exist
    IF NOT v_progress_exists THEN
        INSERT INTO public.sr_progress (
            student_id, lesson_id, cards_total, cards_reviewed, 
            cards_learned, average_quality, study_streak
        )
        SELECT 
            p_student_id, p_lesson_id, COUNT(*), 0, 0, 0.0, 0
        FROM public.sr_cards
        WHERE lesson_id = p_lesson_id AND status = 'approved';
    END IF;

    -- Create initial review records for all approved cards in the lesson
    FOR v_card IN 
        SELECT id FROM public.sr_cards 
        WHERE lesson_id = p_lesson_id AND status = 'approved'
    LOOP
        -- Only create if no review exists for this card and student
        IF NOT EXISTS(
            SELECT 1 FROM public.sr_reviews 
            WHERE card_id = v_card.id AND student_id = p_student_id
        ) THEN
            INSERT INTO public.sr_reviews (
                card_id, student_id, scheduled_for, 
                interval_days, ease_factor, repetition_count
            ) VALUES (
                v_card.id, p_student_id, NOW(),
                1, 2.5, 0
            );
        END IF;
    END LOOP;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Function: Get lesson progress for a student
CREATE OR REPLACE FUNCTION get_lesson_progress(
    p_student_id UUID,
    p_lesson_id UUID DEFAULT NULL
) RETURNS TABLE(
    lesson_id UUID,
    lesson_name TEXT,
    cards_total INT,
    cards_reviewed INT,
    cards_learned INT,
    cards_due INT,
    average_quality DECIMAL,
    next_review_date DATE,
    progress_percentage DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        l.id as lesson_id,
        l.name as lesson_name,
        p.cards_total,
        p.cards_reviewed,
        p.cards_learned,
        COUNT(r.id)::INT as cards_due,
        p.average_quality,
        p.next_review_date,
        CASE 
            WHEN p.cards_total > 0 THEN 
                ROUND((p.cards_learned::DECIMAL / p.cards_total::DECIMAL) * 100, 2)
            ELSE 0.0
        END as progress_percentage
    FROM public.lessons l
    INNER JOIN public.lesson_participants lp ON l.id = lp.lesson_id
    LEFT JOIN public.sr_progress p ON l.id = p.lesson_id AND p.student_id = lp.student_id
    LEFT JOIN public.sr_reviews r ON r.student_id = lp.student_id 
        AND r.completed_at IS NULL 
        AND r.scheduled_for <= NOW()
        AND EXISTS(
            SELECT 1 FROM public.sr_cards c 
            WHERE c.id = r.card_id AND c.lesson_id = l.id
        )
    WHERE lp.student_id = p_student_id
      AND (p_lesson_id IS NULL OR l.id = p_lesson_id)
    GROUP BY l.id, l.name, p.cards_total, p.cards_reviewed, 
             p.cards_learned, p.average_quality, p.next_review_date
    ORDER BY l.name;
END;
$$ LANGUAGE plpgsql;

-- Trigger: Auto-initialize spaced repetition when student joins lesson
CREATE OR REPLACE FUNCTION auto_initialize_sr()
RETURNS TRIGGER AS $$
BEGIN
    -- Initialize spaced repetition for the new participant
    PERFORM initialize_sr_for_participant(NEW.student_id, NEW.lesson_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for auto-initialization
DROP TRIGGER IF EXISTS trigger_auto_initialize_sr ON public.lesson_participants;
CREATE TRIGGER trigger_auto_initialize_sr
    AFTER INSERT ON public.lesson_participants
    FOR EACH ROW EXECUTE FUNCTION auto_initialize_sr();

-- Trigger: Auto-create reviews when new cards are approved
CREATE OR REPLACE FUNCTION auto_create_reviews_for_new_cards()
RETURNS TRIGGER AS $$
DECLARE
    participant RECORD;
BEGIN
    -- Only trigger when status changes to 'approved'
    IF OLD.status != 'approved' AND NEW.status = 'approved' THEN
        -- Create review records for all participants of this lesson
        FOR participant IN
            SELECT student_id FROM public.lesson_participants 
            WHERE lesson_id = NEW.lesson_id
        LOOP
            -- Create initial review record
            INSERT INTO public.sr_reviews (
                card_id, student_id, scheduled_for,
                interval_days, ease_factor, repetition_count
            ) VALUES (
                NEW.id, participant.student_id, NOW(),
                1, 2.5, 0
            );
        END LOOP;

        -- Update progress records
        UPDATE public.sr_progress 
        SET 
            cards_total = cards_total + 1,
            updated_at = NOW()
        WHERE lesson_id = NEW.lesson_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for auto-creating reviews
DROP TRIGGER IF EXISTS trigger_auto_create_reviews ON public.sr_cards;
CREATE TRIGGER trigger_auto_create_reviews
    AFTER UPDATE ON public.sr_cards
    FOR EACH ROW EXECUTE FUNCTION auto_create_reviews_for_new_cards();

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION calculate_sr_interval TO authenticated;
GRANT EXECUTE ON FUNCTION record_sr_review TO authenticated;
GRANT EXECUTE ON FUNCTION get_cards_due TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_stats TO authenticated;
GRANT EXECUTE ON FUNCTION initialize_sr_for_participant TO authenticated;
GRANT EXECUTE ON FUNCTION get_lesson_progress TO authenticated;