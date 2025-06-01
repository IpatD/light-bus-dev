-- =============================================================================
-- SPACED REPETITION LEARNING SYSTEM - DATABASE TRIGGERS
-- =============================================================================
-- This file contains all triggers and their supporting functions for the
-- spaced repetition e-learning platform
-- =============================================================================

-- =============================================================================
-- TRIGGER FUNCTIONS
-- =============================================================================

-- Function: Update flag timestamps when flags are modified
CREATE OR REPLACE FUNCTION trigger_update_flag_timestamps()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Update the updated_at timestamp whenever a flag is modified
    NEW.updated_at = NOW();
    
    -- If status is being changed to resolved or dismissed, set resolved_at
    IF (OLD.status = 'pending' AND NEW.status IN ('resolved', 'dismissed')) THEN
        NEW.resolved_at = NOW();
    END IF;
    
    -- If status is being changed back to pending, clear resolved_at and resolved_by
    IF (OLD.status IN ('resolved', 'dismissed') AND NEW.status = 'pending') THEN
        NEW.resolved_at = NULL;
        NEW.resolved_by = NULL;
        NEW.resolution = NULL;
    END IF;
    
    RETURN NEW;
END;
$$;

-- Function: Update spaced repetition progress when cards are approved
CREATE OR REPLACE FUNCTION trigger_update_sr_progress()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    participant_record RECORD;
BEGIN
    -- Only proceed if the card status changed to 'approved'
    IF (OLD.status != 'approved' AND NEW.status = 'approved') THEN
        
        -- Create initial progress records for all students in the lesson
        -- if this card belongs to a lesson
        IF NEW.lesson_id IS NOT NULL THEN
            FOR participant_record IN
                SELECT lp.user_id
                FROM lesson_participants lp
                WHERE lp.lesson_id = NEW.lesson_id
                AND lp.role = 'student'
            LOOP
                -- Insert initial progress record if it doesn't exist
                INSERT INTO sr_progress (
                    user_id,
                    card_id,
                    interval_days,
                    easiness_factor,
                    next_review,
                    review_count,
                    created_at,
                    updated_at
                )
                VALUES (
                    participant_record.user_id,
                    NEW.id,
                    0,  -- Initial interval
                    2.5,  -- Default easiness factor
                    NOW(),  -- Available for review immediately
                    0,  -- No reviews yet
                    NOW(),
                    NOW()
                )
                ON CONFLICT (user_id, card_id) DO NOTHING;
            END LOOP;
        END IF;
        
        -- Log the approval event
        INSERT INTO student_lesson_interactions (
            user_id,
            lesson_id,
            interaction_type,
            notes,
            created_at
        )
        VALUES (
            NEW.approved_by,
            NEW.lesson_id,
            'card_approved',
            'Card approved: ' || NEW.front_text,
            NOW()
        );
    END IF;
    
    RETURN NEW;
END;
$$;

-- Function: Validate card insertion permissions and data
CREATE OR REPLACE FUNCTION validate_sr_card_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    user_can_create BOOLEAN := FALSE;
    validation_result JSON;
    lesson_exists BOOLEAN := FALSE;
    user_in_lesson BOOLEAN := FALSE;
BEGIN
    -- Validate card content first
    SELECT validate_card_content(NEW.front_text, NEW.back_text) INTO validation_result;
    
    -- Check if validation passed
    IF NOT (validation_result->>'valid')::BOOLEAN THEN
        RAISE EXCEPTION 'Card validation failed: %', validation_result->>'errors';
    END IF;
    
    -- Check if user has permission to create cards
    IF NEW.created_by IS NOT NULL THEN
        -- Check if lesson exists
        IF NEW.lesson_id IS NOT NULL THEN
            SELECT EXISTS(SELECT 1 FROM lessons WHERE id = NEW.lesson_id) INTO lesson_exists;
            
            IF NOT lesson_exists THEN
                RAISE EXCEPTION 'Lesson does not exist';
            END IF;
            
            -- Check if user is participant in the lesson
            SELECT EXISTS(
                SELECT 1 FROM lesson_participants
                WHERE lesson_id = NEW.lesson_id
                AND user_id = NEW.created_by
            ) INTO user_in_lesson;
            
            IF NOT user_in_lesson THEN
                RAISE EXCEPTION 'User is not a participant in this lesson';
            END IF;
        END IF;
        
        user_can_create := TRUE;
    END IF;
    
    -- Set default values
    NEW.created_at := COALESCE(NEW.created_at, NOW());
    NEW.updated_at := COALESCE(NEW.updated_at, NOW());
    NEW.status := COALESCE(NEW.status, 'pending');
    
    RETURN NEW;
END;
$$;

-- =============================================================================
-- TRIGGERS
-- =============================================================================

-- Trigger: Update flag timestamps on sr_card_flags table
DROP TRIGGER IF EXISTS trigger_sr_card_flags_update ON sr_card_flags;
CREATE TRIGGER trigger_sr_card_flags_update
    BEFORE UPDATE ON sr_card_flags
    FOR EACH ROW
    EXECUTE FUNCTION trigger_update_flag_timestamps();

-- Trigger: Update progress when cards are approved
DROP TRIGGER IF EXISTS trigger_sr_card_progress ON sr_cards;
CREATE TRIGGER trigger_sr_card_progress
    AFTER UPDATE ON sr_cards
    FOR EACH ROW
    EXECUTE FUNCTION trigger_update_sr_progress();

-- Trigger: Validate card creation permissions
DROP TRIGGER IF EXISTS validate_sr_card_insert_trigger ON sr_cards;
CREATE TRIGGER validate_sr_card_insert_trigger
    BEFORE INSERT ON sr_cards
    FOR EACH ROW
    EXECUTE FUNCTION validate_sr_card_insert();

-- =============================================================================
-- TRIGGER MANAGEMENT FUNCTIONS
-- =============================================================================

-- Function to enable all triggers
CREATE OR REPLACE FUNCTION enable_all_triggers()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
BEGIN
    -- Enable flag update trigger
    ALTER TABLE sr_card_flags ENABLE TRIGGER trigger_sr_card_flags_update;
    
    -- Enable card progress trigger
    ALTER TABLE sr_cards ENABLE TRIGGER trigger_sr_card_progress;
    
    -- Enable card validation trigger
    ALTER TABLE sr_cards ENABLE TRIGGER validate_sr_card_insert_trigger;
    
    RETURN 'All triggers enabled successfully';
END;
$$;

-- Function to disable all triggers
CREATE OR REPLACE FUNCTION disable_all_triggers()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
BEGIN
    -- Disable flag update trigger
    ALTER TABLE sr_card_flags DISABLE TRIGGER trigger_sr_card_flags_update;
    
    -- Disable card progress trigger
    ALTER TABLE sr_cards DISABLE TRIGGER trigger_sr_card_progress;
    
    -- Disable card validation trigger
    ALTER TABLE sr_cards DISABLE TRIGGER validate_sr_card_insert_trigger;
    
    RETURN 'All triggers disabled successfully';
END;
$$;

-- Function to check trigger status
CREATE OR REPLACE FUNCTION check_trigger_status()
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    trigger_status JSON;
BEGIN
    SELECT json_build_object(
        'sr_card_flags_update', (
            SELECT tgenabled
            FROM pg_trigger
            WHERE tgname = 'trigger_sr_card_flags_update'
        ),
        'sr_card_progress', (
            SELECT tgenabled
            FROM pg_trigger
            WHERE tgname = 'trigger_sr_card_progress'
        ),
        'validate_sr_card_insert', (
            SELECT tgenabled
            FROM pg_trigger
            WHERE tgname = 'validate_sr_card_insert_trigger'
        )
    ) INTO trigger_status;
    
    RETURN trigger_status;
END;
$$;

-- =============================================================================
-- END OF TRIGGERS
-- =============================================================================
-- Total triggers: 3
-- Total trigger functions: 3
-- Last updated: 2025-05-30
-- =============================================================================
