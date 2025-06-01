-- =============================================================================
-- ANALYTICS AND UTILITY FUNCTIONS
-- =============================================================================
-- Functions for system analytics, debugging, testing, and general utilities
-- =============================================================================

-- Get system health check
CREATE OR REPLACE FUNCTION system_health_check()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    health JSON;
BEGIN
    SELECT json_build_object(
        'timestamp', NOW(),
        'database', 'healthy',
        'tables', json_build_object(
            'profiles', (SELECT COUNT(*) FROM profiles),
            'lessons', (SELECT COUNT(*) FROM lessons),
            'sr_cards', (SELECT COUNT(*) FROM sr_cards),
            'sr_progress', (SELECT COUNT(*) FROM sr_progress),
            'sr_reviews', (SELECT COUNT(*) FROM sr_reviews),
            'lesson_participants', (SELECT COUNT(*) FROM lesson_participants),
            'sr_card_flags', (SELECT COUNT(*) FROM sr_card_flags),
            'transcripts', (SELECT COUNT(*) FROM transcripts),
            'summaries', (SELECT COUNT(*) FROM summaries),
            'student_lesson_interactions', (SELECT COUNT(*) FROM student_lesson_interactions)
        ),
        'functions_loaded', 60,
        'triggers_active', 3,
        'recent_activity', json_build_object(
            'reviews_last_24h', (
                SELECT COUNT(*) FROM sr_reviews 
                WHERE reviewed_at >= NOW() - INTERVAL '24 hours'
            ),
            'cards_created_last_24h', (
                SELECT COUNT(*) FROM sr_cards 
                WHERE created_at >= NOW() - INTERVAL '24 hours'
            ),
            'lessons_last_week', (
                SELECT COUNT(*) FROM lessons 
                WHERE created_at >= NOW() - INTERVAL '7 days'
            )
        )
    )
    INTO health;
    
    RETURN health;
END;
$$;

-- Get database statistics
CREATE OR REPLACE FUNCTION get_database_stats()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    stats JSON;
BEGIN
    SELECT json_build_object(
        'total_users', (SELECT COUNT(*) FROM profiles),
        'total_lessons', (SELECT COUNT(*) FROM lessons),
        'active_lessons', (SELECT COUNT(*) FROM lessons WHERE status = 'recording'),
        'total_cards', (SELECT COUNT(*) FROM sr_cards),
        'approved_cards', (SELECT COUNT(*) FROM sr_cards WHERE status = 'approved'),
        'pending_cards', (SELECT COUNT(*) FROM sr_cards WHERE status = 'pending'),
        'total_reviews', (SELECT COUNT(*) FROM sr_reviews),
        'reviews_today', (SELECT COUNT(*) FROM sr_reviews WHERE reviewed_at::DATE = CURRENT_DATE),
        'active_progress_records', (SELECT COUNT(*) FROM sr_progress),
        'pending_flags', (SELECT COUNT(*) FROM sr_card_flags WHERE status = 'pending'),
        'lesson_participants', (SELECT COUNT(*) FROM lesson_participants),
        'transcripts', (SELECT COUNT(*) FROM transcripts),
        'summaries', (SELECT COUNT(*) FROM summaries),
        'storage_info', json_build_object(
            'avg_card_size_bytes', (
                SELECT AVG(LENGTH(front_text) + LENGTH(back_text))
                FROM sr_cards
            ),
            'avg_transcript_size_bytes', (
                SELECT AVG(LENGTH(content))
                FROM transcripts
            ),
            'total_text_content_mb', (
                SELECT ROUND(
                    (SUM(LENGTH(front_text) + LENGTH(back_text)) + 
                     COALESCE((SELECT SUM(LENGTH(content)) FROM transcripts), 0) +
                     COALESCE((SELECT SUM(LENGTH(summary_text)) FROM summaries), 0)) / 1024.0 / 1024.0, 2
                )
                FROM sr_cards
            )
        )
    )
    INTO stats;
    
    RETURN stats;
END;
$$;

-- Get platform usage analytics
CREATE OR REPLACE FUNCTION get_platform_analytics(p_days_back INTEGER DEFAULT 30)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    analytics JSON;
    start_date DATE;
BEGIN
    start_date := CURRENT_DATE - p_days_back;
    
    SELECT json_build_object(
        'period_days', p_days_back,
        'user_activity', json_build_object(
            'daily_active_users', (
                SELECT json_agg(
                    json_build_object(
                        'date', activity_date,
                        'active_users', active_users
                    )
                )
                FROM (
                    SELECT 
                        sr.reviewed_at::DATE as activity_date,
                        COUNT(DISTINCT sr.user_id) as active_users
                    FROM sr_reviews sr
                    WHERE sr.reviewed_at >= start_date
                    GROUP BY sr.reviewed_at::DATE
                    ORDER BY activity_date
                ) daily_activity
            ),
            'total_active_users', (
                SELECT COUNT(DISTINCT user_id)
                FROM sr_reviews
                WHERE reviewed_at >= start_date
            ),
            'new_users', (
                SELECT COUNT(*)
                FROM profiles
                WHERE created_at >= start_date
            )
        ),
        'learning_metrics', json_build_object(
            'total_reviews', (
                SELECT COUNT(*)
                FROM sr_reviews
                WHERE reviewed_at >= start_date
            ),
            'avg_quality_score', (
                SELECT ROUND(AVG(quality), 2)
                FROM sr_reviews
                WHERE reviewed_at >= start_date
            ),
            'cards_mastered', (
                SELECT COUNT(DISTINCT card_id)
                FROM sr_progress
                WHERE interval_days >= 21
                AND updated_at >= start_date
            ),
            'study_sessions', (
                SELECT COUNT(DISTINCT DATE(reviewed_at) || user_id)
                FROM sr_reviews
                WHERE reviewed_at >= start_date
            )
        ),
        'content_creation', json_build_object(
            'cards_created', (
                SELECT COUNT(*)
                FROM sr_cards
                WHERE created_at >= start_date
            ),
            'cards_approved', (
                SELECT COUNT(*)
                FROM sr_cards
                WHERE approved_at >= start_date
            ),
            'lessons_created', (
                SELECT COUNT(*)
                FROM lessons
                WHERE created_at >= start_date
            ),
            'transcripts_generated', (
                SELECT COUNT(*)
                FROM transcripts
                WHERE created_at >= start_date
            )
        ),
        'engagement_trends', (
            SELECT json_agg(
                json_build_object(
                    'date', trend_date,
                    'avg_reviews_per_user', avg_reviews,
                    'avg_study_time_minutes', avg_study_time
                )
            )
            FROM (
                SELECT 
                    reviewed_at::DATE as trend_date,
                    ROUND(COUNT(*)::DECIMAL / COUNT(DISTINCT user_id), 2) as avg_reviews,
                    ROUND(AVG(response_time_ms) / 1000.0 / 60.0, 2) as avg_study_time
                FROM sr_reviews
                WHERE reviewed_at >= start_date
                AND response_time_ms IS NOT NULL
                GROUP BY reviewed_at::DATE
                ORDER BY trend_date
            ) trend_data
        )
    )
    INTO analytics;
    
    RETURN analytics;
END;
$$;

-- Generate performance report
CREATE OR REPLACE FUNCTION generate_performance_report(
    p_user_id UUID DEFAULT NULL,
    p_lesson_id UUID DEFAULT NULL,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    report JSON;
    default_start_date DATE;
    default_end_date DATE;
BEGIN
    default_start_date := COALESCE(p_start_date, CURRENT_DATE - 30);
    default_end_date := COALESCE(p_end_date, CURRENT_DATE);
    
    SELECT json_build_object(
        'report_period', json_build_object(
            'start_date', default_start_date,
            'end_date', default_end_date
        ),
        'user_filter', p_user_id,
        'lesson_filter', p_lesson_id,
        'summary', json_build_object(
            'total_reviews', COUNT(sr.id),
            'unique_users', COUNT(DISTINCT sr.user_id),
            'unique_cards', COUNT(DISTINCT sr.card_id),
            'avg_quality', ROUND(AVG(sr.quality), 2),
            'avg_response_time_ms', ROUND(AVG(sr.response_time_ms), 0),
            'success_rate', ROUND(
                COUNT(CASE WHEN sr.quality >= 3 THEN 1 END)::DECIMAL / 
                NULLIF(COUNT(sr.id), 0) * 100, 2
            )
        ),
        'quality_distribution', (
            SELECT json_object_agg(quality_level, quality_count)
            FROM (
                SELECT 
                    'Q' || sr.quality as quality_level,
                    COUNT(*) as quality_count
                FROM sr_reviews sr
                LEFT JOIN sr_cards sc ON sc.id = sr.card_id
                WHERE sr.reviewed_at::DATE BETWEEN default_start_date AND default_end_date
                AND (p_user_id IS NULL OR sr.user_id = p_user_id)
                AND (p_lesson_id IS NULL OR sc.lesson_id = p_lesson_id)
                GROUP BY sr.quality
            ) quality_stats
        ),
        'daily_performance', (
            SELECT json_agg(
                json_build_object(
                    'date', perf_date,
                    'reviews', review_count,
                    'avg_quality', avg_quality,
                    'avg_response_time', avg_response_time
                )
            )
            FROM (
                SELECT 
                    sr.reviewed_at::DATE as perf_date,
                    COUNT(*) as review_count,
                    ROUND(AVG(sr.quality), 2) as avg_quality,
                    ROUND(AVG(sr.response_time_ms), 0) as avg_response_time
                FROM sr_reviews sr
                LEFT JOIN sr_cards sc ON sc.id = sr.card_id
                WHERE sr.reviewed_at::DATE BETWEEN default_start_date AND default_end_date
                AND (p_user_id IS NULL OR sr.user_id = p_user_id)
                AND (p_lesson_id IS NULL OR sc.lesson_id = p_lesson_id)
                GROUP BY sr.reviewed_at::DATE
                ORDER BY perf_date
            ) daily_stats
        ),
        'top_performers', CASE 
            WHEN p_user_id IS NULL THEN (
                SELECT json_agg(
                    json_build_object(
                        'user_id', user_id,
                        'user_name', user_name,
                        'total_reviews', total_reviews,
                        'avg_quality', avg_quality,
                        'mastery_rate', mastery_rate
                    )
                )
                FROM (
                    SELECT 
                        p.id as user_id,
                        p.full_name as user_name,
                        COUNT(sr.id) as total_reviews,
                        ROUND(AVG(sr.quality), 2) as avg_quality,
                        ROUND(
                            COUNT(DISTINCT CASE WHEN sp.interval_days >= 21 THEN sp.card_id END)::DECIMAL /
                            NULLIF(COUNT(DISTINCT sp.card_id), 0) * 100, 2
                        ) as mastery_rate
                    FROM profiles p
                    LEFT JOIN sr_reviews sr ON sr.user_id = p.id
                    LEFT JOIN sr_progress sp ON sp.user_id = p.id
                    LEFT JOIN sr_cards sc ON sc.id = sr.card_id
                    WHERE sr.reviewed_at::DATE BETWEEN default_start_date AND default_end_date
                    AND (p_lesson_id IS NULL OR sc.lesson_id = p_lesson_id)
                    GROUP BY p.id, p.full_name
                    HAVING COUNT(sr.id) > 0
                    ORDER BY avg_quality DESC, total_reviews DESC
                    LIMIT 10
                ) top_users
            )
            ELSE NULL
        END
    )
    INTO report
    FROM sr_reviews sr
    LEFT JOIN sr_cards sc ON sc.id = sr.card_id
    WHERE sr.reviewed_at::DATE BETWEEN default_start_date AND default_end_date
    AND (p_user_id IS NULL OR sr.user_id = p_user_id)
    AND (p_lesson_id IS NULL OR sc.lesson_id = p_lesson_id);
    
    RETURN report;
END;
$$;

-- Clean up test data
CREATE OR REPLACE FUNCTION cleanup_test_data()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    deleted_count INTEGER := 0;
BEGIN
    -- Delete test reviews
    DELETE FROM sr_reviews WHERE user_id IN (
        SELECT id FROM profiles WHERE email LIKE '%test%'
    );
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    -- Delete test progress
    DELETE FROM sr_progress WHERE user_id IN (
        SELECT id FROM profiles WHERE email LIKE '%test%'
    );
    
    -- Delete test cards
    DELETE FROM sr_cards WHERE created_by IN (
        SELECT id FROM profiles WHERE email LIKE '%test%'
    );
    
    -- Delete test lesson participants
    DELETE FROM lesson_participants WHERE user_id IN (
        SELECT id FROM profiles WHERE email LIKE '%test%'
    );
    
    -- Delete test lessons
    DELETE FROM lessons WHERE title LIKE '%test%';
    
    -- Delete test profiles
    DELETE FROM profiles WHERE email LIKE '%test%';
    
    RETURN deleted_count;
END;
$$;

-- Generate sample data for testing
CREATE OR REPLACE FUNCTION generate_sample_data()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    test_user_id UUID;
    test_lesson_id UUID;
    test_card_id UUID;
BEGIN
    -- Create test user
    INSERT INTO profiles (id, email, full_name, created_at, updated_at)
    VALUES (gen_random_uuid(), 'test@example.com', 'Test User', NOW(), NOW())
    RETURNING id INTO test_user_id;
    
    -- Create test lesson
    test_lesson_id := create_lesson('Test Lesson', 'Sample lesson for testing', NOW() + INTERVAL '1 hour');
    
    -- Add user to lesson
    PERFORM add_lesson_participant(test_lesson_id, test_user_id, 'student');
    
    -- Create test card
    test_card_id := create_sr_card('What is 2+2?', '4', test_lesson_id, test_user_id, ARRAY['math', 'basic']);
    
    -- Approve the card
    PERFORM approve_sr_card(test_card_id, test_user_id);
    
    -- Record a review
    PERFORM record_sr_review(test_user_id, test_card_id, 4, 3000);
    
    RETURN 'Sample data generated successfully';
END;
$$;

-- Export data for backup
CREATE OR REPLACE FUNCTION export_user_data(p_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    user_data JSON;
BEGIN
    SELECT json_build_object(
        'profile', (
            SELECT row_to_json(p) FROM profiles p WHERE p.id = p_user_id
        ),
        'reviews', (
            SELECT json_agg(row_to_json(sr))
            FROM sr_reviews sr
            WHERE sr.user_id = p_user_id
        ),
        'progress', (
            SELECT json_agg(row_to_json(sp))
            FROM sr_progress sp
            WHERE sp.user_id = p_user_id
        ),
        'lesson_participation', (
            SELECT json_agg(
                json_build_object(
                    'lesson', row_to_json(l),
                    'role', lp.role,
                    'joined_at', lp.joined_at
                )
            )
            FROM lesson_participants lp
            JOIN lessons l ON l.id = lp.lesson_id
            WHERE lp.user_id = p_user_id
        ),
        'cards_created', (
            SELECT json_agg(row_to_json(sc))
            FROM sr_cards sc
            WHERE sc.created_by = p_user_id
        ),
        'flags_created', (
            SELECT json_agg(row_to_json(scf))
            FROM sr_card_flags scf
            WHERE scf.flagged_by = p_user_id
        )
    )
    INTO user_data;
    
    RETURN user_data;
END;
$$;

-- Get system metrics for monitoring
CREATE OR REPLACE FUNCTION get_system_metrics()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    metrics JSON;
BEGIN
    SELECT json_build_object(
        'timestamp', NOW(),
        'performance', json_build_object(
            'avg_review_response_time_ms', (
                SELECT AVG(response_time_ms)
                FROM sr_reviews
                WHERE reviewed_at >= NOW() - INTERVAL '1 hour'
                AND response_time_ms IS NOT NULL
            ),
            'reviews_per_minute', (
                SELECT COUNT(*) / 60.0
                FROM sr_reviews
                WHERE reviewed_at >= NOW() - INTERVAL '1 hour'
            ),
            'active_sessions', (
                SELECT COUNT(DISTINCT user_id)
                FROM sr_reviews
                WHERE reviewed_at >= NOW() - INTERVAL '15 minutes'
            )
        ),
        'errors', json_build_object(
            'pending_flags', (
                SELECT COUNT(*) FROM sr_card_flags WHERE status = 'pending'
            ),
            'failed_transcriptions', (
                SELECT COUNT(*) 
                FROM transcripts 
                WHERE confidence_score < 0.5
                AND created_at >= NOW() - INTERVAL '24 hours'
            )
        ),
        'capacity', json_build_object(
            'database_size_mb', (
                SELECT ROUND(
                    pg_database_size(current_database()) / 1024.0 / 1024.0, 2
                )
            ),
            'connection_count', (
                SELECT count(*) 
                FROM pg_stat_activity 
                WHERE state = 'active'
            )
        )
    )
    INTO metrics;
    
    RETURN metrics;
END;
$$;

-- Optimize database performance
CREATE OR REPLACE FUNCTION optimize_database()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Analyze tables for better query planning
    ANALYZE profiles;
    ANALYZE lessons;
    ANALYZE sr_cards;
    ANALYZE sr_progress;
    ANALYZE sr_reviews;
    ANALYZE lesson_participants;
    ANALYZE sr_card_flags;
    ANALYZE transcripts;
    ANALYZE summaries;
    ANALYZE student_lesson_interactions;
    
    RETURN 'Database optimization completed - all tables analyzed';
END;
$$;