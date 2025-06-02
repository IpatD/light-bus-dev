-- Storage Bucket Policies and Configuration
-- This migration creates the necessary storage buckets and RLS policies

-- =============================================
-- CREATE STORAGE BUCKETS
-- =============================================

-- Create lesson-media bucket (Public: true for lesson recordings/materials)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'lesson-media',
  'lesson-media', 
  true,
  104857600, -- 100MB limit
  ARRAY['audio/mpeg', 'audio/wav', 'audio/mp3', 'audio/mp4', 'video/mp4', 'application/pdf', 'text/plain']
)
ON CONFLICT (id) DO UPDATE SET
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Create user-uploads bucket (Public: false for user-specific content)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'user-uploads',
  'user-uploads',
  false,
  52428800, -- 50MB limit
  ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'application/pdf', 'text/plain']
)
ON CONFLICT (id) DO UPDATE SET
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Create media bucket (for backwards compatibility with existing code)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'media',
  'media',
  true,
  104857600, -- 100MB limit
  ARRAY['audio/mpeg', 'audio/wav', 'audio/mp3', 'audio/mp4', 'video/mp4', 'application/pdf', 'text/plain']
)
ON CONFLICT (id) DO UPDATE SET
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- =============================================
-- STORAGE RLS POLICIES
-- =============================================

-- NOTE: RLS must be enabled manually via Supabase Dashboard
-- See manual setup instructions in docs/STORAGE_MANUAL_SETUP.md
--
-- Manual step required: ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
-- This command requires superuser permissions not available in migrations

-- =============================================
-- LESSON-MEDIA BUCKET POLICIES
-- =============================================

-- Teachers can upload lesson media to their own lesson folders
CREATE POLICY "Teachers can upload lesson media" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'lesson-media' AND
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'teacher'
    ) AND
    -- Ensure teachers can only upload to folders they own
    (storage.foldername(name))[1] IN (
      SELECT l.id::text FROM public.lessons l
      WHERE l.teacher_id = auth.uid()
    )
  );

-- Teachers can view and manage their own lesson media
CREATE POLICY "Teachers can manage their lesson media" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'lesson-media' AND
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'teacher'
    ) AND
    (storage.foldername(name))[1] IN (
      SELECT l.id::text FROM public.lessons l
      WHERE l.teacher_id = auth.uid()
    )
  );

-- Teachers can update their own lesson media
CREATE POLICY "Teachers can update their lesson media" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'lesson-media' AND
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'teacher'
    ) AND
    (storage.foldername(name))[1] IN (
      SELECT l.id::text FROM public.lessons l
      WHERE l.teacher_id = auth.uid()
    )
  );

-- Teachers can delete their own lesson media
CREATE POLICY "Teachers can delete their lesson media" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'lesson-media' AND
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'teacher'
    ) AND
    (storage.foldername(name))[1] IN (
      SELECT l.id::text FROM public.lessons l
      WHERE l.teacher_id = auth.uid()
    )
  );

-- Students can view lesson media from lessons they're enrolled in
CREATE POLICY "Students can view enrolled lesson media" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'lesson-media' AND
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'student'
    ) AND
    (storage.foldername(name))[1] IN (
      SELECT lp.lesson_id::text FROM public.lesson_participants lp
      WHERE lp.student_id = auth.uid()
    )
  );

-- =============================================
-- USER-UPLOADS BUCKET POLICIES
-- =============================================

-- Users can upload to their own user folder
CREATE POLICY "Users can upload to their folder" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'user-uploads' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );

-- Users can view their own uploads
CREATE POLICY "Users can view their uploads" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'user-uploads' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );

-- Users can update their own uploads
CREATE POLICY "Users can update their uploads" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'user-uploads' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );

-- Users can delete their own uploads
CREATE POLICY "Users can delete their uploads" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'user-uploads' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );

-- =============================================
-- MEDIA BUCKET POLICIES (Legacy Support)
-- =============================================

-- Teachers can upload to media bucket
CREATE POLICY "Teachers can upload to media bucket" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'media' AND
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'teacher'
    )
  );

-- Teachers can manage media bucket files
CREATE POLICY "Teachers can manage media bucket" ON storage.objects
  FOR ALL USING (
    bucket_id = 'media' AND
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'teacher'
    )
  );

-- Students can view media bucket files
CREATE POLICY "Students can view media bucket" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'media' AND
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'student'
    )
  );

-- =============================================
-- ADMIN POLICIES
-- =============================================

-- Admins can manage all storage objects
CREATE POLICY "Admins can manage all storage" ON storage.objects
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- =============================================
-- HELPER FUNCTIONS
-- =============================================

-- Function to get file URL with proper permissions
CREATE OR REPLACE FUNCTION public.get_file_url(
  bucket_name TEXT,
  file_path TEXT
)
RETURNS TEXT AS $$
DECLARE
  file_url TEXT;
BEGIN
  -- For public buckets, return direct URL
  IF bucket_name IN ('lesson-media', 'media') THEN
    SELECT concat(
      current_setting('app.supabase_url', true),
      '/storage/v1/object/public/',
      bucket_name, '/', file_path
    ) INTO file_url;
  ELSE
    -- For private buckets, return signed URL (expires in 1 hour)
    SELECT storage.get_signed_url(bucket_name, file_path, 3600) INTO file_url;
  END IF;
  
  RETURN file_url;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to organize lesson media by creating proper folder structure
CREATE OR REPLACE FUNCTION public.organize_lesson_file(
  lesson_id UUID,
  original_filename TEXT,
  file_type TEXT DEFAULT 'media'
)
RETURNS TEXT AS $$
DECLARE
  file_path TEXT;
  file_extension TEXT;
  clean_filename TEXT;
BEGIN
  -- Extract file extension
  file_extension := lower(substring(original_filename from '\.([^.]*)$'));
  
  -- Clean filename (remove special characters, spaces)
  clean_filename := regexp_replace(
    lower(original_filename), 
    '[^a-z0-9._-]', 
    '_', 
    'g'
  );
  
  -- Create organized path: lesson_id/type/timestamp_filename
  file_path := concat(
    lesson_id::text, '/',
    file_type, '/',
    extract(epoch from now())::bigint, '_',
    clean_filename
  );
  
  RETURN file_path;
END;
$$ LANGUAGE plpgsql;

-- Add storage usage tracking
CREATE OR REPLACE FUNCTION public.update_storage_metrics()
RETURNS void AS $$
DECLARE
  total_size BIGINT;
  file_count BIGINT;
BEGIN
  -- Calculate total storage usage
  SELECT 
    COALESCE(SUM(metadata->>'size')::BIGINT, 0),
    COUNT(*)
  INTO total_size, file_count
  FROM storage.objects;
  
  -- Insert metrics
  INSERT INTO public.system_metrics (
    metric_name,
    metric_value,
    metric_unit,
    metric_category
  ) VALUES 
    ('total_storage_bytes', total_size, 'bytes', 'usage'),
    ('total_files', file_count, 'count', 'usage');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- NOTE: Index creation on storage.objects requires superuser permissions
-- These indexes must be created manually via Supabase Dashboard or by admin
-- See STORAGE_MANUAL_SETUP.md for instructions
--
-- Manual indexes needed:
-- CREATE INDEX IF NOT EXISTS idx_storage_objects_bucket_owner ON storage.objects (bucket_id, owner);
-- CREATE INDEX IF NOT EXISTS idx_storage_objects_name ON storage.objects USING gin (name gin_trgm_ops);

-- Insert initial storage configuration
-- NOTE: Using WHERE NOT EXISTS to avoid conflicts since unique constraint may not exist
INSERT INTO public.system_metrics (metric_name, metric_value, metric_unit, metric_category)
SELECT 'max_file_size_mb', 100, 'MB', 'performance'
WHERE NOT EXISTS (
  SELECT 1 FROM public.system_metrics WHERE metric_name = 'max_file_size_mb'
);

INSERT INTO public.system_metrics (metric_name, metric_value, metric_unit, metric_category)
SELECT 'storage_quota_gb', 10, 'GB', 'usage'
WHERE NOT EXISTS (
  SELECT 1 FROM public.system_metrics WHERE metric_name = 'storage_quota_gb'
);

-- NOTE: Comments on storage.objects table and policies require superuser permissions
-- These comments must be added manually if needed:
-- COMMENT ON TABLE storage.objects IS 'Storage objects with RLS policies for secure file access';
-- COMMENT ON POLICY "Teachers can upload lesson media" ON storage.objects IS 'Teachers can only upload files to folders corresponding to their own lessons';
-- COMMENT ON POLICY "Students can view enrolled lesson media" ON storage.objects IS 'Students can only access media from lessons they are enrolled in';