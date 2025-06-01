-- =============================================================================
-- TRANSCRIPTION AND AUDIO PROCESSING FUNCTIONS
-- =============================================================================
-- Functions for handling lesson transcripts, summaries, and content processing
-- =============================================================================

-- Create transcript for lesson
CREATE OR REPLACE FUNCTION create_transcript(
    p_lesson_id UUID,
    p_content TEXT,
    p_language TEXT DEFAULT 'en',
    p_confidence_score DECIMAL DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    transcript_id UUID;
BEGIN
    INSERT INTO transcripts (lesson_id, content, language, confidence_score, created_at, updated_at)
    VALUES (p_lesson_id, p_content, p_language, p_confidence_score, NOW(), NOW())
    RETURNING id INTO transcript_id;
    
    RETURN transcript_id;
END;
$$;

-- Update transcript
CREATE OR REPLACE FUNCTION update_transcript(
    p_transcript_id UUID,
    p_content TEXT,
    p_confidence_score DECIMAL DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE transcripts
    SET 
        content = p_content,
        confidence_score = COALESCE(p_confidence_score, confidence_score),
        updated_at = NOW()
    WHERE id = p_transcript_id;
    
    RETURN FOUND;
END;
$$;

-- Create summary for lesson
CREATE OR REPLACE FUNCTION create_summary(
    p_lesson_id UUID,
    p_summary_text TEXT,
    p_key_points TEXT[] DEFAULT NULL,
    p_generated_by TEXT DEFAULT 'ai'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    summary_id UUID;
BEGIN
    INSERT INTO summaries (lesson_id, summary_text, key_points, generated_by, created_at, updated_at)
    VALUES (p_lesson_id, p_summary_text, p_key_points, p_generated_by, NOW(), NOW())
    RETURNING id INTO summary_id;
    
    RETURN summary_id;
END;
$$;

-- Get lesson content (transcript + summary)
CREATE OR REPLACE FUNCTION get_lesson_content(p_lesson_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    content JSON;
BEGIN
    SELECT json_build_object(
        'lesson', row_to_json(l),
        'transcript', (
            SELECT row_to_json(t)
            FROM transcripts t
            WHERE t.lesson_id = l.id
            ORDER BY t.created_at DESC
            LIMIT 1
        ),
        'summary', (
            SELECT row_to_json(s)
            FROM summaries s
            WHERE s.lesson_id = l.id
            ORDER BY s.created_at DESC
            LIMIT 1
        ),
        'cards', COALESCE(
            (SELECT json_agg(row_to_json(sc))
             FROM sr_cards sc
             WHERE sc.lesson_id = l.id
             AND sc.status = 'approved'), '[]'::json
        )
    )
    INTO content
    FROM lessons l
    WHERE l.id = p_lesson_id;
    
    RETURN content;
END;
$$;

-- Extract key terms from transcript
CREATE OR REPLACE FUNCTION extract_key_terms(p_transcript_content TEXT)
RETURNS TEXT[]
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    words TEXT[];
    word TEXT;
    key_terms TEXT[] := '{}';
    word_count INTEGER;
BEGIN
    -- Simple key term extraction (in production, would use more sophisticated NLP)
    -- Split text into words and find frequent meaningful terms
    SELECT string_to_array(lower(regexp_replace(p_transcript_content, '[^\w\s]', ' ', 'g')), ' ') INTO words;
    
    -- Count word frequencies and extract terms longer than 3 characters
    FOR word IN SELECT DISTINCT unnest(words) LOOP
        IF LENGTH(word) > 3 AND word NOT IN ('this', 'that', 'with', 'have', 'will', 'been', 'from', 'they', 'know', 'want', 'been', 'good', 'much', 'some', 'time', 'very', 'when', 'come', 'here', 'just', 'like', 'long', 'make', 'many', 'over', 'such', 'take', 'than', 'them', 'well', 'were') THEN
            SELECT COUNT(*) INTO word_count FROM unnest(words) w WHERE w = word;
            IF word_count >= 2 THEN  -- Appears at least twice
                key_terms := array_append(key_terms, word);
            END IF;
        END IF;
    END LOOP;
    
    RETURN key_terms[1:20];  -- Return top 20 terms
END;
$$;

-- Generate automatic summary from transcript
CREATE OR REPLACE FUNCTION generate_auto_summary(
    p_lesson_id UUID,
    p_max_sentences INTEGER DEFAULT 5
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    transcript_content TEXT;
    sentences TEXT[];
    summary_text TEXT;
    key_points TEXT[];
    summary_id UUID;
BEGIN
    -- Get the latest transcript
    SELECT content INTO transcript_content
    FROM transcripts
    WHERE lesson_id = p_lesson_id
    ORDER BY created_at DESC
    LIMIT 1;
    
    IF transcript_content IS NULL THEN
        RAISE EXCEPTION 'No transcript found for lesson';
    END IF;
    
    -- Split into sentences (simple approach)
    SELECT string_to_array(
        regexp_replace(transcript_content, '[.!?]+\s+', '.|', 'g'), 
        '|'
    ) INTO sentences;
    
    -- Take first few sentences as summary (in production, would use more sophisticated summarization)
    summary_text := array_to_string(sentences[1:p_max_sentences], ' ');
    
    -- Extract key points
    key_points := extract_key_terms(transcript_content);
    
    -- Create the summary
    INSERT INTO summaries (lesson_id, summary_text, key_points, generated_by, created_at, updated_at)
    VALUES (p_lesson_id, summary_text, key_points, 'auto', NOW(), NOW())
    RETURNING id INTO summary_id;
    
    RETURN summary_id;
END;
$$;

-- Search transcripts
CREATE OR REPLACE FUNCTION search_transcripts(
    p_search_term TEXT,
    p_user_id UUID DEFAULT NULL,
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE(
    transcript_id UUID,
    lesson_id UUID,
    lesson_title TEXT,
    content_snippet TEXT,
    confidence_score DECIMAL,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id,
        t.lesson_id,
        l.title,
        -- Extract snippet around search term
        CASE 
            WHEN position(lower(p_search_term) in lower(t.content)) > 0 THEN
                substr(
                    t.content, 
                    greatest(1, position(lower(p_search_term) in lower(t.content)) - 100),
                    200
                )
            ELSE substr(t.content, 1, 200)
        END as content_snippet,
        t.confidence_score,
        t.created_at
    FROM transcripts t
    JOIN lessons l ON l.id = t.lesson_id
    LEFT JOIN lesson_participants lp ON lp.lesson_id = l.id
    WHERE t.content ILIKE '%' || p_search_term || '%'
    AND (p_user_id IS NULL OR lp.user_id = p_user_id)
    ORDER BY t.created_at DESC
    LIMIT p_limit OFFSET p_offset;
END;
$$;

-- Get transcript statistics
CREATE OR REPLACE FUNCTION get_transcript_statistics()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    stats JSON;
BEGIN
    SELECT json_build_object(
        'total_transcripts', COUNT(*),
        'avg_confidence_score', ROUND(AVG(confidence_score), 2),
        'total_words', SUM(array_length(string_to_array(content, ' '), 1)),
        'avg_words_per_transcript', ROUND(AVG(array_length(string_to_array(content, ' '), 1)), 0),
        'languages', (
            SELECT json_object_agg(language, lang_count)
            FROM (
                SELECT language, COUNT(*) as lang_count
                FROM transcripts
                GROUP BY language
            ) lang_stats
        ),
        'transcripts_by_month', (
            SELECT json_agg(
                json_build_object(
                    'month', month_year,
                    'count', transcript_count
                )
            )
            FROM (
                SELECT 
                    to_char(created_at, 'YYYY-MM') as month_year,
                    COUNT(*) as transcript_count
                FROM transcripts
                GROUP BY to_char(created_at, 'YYYY-MM')
                ORDER BY month_year DESC
                LIMIT 12
            ) monthly_stats
        )
    )
    INTO stats
    FROM transcripts;
    
    RETURN stats;
END;
$$;

-- Process transcript for card generation suggestions
CREATE OR REPLACE FUNCTION suggest_cards_from_transcript(
    p_lesson_id UUID,
    p_min_confidence DECIMAL DEFAULT 0.7
)
RETURNS TABLE(
    suggested_front TEXT,
    suggested_back TEXT,
    confidence_score DECIMAL,
    source_context TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    transcript_content TEXT;
    sentences TEXT[];
    sentence TEXT;
    question_patterns TEXT[] := ARRAY['what is', 'what are', 'how to', 'define', 'explain'];
    pattern TEXT;
    pos INTEGER;
BEGIN
    -- Get transcript content
    SELECT content INTO transcript_content
    FROM transcripts
    WHERE lesson_id = p_lesson_id
    AND confidence_score >= p_min_confidence
    ORDER BY created_at DESC
    LIMIT 1;
    
    IF transcript_content IS NULL THEN
        RETURN;
    END IF;
    
    -- Split into sentences
    SELECT string_to_array(
        regexp_replace(transcript_content, '[.!?]+\s+', '.|', 'g'), 
        '|'
    ) INTO sentences;
    
    -- Look for patterns that suggest Q&A pairs
    FOREACH sentence IN ARRAY sentences LOOP
        IF LENGTH(sentence) > 20 AND LENGTH(sentence) < 200 THEN
            FOREACH pattern IN ARRAY question_patterns LOOP
                pos := position(lower(pattern) in lower(sentence));
                IF pos > 0 THEN
                    RETURN QUERY SELECT 
                        pattern || ' ' || substr(sentence, pos + length(pattern) + 1, 50) || '?',
                        sentence,
                        0.8::DECIMAL,
                        substr(transcript_content, greatest(1, position(sentence in transcript_content) - 50), 150);
                END IF;
            END LOOP;
        END IF;
    END LOOP;
    
    RETURN;
END;
$$;

-- Update summary with human edits
CREATE OR REPLACE FUNCTION update_summary(
    p_summary_id UUID,
    p_summary_text TEXT,
    p_key_points TEXT[] DEFAULT NULL,
    p_edited_by UUID DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE summaries
    SET 
        summary_text = p_summary_text,
        key_points = COALESCE(p_key_points, key_points),
        generated_by = CASE 
            WHEN p_edited_by IS NOT NULL THEN 'human'
            ELSE generated_by
        END,
        updated_at = NOW()
    WHERE id = p_summary_id;
    
    RETURN FOUND;
END;
$$;

-- Get content processing queue
CREATE OR REPLACE FUNCTION get_content_processing_queue()
RETURNS TABLE(
    lesson_id UUID,
    lesson_title TEXT,
    has_transcript BOOLEAN,
    has_summary BOOLEAN,
    recording_url TEXT,
    scheduled_at TIMESTAMPTZ,
    status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        l.id,
        l.title,
        EXISTS(SELECT 1 FROM transcripts t WHERE t.lesson_id = l.id) as has_transcript,
        EXISTS(SELECT 1 FROM summaries s WHERE s.lesson_id = l.id) as has_summary,
        l.recording_url,
        l.scheduled_at,
        l.status
    FROM lessons l
    WHERE l.status IN ('completed', 'recording')
    AND l.recording_url IS NOT NULL
    ORDER BY 
        CASE WHEN NOT EXISTS(SELECT 1 FROM transcripts t WHERE t.lesson_id = l.id) THEN 0 ELSE 1 END,
        l.scheduled_at DESC;
END;
$$;

-- Batch process transcripts
CREATE OR REPLACE FUNCTION batch_process_transcripts(p_lesson_ids UUID[])
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    lesson_id UUID;
    processed_count INTEGER := 0;
    summary_id UUID;
    result JSON;
BEGIN
    FOREACH lesson_id IN ARRAY p_lesson_ids LOOP
        -- Generate auto summary if transcript exists but no summary
        IF EXISTS(SELECT 1 FROM transcripts WHERE lesson_id = lesson_id) 
           AND NOT EXISTS(SELECT 1 FROM summaries WHERE lesson_id = lesson_id) THEN
            BEGIN
                summary_id := generate_auto_summary(lesson_id, 5);
                processed_count := processed_count + 1;
            EXCEPTION WHEN OTHERS THEN
                -- Continue processing other lessons if one fails
                CONTINUE;
            END;
        END IF;
    END LOOP;
    
    SELECT json_build_object(
        'processed_lessons', processed_count,
        'total_requested', array_length(p_lesson_ids, 1)
    ) INTO result;
    
    RETURN result;
END;
$$;