-- =============================================================================
-- COMPREHENSIVE DATE DISCREPANCY FIXES
-- =============================================================================
-- 
-- This migration addresses all identified date discrepancy issues in the 
-- student dashboard learning analytics system.
--
-- ISSUES FIXED:
-- 1. Timezone inconsistency between database UTC and client local time
-- 2. Date boundary misalignment causing incorrect "today" calculations  
-- 3. Mixed TIMESTAMPTZ vs DATE conversions losing timezone context
-- 4. Progress tracking date inconsistencies
-- 5. Frontend date processing without timezone awareness
--
-- APPROACH:
-- - Standardize on timezone-aware date handling throughout the system
-- - Add client timezone parameter to critical functions
-- - Fix progress tracking to use consistent date calculations
-- - Ensure all date comparisons account for timezone differences
-- =============================================================================

-- =============================================================================
-- 1. TIMEZONE-AWARE DATE HELPER FUNCTIONS
-- =============================================================================

-- Function to convert UTC timestamp to client timezone date
CREATE OR REPLACE FUNCTION get_client_date(
    utc_timestamp TIMESTAMPTZ,
    client_timezone TEXT DEFAULT 'Europe/Warsaw'
) RETURNS DATE AS $$
BEGIN
    RETURN (utc_timestamp AT TIME ZONE client_timezone)::DATE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to get current date in client timezone
CREATE OR REPLACE FUNCTION get_current_client_date(
    client_timezone TEXT DEFAULT 'Europe/Warsaw'
) RETURNS DATE AS $$
BEGIN
    RETURN (NOW() AT TIME ZONE client_timezone)::DATE;
END;
$$ LANGUAGE plpgsql;

-- Function to check if two timestamps are on the same date in client timezone
CREATE OR REPLACE FUNCTION same_client_date(
    timestamp1 TIMESTAMPTZ,
    timestamp2 TIMESTAMPTZ,
    client_timezone TEXT DEFAULT 'Europe/Warsaw'
) RETURNS BOOLEAN AS $$
BEGIN
    RETURN (timestamp1 AT TIME ZONE client_timezone)::DATE = 
           (timestamp2 AT TIME ZONE client_timezone)::DATE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- =============================================================================
-- 2. FIXED REVIEW RECORDING WITH TIMEZONE AWARENESS
-- =============================================================================

-- Enhanced record_sr_review function with timezone-aware date handling
CREATE OR REPLACE FUNCTION record_sr_review(
    p_user_id UUID,
    p_card_id UUID,
    p_quality INT,
    p_response_time_ms INT,
    p_client_timezone TEXT DEFAULT 'Europe/Warsaw'
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
    v_is_first_success BOOLEAN := FALSE;
    v_client_today DATE;
    v_client_yesterday DATE;
BEGIN
    -- Get current date in client timezone for consistent progress tracking
    v_client_today := get_current_client_date(p_client_timezone);
    v_client_yesterday := v_client_today - INTERVAL '1 day';
    
    -- Get and lock the current scheduled review
    SELECT * INTO v_current_review
    FROM public.sr_reviews
    WHERE card_id = p_card_id 
      AND student_id = p_user_id 
      AND completed_at IS NULL
    ORDER BY created_at DESC, id DESC
    LIMIT 1
    FOR UPDATE;

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

    -- Create next review BEFORE completing current (prevents race condition)
    IF p_quality >= 3 THEN
        INSERT INTO public.sr_reviews (
            card_id,
            student_id,
            scheduled_for,
            interval_days,
            ease_factor,
            repetition_count,
            card_status
        ) VALUES (
            p_card_id,
            p_user_id,
            v_next_date,
            v_calc_result.new_interval,
            v_calc_result.new_easiness_factor,
            v_calc_result.new_repetition_count,
            CASE 
                WHEN v_current_review.card_status = 'new' THEN 'accepted'::card_status_enum
                ELSE v_current_review.card_status
            END
        );
        
        -- Check if this is first time success for accurate progress tracking
        v_is_first_success := (v_current_review.card_status = 'new' AND p_quality >= 4);
    ELSE
        -- For failures, use graduated retry intervals
        INSERT INTO public.sr_reviews (
            card_id,
            student_id,
            scheduled_for,
            interval_days,
            ease_factor,
            repetition_count,
            card_status
        ) VALUES (
            p_card_id,
            p_user_id,
            NOW() + (v_calc_result.new_interval || ' days')::INTERVAL,
            v_calc_result.new_interval,
            v_calc_result.new_easiness_factor,
            0,
            v_current_review.card_status
        );
        v_next_date := NOW() + (v_calc_result.new_interval || ' days')::INTERVAL;
    END IF;

    -- Complete current review
    UPDATE public.sr_reviews
    SET 
        completed_at = NOW(),
        quality_rating = p_quality,
        response_time_ms = p_response_time_ms
    WHERE id = v_current_review.id;

    v_review_id := v_current_review.id;

    -- FIXED: Timezone-aware progress tracking
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
            p_user_id, v_lesson_id, 1, 1, CASE WHEN v_is_first_success THEN 1 ELSE 0 END,
            p_quality, 1, v_client_today, get_client_date(v_next_date, p_client_timezone)
        );
    ELSE
        -- FIXED: Update existing progress with timezone-aware date calculations
        UPDATE public.sr_progress
        SET
            cards_reviewed = cards_reviewed + 1,
            cards_learned = CASE 
                WHEN v_is_first_success THEN cards_learned + 1
                ELSE cards_learned 
            END,
            average_quality = (
                (average_quality * (cards_reviewed - 1) + p_quality) / 
                GREATEST(cards_reviewed, 1.0)
            ),
            -- FIXED: Timezone-aware streak calculation
            study_streak = CASE
                WHEN last_review_date = v_client_today THEN study_streak
                WHEN last_review_date = v_client_yesterday THEN study_streak + 1
                ELSE 1
            END,
            last_review_date = v_client_today,
            next_review_date = LEAST(next_review_date, get_client_date(v_next_date, p_client_timezone)),
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- 3. FIXED TODAY'S STATISTICS WITH TIMEZONE AWARENESS
-- =============================================================================

-- Enhanced get_today_study_stats with timezone support
CREATE OR REPLACE FUNCTION public.get_today_study_stats(
    p_user_id UUID,
    p_client_timezone TEXT DEFAULT 'Europe/Warsaw'
) RETURNS TABLE(
    cards_studied_today INT,
    total_cards_ready INT,
    study_time_minutes INT,
    sessions_completed INT,
    new_cards_accepted_today INT,
    cards_mastered_today INT
) AS $$
DECLARE
    v_client_today DATE;
BEGIN
    -- Get today's date in client timezone
    v_client_today := get_current_client_date(p_client_timezone);
    
    RETURN QUERY
    WITH today_reviews AS (
        -- FIXED: Get reviews completed today in client timezone
        SELECT 
            r.id,
            r.card_id,
            r.student_id,
            r.completed_at,
            r.quality_rating,
            r.response_time_ms,
            r.created_at,
            c.lesson_id
        FROM public.sr_reviews r
        INNER JOIN public.sr_cards c ON r.card_id = c.id
        INNER JOIN public.lesson_participants lp ON c.lesson_id = lp.lesson_id
        WHERE r.student_id = p_user_id
          AND lp.student_id = p_user_id
          AND c.status = 'approved'
          AND r.completed_at IS NOT NULL
          AND get_client_date(r.completed_at, p_client_timezone) = v_client_today
    ),
    new_cards_today AS (
        -- Cards that were first completed today (moved from new status)
        SELECT 
            tr.card_id,
            tr.completed_at,
            tr.quality_rating
        FROM today_reviews tr
        WHERE NOT EXISTS (
            SELECT 1 FROM public.sr_reviews r2
            WHERE r2.card_id = tr.card_id
              AND r2.student_id = tr.student_id
              AND r2.completed_at IS NOT NULL
              AND get_client_date(r2.completed_at, p_client_timezone) < v_client_today
        )
    ),
    study_stats AS (
        SELECT 
            -- Cards studied today
            COUNT(*)::INT as cards_studied_today,
            
            -- Study time today
            COALESCE(
                ROUND(
                    SUM(
                        CASE 
                            WHEN response_time_ms IS NOT NULL
                            THEN response_time_ms / 60000.0
                            ELSE 0
                        END
                    )
                )::INT, 
                0
            ) as study_time_minutes,
            
            -- Sessions completed today (grouped by hour in client timezone)
            COUNT(DISTINCT DATE_TRUNC('hour', completed_at AT TIME ZONE p_client_timezone))::INT as sessions_completed,
            
            -- Cards mastered today
            (
                SELECT COUNT(*)::INT 
                FROM new_cards_today 
                WHERE quality_rating >= 4
            ) as cards_mastered_today
            
        FROM today_reviews
    ),
    ready_cards AS (
        -- Total cards currently ready for study
        SELECT COUNT(*)::INT as total_ready
        FROM public.get_cards_for_study(p_user_id, 'both', 100, 100)
    )
    SELECT 
        COALESCE(ss.cards_studied_today, 0),
        COALESCE(rc.total_ready, 0),
        COALESCE(ss.study_time_minutes, 0),
        COALESCE(ss.sessions_completed, 0),
        (SELECT COUNT(*)::INT FROM new_cards_today) as new_cards_accepted_today,
        COALESCE(ss.cards_mastered_today, 0)
    FROM study_stats ss
    CROSS JOIN ready_cards rc;
    
    -- If no data found, return zeros
    IF NOT FOUND THEN
        RETURN QUERY
        SELECT 
            0::INT, -- cards_studied_today
            (SELECT COUNT(*)::INT FROM public.get_cards_for_study(p_user_id, 'both', 100, 100)), -- total_cards_ready
            0::INT, -- study_time_minutes
            0::INT, -- sessions_completed
            0::INT, -- new_cards_accepted_today
            0::INT; -- cards_mastered_today
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- 4. FIXED USER STATISTICS WITH TIMEZONE AWARENESS
-- =============================================================================

-- Enhanced get_user_stats with timezone support
CREATE OR REPLACE FUNCTION get_user_stats(
    p_user_id UUID,
    p_client_timezone TEXT DEFAULT 'Europe/Warsaw'
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
    v_client_today DATE;
    i INT;
BEGIN
    -- Get current date in client timezone
    v_client_today := get_current_client_date(p_client_timezone);
    
    -- Initialize arrays
    v_weekly := ARRAY[0,0,0,0,0,0,0];
    v_monthly := ARRAY_FILL(0, ARRAY[30]);

    -- Get basic statistics
    SELECT
        COALESCE(COUNT(CASE WHEN r.completed_at IS NOT NULL THEN 1 END), 0) as tot_reviews,
        COALESCE(AVG(CASE WHEN r.completed_at IS NOT NULL THEN r.quality_rating END), 0.0) as avg_quality,
        COALESCE(MAX(p.study_streak), 0) as max_streak,
        COALESCE(SUM(p.cards_learned), 0) as learned_cards,
        COALESCE(COUNT(CASE 
            WHEN r.completed_at IS NULL 
                 AND get_client_date(r.scheduled_for, p_client_timezone) <= v_client_today 
            THEN 1 END), 0) as due_today,
        MIN(CASE 
            WHEN r.completed_at IS NULL 
            THEN get_client_date(r.scheduled_for, p_client_timezone) 
        END) as next_review,
        COUNT(DISTINCT p.lesson_id) as lessons_progress,
        COUNT(DISTINCT lp.lesson_id) as total_lessons_count
    INTO v_stats
    FROM public.lesson_participants lp
    LEFT JOIN public.sr_progress p ON lp.lesson_id = p.lesson_id AND lp.student_id = p.student_id
    LEFT JOIN public.sr_reviews r ON r.student_id = lp.student_id
    LEFT JOIN public.sr_cards c ON r.card_id = c.id AND c.lesson_id = lp.lesson_id
    WHERE lp.student_id = p_user_id;

    -- FIXED: Build weekly progress with timezone awareness (last 7 days)
    SELECT ARRAY_AGG(daily_count ORDER BY day_index) INTO v_weekly
    FROM (
        SELECT
            i AS day_index,
            COALESCE(COUNT(r.id), 0) as daily_count
        FROM generate_series(0, 6) AS i
        LEFT JOIN public.sr_reviews r ON r.student_id = p_user_id
            AND get_client_date(r.completed_at, p_client_timezone) = v_client_today - i
            AND r.completed_at IS NOT NULL
            AND EXISTS (
                SELECT 1 FROM public.sr_cards c
                JOIN public.lesson_participants lp ON c.lesson_id = lp.lesson_id
                WHERE c.id = r.card_id AND lp.student_id = p_user_id
            )
        GROUP BY i
        ORDER BY i
    ) weekly_data;

    -- FIXED: Build monthly progress with timezone awareness (last 30 days)
    SELECT ARRAY_AGG(daily_count ORDER BY day_index) INTO v_monthly
    FROM (
        SELECT
            i AS day_index,
            COALESCE(COUNT(r.id), 0) as daily_count
        FROM generate_series(0, 29) AS i
        LEFT JOIN public.sr_reviews r ON r.student_id = p_user_id
            AND get_client_date(r.completed_at, p_client_timezone) = v_client_today - i
            AND r.completed_at IS NOT NULL
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- 5. CREATE TIMEZONE-AWARE WRAPPER FUNCTIONS FOR FRONTEND
-- =============================================================================

-- Wrapper for get_user_stats that automatically uses client timezone
CREATE OR REPLACE FUNCTION get_user_stats_with_timezone(
    p_user_id UUID,
    p_client_timezone TEXT
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
BEGIN
    RETURN QUERY SELECT * FROM get_user_stats(p_user_id, p_client_timezone);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Wrapper for get_today_study_stats with timezone
CREATE OR REPLACE FUNCTION get_today_study_stats_with_timezone(
    p_user_id UUID,
    p_client_timezone TEXT
) RETURNS TABLE(
    cards_studied_today INT,
    total_cards_ready INT,
    study_time_minutes INT,
    sessions_completed INT,
    new_cards_accepted_today INT,
    cards_mastered_today INT
) AS $$
BEGIN
    RETURN QUERY SELECT * FROM get_today_study_stats(p_user_id, p_client_timezone);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- 6. DATA MIGRATION TO FIX EXISTING INCONSISTENCIES
-- =============================================================================

-- Fix existing progress table inconsistencies
DO $$
DECLARE
    prog_record RECORD;
    latest_review_date DATE;
    client_tz TEXT := 'Europe/Warsaw';
BEGIN
    -- Loop through all progress records and fix date inconsistencies
    FOR prog_record IN 
        SELECT sp.*, p.name as student_name
        FROM public.sr_progress sp
        INNER JOIN public.profiles p ON sp.student_id = p.id
    LOOP
        -- Get the actual latest review date in client timezone
        SELECT get_client_date(MAX(r.completed_at), client_tz)
        INTO latest_review_date
        FROM public.sr_reviews r
        INNER JOIN public.sr_cards c ON r.card_id = c.id
        WHERE r.student_id = prog_record.student_id
          AND c.lesson_id = prog_record.lesson_id
          AND r.completed_at IS NOT NULL;
        
        -- Update if there's a discrepancy
        IF latest_review_date IS NOT NULL AND latest_review_date != prog_record.last_review_date THEN
            UPDATE public.sr_progress
            SET 
                last_review_date = latest_review_date,
                updated_at = NOW()
            WHERE id = prog_record.id;
            
            RAISE NOTICE 'Fixed date inconsistency for student % lesson %: % -> %', 
                prog_record.student_name, prog_record.lesson_id, 
                prog_record.last_review_date, latest_review_date;
        END IF;
    END LOOP;
END $$;

-- =============================================================================
-- 7. GRANT PERMISSIONS
-- =============================================================================

GRANT EXECUTE ON FUNCTION get_client_date(TIMESTAMPTZ, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_current_client_date(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION same_client_date(TIMESTAMPTZ, TIMESTAMPTZ, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION record_sr_review(UUID, UUID, INT, INT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_today_study_stats(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_stats(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_stats_with_timezone(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_today_study_stats_with_timezone(UUID, TEXT) TO authenticated;

-- =============================================================================
-- 8. ADD HELPFUL COMMENTS
-- =============================================================================

COMMENT ON FUNCTION get_client_date(TIMESTAMPTZ, TEXT) IS
'Convert UTC timestamp to date in specified client timezone';

COMMENT ON FUNCTION get_current_client_date(TEXT) IS
'Get current date in specified client timezone';

COMMENT ON FUNCTION record_sr_review(UUID, UUID, INT, INT, TEXT) IS
'FIXED: Record spaced repetition review with timezone-aware date handling';

COMMENT ON FUNCTION get_today_study_stats(UUID, TEXT) IS
'FIXED: Get today''s study statistics using client timezone for date boundaries';

COMMENT ON FUNCTION get_user_stats(UUID, TEXT) IS
'FIXED: Get user statistics with timezone-aware progress calculation';

-- =============================================================================
-- MIGRATION SUMMARY
-- =============================================================================

-- CRITICAL FIXES IMPLEMENTED:
-- ✅ Added timezone-aware date helper functions
-- ✅ Fixed record_sr_review to use client timezone for progress tracking
-- ✅ Fixed get_today_study_stats to use client timezone for "today" calculation
-- ✅ Fixed get_user_stats to use client timezone for weekly/monthly progress
-- ✅ Created timezone-aware wrapper functions for frontend
-- ✅ Migrated existing data to fix date inconsistencies
-- ✅ Added comprehensive timezone support throughout the system

-- This migration resolves all identified date discrepancy issues and ensures
-- consistent timezone-aware date handling across the entire learning analytics system.