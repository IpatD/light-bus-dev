-- Light Bus E-Learning Platform - Production Database Setup Script
-- Run this script after applying migrations to set up initial production data

-- =============================================================================
-- PRODUCTION DATABASE INITIALIZATION
-- =============================================================================

BEGIN;

-- Create performance indexes for production
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sr_reviews_next_review_optimized 
ON sr_reviews(user_id, next_review_date) 
WHERE next_review_date <= NOW() + INTERVAL '1 day';

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_lessons_teacher_created 
ON lessons(teacher_id, created_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_lesson_participants_student_lesson 
ON lesson_participants(student_id, lesson_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ai_processing_jobs_status 
ON ai_processing_jobs(status, created_at);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_content_flags_status 
ON content_flags(status, created_at);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_profiles_role_created 
ON profiles(role, created_at);

-- Update table statistics
ANALYZE;

-- =============================================================================
-- PRODUCTION CONFIGURATION SETTINGS
-- =============================================================================

-- Create application settings table if not exists
CREATE TABLE IF NOT EXISTS app_settings (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS on app_settings
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;

-- Create policy for app_settings (admin only)
CREATE POLICY "Admin can manage app settings" ON app_settings
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE profiles.id = auth.uid() 
            AND profiles.role = 'admin'
        )
    );

-- Insert default application settings
INSERT INTO app_settings (key, value) VALUES
('platform_name', '"Light Bus E-Learning Platform"'),
('platform_description', '"AI-powered spaced repetition learning platform"'),
('registration_enabled', 'true'),
('max_file_size_mb', '50'),
('supported_file_types', '["mp3", "mp4", "wav", "pdf", "txt"]'),
('ai_processing_enabled', 'true'),
('content_moderation_enabled', 'true'),
('email_notifications_enabled', 'true'),
('maintenance_mode', 'false'),
('max_lessons_per_teacher', '100'),
('max_cards_per_lesson', '1000'),
('session_timeout_minutes', '480')
ON CONFLICT (key) DO NOTHING;

-- =============================================================================
-- ADMIN USER SETUP FUNCTION
-- =============================================================================

-- Function to create admin user (to be called after user registration)
CREATE OR REPLACE FUNCTION setup_admin_user(admin_email TEXT)
RETURNS TEXT AS $$
DECLARE
    admin_user_id UUID;
BEGIN
    -- Find user by email
    SELECT id INTO admin_user_id 
    FROM auth.users 
    WHERE email = admin_email;
    
    IF admin_user_id IS NULL THEN
        RETURN 'User not found with email: ' || admin_email;
    END IF;
    
    -- Update user role to admin
    INSERT INTO profiles (id, email, role, full_name, created_at)
    VALUES (admin_user_id, admin_email, 'admin', 'Platform Administrator', NOW())
    ON CONFLICT (id) 
    DO UPDATE SET 
        role = 'admin',
        updated_at = NOW();
    
    RETURN 'Successfully set up admin user: ' || admin_email;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- WELCOME CONTENT SETUP
-- =============================================================================

-- Function to create welcome lesson
CREATE OR REPLACE FUNCTION create_welcome_content()
RETURNS TEXT AS $$
DECLARE
    admin_user_id UUID;
    welcome_lesson_id UUID;
BEGIN
    -- Find admin user
    SELECT id INTO admin_user_id 
    FROM profiles 
    WHERE role = 'admin' 
    LIMIT 1;
    
    IF admin_user_id IS NULL THEN
        RETURN 'No admin user found. Please set up admin user first.';
    END IF;
    
    -- Create welcome lesson
    INSERT INTO lessons (
        title,
        description,
        content,
        teacher_id,
        status,
        created_at
    ) VALUES (
        'Welcome to Light Bus E-Learning Platform',
        'Get started with your AI-powered learning journey',
        'Welcome to the Light Bus E-Learning Platform! This platform uses AI to help you learn more effectively through spaced repetition. Here''s how to get started:

1. **For Teachers**: Create lessons, upload content, and let our AI generate flashcards automatically
2. **For Students**: Study lessons, review flashcards, and track your progress
3. **AI Features**: Automatic transcription, content analysis, and intelligent flashcard generation

Start by exploring the platform and creating your first lesson!',
        admin_user_id,
        'published',
        NOW()
    ) RETURNING id INTO welcome_lesson_id;
    
    -- Create sample flashcards for welcome lesson
    INSERT INTO sr_cards (
        lesson_id,
        front,
        back,
        card_type,
        created_at
    ) VALUES 
    (
        welcome_lesson_id,
        'What is spaced repetition?',
        'A learning technique that involves reviewing information at increasing intervals to improve long-term retention.',
        'text',
        NOW()
    ),
    (
        welcome_lesson_id,
        'How does AI help in learning?',
        'AI can automatically transcribe audio content, analyze text for key concepts, and generate relevant flashcards to optimize your study sessions.',
        'text',
        NOW()
    ),
    (
        welcome_lesson_id,
        'What file types are supported?',
        'The platform supports MP3, MP4, WAV audio files, as well as PDF and TXT documents for content processing.',
        'text',
        NOW()
    );
    
    RETURN 'Successfully created welcome content with lesson ID: ' || welcome_lesson_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- DATABASE MAINTENANCE FUNCTIONS
-- =============================================================================

-- Function to clean up old processing jobs
CREATE OR REPLACE FUNCTION cleanup_old_processing_jobs()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM ai_processing_jobs 
    WHERE created_at < NOW() - INTERVAL '30 days' 
    AND status IN ('completed', 'failed');
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Function to update database statistics
CREATE OR REPLACE FUNCTION update_database_stats()
RETURNS TEXT AS $$
BEGIN
    ANALYZE;
    RETURN 'Database statistics updated at ' || NOW();
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- MONITORING AND HEALTH CHECK FUNCTIONS
-- =============================================================================

-- Function to check database health
CREATE OR REPLACE FUNCTION check_database_health()
RETURNS JSONB AS $$
DECLARE
    result JSONB;
    table_counts JSONB;
    index_health JSONB;
BEGIN
    -- Get table counts
    SELECT jsonb_object_agg(table_name, row_count) INTO table_counts
    FROM (
        SELECT 'profiles' as table_name, COUNT(*) as row_count FROM profiles
        UNION ALL
        SELECT 'lessons', COUNT(*) FROM lessons
        UNION ALL
        SELECT 'sr_cards', COUNT(*) FROM sr_cards
        UNION ALL
        SELECT 'sr_reviews', COUNT(*) FROM sr_reviews
        UNION ALL
        SELECT 'ai_processing_jobs', COUNT(*) FROM ai_processing_jobs
    ) counts;
    
    -- Check index usage
    SELECT jsonb_object_agg(indexname, idx_scan) INTO index_health
    FROM pg_stat_user_indexes 
    WHERE schemaname = 'public'
    AND idx_scan > 0
    LIMIT 10;
    
    -- Build result
    result := jsonb_build_object(
        'timestamp', NOW(),
        'status', 'healthy',
        'table_counts', table_counts,
        'top_indexes', index_health,
        'database_size', pg_size_pretty(pg_database_size(current_database()))
    );
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- PRODUCTION SECURITY SETTINGS
-- =============================================================================

-- Ensure all tables have RLS enabled
DO $$
DECLARE
    tbl RECORD;
BEGIN
    FOR tbl IN 
        SELECT tablename 
        FROM pg_tables 
        WHERE schemaname = 'public' 
        AND tablename NOT IN ('app_settings')
    LOOP
        EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', tbl.tablename);
    END LOOP;
END $$;

-- Create function to verify RLS policies
CREATE OR REPLACE FUNCTION verify_rls_policies()
RETURNS TABLE(table_name TEXT, has_rls BOOLEAN, policy_count BIGINT) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.tablename::TEXT,
        t.rowsecurity,
        COUNT(p.policyname)
    FROM pg_tables t
    LEFT JOIN pg_policies p ON p.tablename = t.tablename
    WHERE t.schemaname = 'public'
    GROUP BY t.tablename, t.rowsecurity
    ORDER BY t.tablename;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- PRODUCTION READY NOTIFICATIONS
-- =============================================================================

-- Log successful production setup
INSERT INTO ai_processing_jobs (
    lesson_id,
    job_type,
    status,
    result,
    created_at
) VALUES (
    NULL,
    'system_setup',
    'completed',
    '{"message": "Production database setup completed successfully", "timestamp": "' || NOW() || '"}',
    NOW()
);

COMMIT;

-- =============================================================================
-- POST-SETUP VERIFICATION QUERIES
-- =============================================================================

-- Verify indexes were created
SELECT schemaname, tablename, indexname, indexdef
FROM pg_indexes 
WHERE schemaname = 'public' 
AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;

-- Verify RLS is enabled
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
ORDER BY tablename;

-- Check app settings
SELECT key, value 
FROM app_settings 
ORDER BY key;

-- Display setup completion message
SELECT 
    'Production database setup completed successfully!' as message,
    NOW() as completed_at,
    current_database() as database_name,
    current_user as setup_user;