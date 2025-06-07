-- Migration: Add Multiple Audio File Support for Lessons
-- This migration creates the infrastructure for multiple audio files per lesson
-- with proper constraints, cascading deletion, and system metrics

-- Create lesson_media table for multiple audio files per lesson
CREATE TABLE IF NOT EXISTS public.lesson_media (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    lesson_id UUID REFERENCES public.lessons(id) ON DELETE CASCADE NOT NULL,
    file_path TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_size BIGINT NOT NULL,
    mime_type TEXT NOT NULL,
    upload_order INTEGER NOT NULL DEFAULT 1,
    processing_status TEXT DEFAULT 'pending' CHECK (processing_status IN ('pending', 'processing', 'completed', 'failed')),
    processing_job_id UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Ensure unique ordering per lesson
    UNIQUE(lesson_id, upload_order)
);

-- Enable RLS on lesson_media
ALTER TABLE public.lesson_media ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for lesson_media
CREATE POLICY "Teachers can manage media for their lessons" ON public.lesson_media
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.lessons l
            WHERE l.id = lesson_id AND l.teacher_id = auth.uid()
        )
    );

CREATE POLICY "Students can view media from their lessons" ON public.lesson_media
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.lesson_participants lp
            WHERE lp.lesson_id = lesson_media.lesson_id AND lp.student_id = auth.uid()
        )
    );

-- Create indexes for performance
CREATE INDEX idx_lesson_media_lesson_id ON public.lesson_media(lesson_id);
CREATE INDEX idx_lesson_media_upload_order ON public.lesson_media(lesson_id, upload_order);
CREATE INDEX idx_lesson_media_processing_status ON public.lesson_media(processing_status);
CREATE INDEX idx_lesson_media_created_at ON public.lesson_media(created_at);

-- Add updated_at trigger for lesson_media
CREATE TRIGGER update_lesson_media_updated_at
    BEFORE UPDATE ON public.lesson_media
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Create system_settings table for configurable limits
CREATE TABLE IF NOT EXISTS public.system_settings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    setting_key TEXT UNIQUE NOT NULL,
    setting_value TEXT NOT NULL,
    setting_type TEXT DEFAULT 'string' CHECK (setting_type IN ('string', 'number', 'boolean', 'json')),
    description TEXT,
    is_public BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS on system_settings
ALTER TABLE public.system_settings ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for system_settings
CREATE POLICY "Public settings are viewable by all authenticated users" ON public.system_settings
    FOR SELECT USING (is_public = TRUE AND auth.role() = 'authenticated');

CREATE POLICY "Admins can manage all system settings" ON public.system_settings
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Add updated_at trigger for system_settings
CREATE TRIGGER update_system_settings_updated_at
    BEFORE UPDATE ON public.system_settings
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Insert default system settings
INSERT INTO public.system_settings (setting_key, setting_value, setting_type, description, is_public) VALUES
    ('max_audio_files_per_lesson', '5', 'number', 'Maximum number of audio files allowed per lesson', TRUE),
    ('max_audio_file_size_mb', '100', 'number', 'Maximum size for audio files in MB', TRUE),
    ('supported_audio_formats', '["audio/mpeg","audio/wav","audio/m4a","audio/aac","audio/ogg"]', 'json', 'List of supported audio MIME types', TRUE),
    ('auto_process_audio', 'true', 'boolean', 'Automatically process uploaded audio files', TRUE),
    ('audio_processing_provider', 'openai', 'string', 'Default AI service provider for audio processing', FALSE);

-- Function: Check if lesson can accept more audio files
CREATE OR REPLACE FUNCTION check_lesson_audio_limit(p_lesson_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    current_count INTEGER;
    max_allowed INTEGER;
BEGIN
    -- Get current count of audio files for the lesson
    SELECT COUNT(*) INTO current_count
    FROM public.lesson_media
    WHERE lesson_id = p_lesson_id;
    
    -- Get maximum allowed from settings
    SELECT setting_value::INTEGER INTO max_allowed
    FROM public.system_settings
    WHERE setting_key = 'max_audio_files_per_lesson';
    
    -- Default to 5 if setting not found
    IF max_allowed IS NULL THEN
        max_allowed := 5;
    END IF;
    
    RETURN current_count < max_allowed;
END;
$$ LANGUAGE plpgsql;

-- Function: Get next upload order for lesson
CREATE OR REPLACE FUNCTION get_next_upload_order(p_lesson_id UUID)
RETURNS INTEGER AS $$
DECLARE
    next_order INTEGER;
BEGIN
    SELECT COALESCE(MAX(upload_order), 0) + 1 INTO next_order
    FROM public.lesson_media
    WHERE lesson_id = p_lesson_id;
    
    RETURN next_order;
END;
$$ LANGUAGE plpgsql;

-- Function: Add audio file to lesson
CREATE OR REPLACE FUNCTION add_lesson_audio(
    p_lesson_id UUID,
    p_file_path TEXT,
    p_file_name TEXT,
    p_file_size BIGINT,
    p_mime_type TEXT
) RETURNS TABLE(
    media_id UUID,
    upload_order INTEGER,
    success BOOLEAN,
    message TEXT
) AS $$
DECLARE
    v_media_id UUID;
    v_upload_order INTEGER;
    v_can_add BOOLEAN;
BEGIN
    -- Check if lesson exists and user has permission
    IF NOT EXISTS(
        SELECT 1 FROM public.lessons l
        WHERE l.id = p_lesson_id AND l.teacher_id = auth.uid()
    ) THEN
        RETURN QUERY SELECT NULL::UUID, NULL::INTEGER, FALSE, 'Lesson not found or access denied';
        RETURN;
    END IF;
    
    -- Check audio file limit
    SELECT check_lesson_audio_limit(p_lesson_id) INTO v_can_add;
    
    IF NOT v_can_add THEN
        RETURN QUERY SELECT NULL::UUID, NULL::INTEGER, FALSE, 'Maximum audio files limit reached for this lesson';
        RETURN;
    END IF;
    
    -- Get next upload order
    SELECT get_next_upload_order(p_lesson_id) INTO v_upload_order;
    
    -- Insert new media record
    INSERT INTO public.lesson_media (
        lesson_id, file_path, file_name, file_size, mime_type, upload_order
    ) VALUES (
        p_lesson_id, p_file_path, p_file_name, p_file_size, p_mime_type, v_upload_order
    ) RETURNING id INTO v_media_id;
    
    -- Update lesson has_audio flag
    UPDATE public.lessons
    SET has_audio = TRUE, updated_at = NOW()
    WHERE id = p_lesson_id;
    
    RETURN QUERY SELECT v_media_id, v_upload_order, TRUE, 'Audio file added successfully';
    
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT NULL::UUID, NULL::INTEGER, FALSE, 'Failed to add audio file: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Function: Remove audio file from lesson
CREATE OR REPLACE FUNCTION remove_lesson_audio(
    p_media_id UUID
) RETURNS TABLE(
    success BOOLEAN,
    message TEXT
) AS $$
DECLARE
    v_lesson_id UUID;
    v_file_path TEXT;
    remaining_count INTEGER;
BEGIN
    -- Get lesson_id and file_path before deletion
    SELECT lesson_id, file_path INTO v_lesson_id, v_file_path
    FROM public.lesson_media
    WHERE id = p_media_id;
    
    IF v_lesson_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Audio file not found';
        RETURN;
    END IF;
    
    -- Check if user has permission to delete
    IF NOT EXISTS(
        SELECT 1 FROM public.lessons l
        WHERE l.id = v_lesson_id AND l.teacher_id = auth.uid()
    ) THEN
        RETURN QUERY SELECT FALSE, 'Access denied';
        RETURN;
    END IF;
    
    -- Delete the media record
    DELETE FROM public.lesson_media WHERE id = p_media_id;
    
    -- Check if this was the last audio file
    SELECT COUNT(*) INTO remaining_count
    FROM public.lesson_media
    WHERE lesson_id = v_lesson_id;
    
    -- Update lesson has_audio flag if no more audio files
    IF remaining_count = 0 THEN
        UPDATE public.lessons
        SET has_audio = FALSE, updated_at = NOW()
        WHERE id = v_lesson_id;
    END IF;
    
    RETURN QUERY SELECT TRUE, 'Audio file removed successfully';
    
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT FALSE, 'Failed to remove audio file: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Function: Get lesson audio files
CREATE OR REPLACE FUNCTION get_lesson_audio_files(
    p_lesson_id UUID
) RETURNS TABLE(
    media_id UUID,
    file_path TEXT,
    file_name TEXT,
    file_size BIGINT,
    mime_type TEXT,
    upload_order INTEGER,
    processing_status TEXT,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    -- Check if user has access to the lesson
    IF NOT EXISTS(
        SELECT 1 FROM public.lessons l
        LEFT JOIN public.lesson_participants lp ON l.id = lp.lesson_id
        WHERE l.id = p_lesson_id 
        AND (l.teacher_id = auth.uid() OR lp.student_id = auth.uid())
    ) THEN
        RETURN;
    END IF;
    
    RETURN QUERY
    SELECT 
        lm.id as media_id,
        lm.file_path,
        lm.file_name,
        lm.file_size,
        lm.mime_type,
        lm.upload_order,
        lm.processing_status,
        lm.created_at
    FROM public.lesson_media lm
    WHERE lm.lesson_id = p_lesson_id
    ORDER BY lm.upload_order ASC;
END;
$$ LANGUAGE plpgsql;

-- Function: Update lesson audio processing status
CREATE OR REPLACE FUNCTION update_audio_processing_status(
    p_media_id UUID,
    p_status TEXT,
    p_processing_job_id UUID DEFAULT NULL
) RETURNS BOOLEAN AS $$
BEGIN
    UPDATE public.lesson_media
    SET 
        processing_status = p_status,
        processing_job_id = p_processing_job_id,
        updated_at = NOW()
    WHERE id = p_media_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION check_lesson_audio_limit TO authenticated;
GRANT EXECUTE ON FUNCTION get_next_upload_order TO authenticated;
GRANT EXECUTE ON FUNCTION add_lesson_audio TO authenticated;
GRANT EXECUTE ON FUNCTION remove_lesson_audio TO authenticated;
GRANT EXECUTE ON FUNCTION get_lesson_audio_files TO authenticated;
GRANT EXECUTE ON FUNCTION update_audio_processing_status TO authenticated;

-- Update existing lessons to maintain backward compatibility
-- For lessons that have recording_path but no lesson_media records
INSERT INTO public.lesson_media (lesson_id, file_path, file_name, file_size, mime_type, upload_order)
SELECT 
    l.id,
    l.recording_path,
    SUBSTRING(l.recording_path FROM '[^/]*$') as file_name,
    0 as file_size, -- Size unknown for existing files
    'audio/mpeg' as mime_type, -- Assume MP3 for existing files
    1 as upload_order
FROM public.lessons l
WHERE l.recording_path IS NOT NULL 
AND l.recording_path != ''
AND NOT EXISTS (
    SELECT 1 FROM public.lesson_media lm WHERE lm.lesson_id = l.id
);

-- Add comment for future reference
COMMENT ON TABLE public.lesson_media IS 'Stores multiple audio files per lesson with processing status tracking';
COMMENT ON TABLE public.system_settings IS 'Configurable system-wide settings and limits';
COMMENT ON FUNCTION add_lesson_audio IS 'Adds an audio file to a lesson with limit checking';
COMMENT ON FUNCTION remove_lesson_audio IS 'Removes an audio file from a lesson and updates flags';
COMMENT ON FUNCTION get_lesson_audio_files IS 'Retrieves all audio files for a lesson';