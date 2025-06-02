-- Phase 4: Moderation, Realtime Features & Admin Console Migration
-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================
-- CONTENT MODERATION SYSTEM
-- =============================================

-- Content flags table for user-reported issues
CREATE TABLE IF NOT EXISTS public.content_flags (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    content_type TEXT NOT NULL CHECK (content_type IN ('lesson', 'card', 'comment', 'transcript', 'user_profile')),
    content_id UUID NOT NULL,
    reporter_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    flag_category TEXT NOT NULL CHECK (flag_category IN ('inappropriate', 'incorrect', 'spam', 'offensive', 'copyright', 'misleading', 'other')),
    flag_reason TEXT NOT NULL,
    evidence_text TEXT,
    evidence_screenshots TEXT[], -- URLs to uploaded screenshots
    severity_level INTEGER DEFAULT 1 CHECK (severity_level BETWEEN 1 AND 5),
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'under_review', 'resolved', 'dismissed')),
    anonymous_report BOOLEAN DEFAULT FALSE,
    resolved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    resolved_at TIMESTAMPTZ,
    resolution_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Moderation queue table for pending reviews
CREATE TABLE IF NOT EXISTS public.moderation_queue (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    content_flag_id UUID REFERENCES public.content_flags(id) ON DELETE CASCADE NOT NULL,
    content_type TEXT NOT NULL,
    content_id UUID NOT NULL,
    priority_score INTEGER DEFAULT 1 CHECK (priority_score BETWEEN 1 AND 100),
    assigned_moderator_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'escalated')),
    review_deadline TIMESTAMPTZ,
    escalation_level INTEGER DEFAULT 0 CHECK (escalation_level BETWEEN 0 AND 3),
    context_data JSONB, -- Additional context for the moderator
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Moderation actions table for audit trail
CREATE TABLE IF NOT EXISTS public.moderation_actions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    queue_item_id UUID REFERENCES public.moderation_queue(id) ON DELETE CASCADE NOT NULL,
    moderator_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    action_type TEXT NOT NULL CHECK (action_type IN ('approve', 'reject', 'remove', 'warn_user', 'ban_user', 'edit_content', 'escalate')),
    action_reason TEXT NOT NULL,
    previous_content JSONB, -- Store original content before modification
    new_content JSONB, -- Store new content after modification
    user_notified BOOLEAN DEFAULT FALSE,
    notification_sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- User violations table for tracking user behavior
CREATE TABLE IF NOT EXISTS public.user_violations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    violation_type TEXT NOT NULL CHECK (violation_type IN ('content_violation', 'spam', 'harassment', 'impersonation', 'copyright', 'multiple_accounts')),
    severity TEXT NOT NULL CHECK (severity IN ('minor', 'moderate', 'major', 'severe')),
    description TEXT NOT NULL,
    moderation_action_id UUID REFERENCES public.moderation_actions(id) ON DELETE SET NULL,
    points_assigned INTEGER DEFAULT 0, -- Violation point system
    expires_at TIMESTAMPTZ, -- When violation expires from record
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Automated moderation table for AI-based content filtering
CREATE TABLE IF NOT EXISTS public.automated_moderation (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    content_type TEXT NOT NULL,
    content_id UUID NOT NULL,
    content_text TEXT NOT NULL,
    ai_service_provider TEXT CHECK (ai_service_provider IN ('openai', 'azure_ai', 'google_ai', 'custom')),
    moderation_result JSONB NOT NULL, -- AI service response
    confidence_score DECIMAL(3,2) CHECK (confidence_score BETWEEN 0.0 AND 1.0),
    flags_detected TEXT[], -- Array of detected issues
    action_taken TEXT CHECK (action_taken IN ('none', 'flagged', 'blocked', 'requires_review')),
    human_review_required BOOLEAN DEFAULT FALSE,
    reviewed_by_human BOOLEAN DEFAULT FALSE,
    human_reviewer_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    human_review_at TIMESTAMPTZ,
    human_review_result TEXT CHECK (human_review_result IN ('confirmed', 'overruled', 'modified')),
    processing_time_ms INTEGER,
    cost_cents INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- REALTIME COLLABORATIVE FEATURES
-- =============================================

-- Study rooms table for live collaborative sessions
CREATE TABLE IF NOT EXISTS public.study_rooms (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    host_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    lesson_id UUID REFERENCES public.lessons(id) ON DELETE CASCADE,
    room_code TEXT UNIQUE NOT NULL, -- 6-digit join code
    max_participants INTEGER DEFAULT 10 CHECK (max_participants BETWEEN 2 AND 50),
    current_participants INTEGER DEFAULT 0,
    is_public BOOLEAN DEFAULT FALSE,
    requires_approval BOOLEAN DEFAULT FALSE,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'paused', 'ended', 'archived')),
    session_config JSONB DEFAULT '{}', -- Room settings
    started_at TIMESTAMPTZ DEFAULT NOW(),
    ended_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Study room participants table
CREATE TABLE IF NOT EXISTS public.study_room_participants (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    room_id UUID REFERENCES public.study_rooms(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    role TEXT DEFAULT 'participant' CHECK (role IN ('host', 'moderator', 'participant')),
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    left_at TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT TRUE,
    progress_sync JSONB DEFAULT '{}', -- Current study progress
    last_seen TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(room_id, user_id)
);

-- Study room events table for realtime synchronization
CREATE TABLE IF NOT EXISTS public.study_room_events (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    room_id UUID REFERENCES public.study_rooms(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL CHECK (event_type IN ('card_flip', 'card_answer', 'chat_message', 'progress_sync', 'user_join', 'user_leave', 'session_pause', 'session_resume')),
    event_data JSONB NOT NULL,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    processed BOOLEAN DEFAULT FALSE
);

-- Realtime notifications table
CREATE TABLE IF NOT EXISTS public.realtime_notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    notification_type TEXT NOT NULL CHECK (notification_type IN ('study_invitation', 'lesson_update', 'card_approved', 'achievement_unlocked', 'reminder', 'system_alert')),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    data JSONB DEFAULT '{}', -- Additional notification data
    priority TEXT DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    read_at TIMESTAMPTZ,
    dismissed_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    delivery_method TEXT[] DEFAULT ARRAY['in_app'], -- 'in_app', 'email', 'push'
    sent_via TEXT[] DEFAULT ARRAY[]::TEXT[], -- Track which methods were used
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Live class monitoring table
CREATE TABLE IF NOT EXISTS public.live_class_sessions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    lesson_id UUID REFERENCES public.lessons(id) ON DELETE CASCADE NOT NULL,
    teacher_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    session_name TEXT NOT NULL,
    status TEXT DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'live', 'paused', 'ended')),
    started_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    recording_enabled BOOLEAN DEFAULT FALSE,
    recording_url TEXT,
    max_students INTEGER DEFAULT 30,
    current_students INTEGER DEFAULT 0,
    session_config JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Live class participants table
CREATE TABLE IF NOT EXISTS public.live_class_participants (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    session_id UUID REFERENCES public.live_class_sessions(id) ON DELETE CASCADE NOT NULL,
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    left_at TIMESTAMPTZ,
    engagement_score DECIMAL(3,2) DEFAULT 0.0,
    questions_asked INTEGER DEFAULT 0,
    cards_completed INTEGER DEFAULT 0,
    attention_duration_minutes INTEGER DEFAULT 0,
    last_activity TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(session_id, student_id)
);

-- =============================================
-- ADVANCED ADMIN CONSOLE
-- =============================================

-- System health metrics table
CREATE TABLE IF NOT EXISTS public.system_health_metrics (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    metric_type TEXT NOT NULL CHECK (metric_type IN ('cpu_usage', 'memory_usage', 'database_performance', 'api_response_time', 'error_rate', 'active_users', 'storage_usage')),
    metric_value DECIMAL(10,4) NOT NULL,
    metric_unit TEXT,
    threshold_warning DECIMAL(10,4),
    threshold_critical DECIMAL(10,4),
    status TEXT DEFAULT 'normal' CHECK (status IN ('normal', 'warning', 'critical')),
    additional_data JSONB,
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

-- Security audit logs table
CREATE TABLE IF NOT EXISTS public.security_audit_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    event_type TEXT NOT NULL CHECK (event_type IN ('login_attempt', 'failed_login', 'privilege_escalation', 'data_access', 'data_modification', 'account_creation', 'password_change', 'suspicious_activity')),
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    ip_address INET,
    user_agent TEXT,
    resource_accessed TEXT,
    action_performed TEXT,
    success BOOLEAN NOT NULL,
    risk_score INTEGER DEFAULT 0 CHECK (risk_score BETWEEN 0 AND 100),
    geolocation JSONB, -- Country, city, etc.
    session_id TEXT,
    additional_context JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Platform analytics table
CREATE TABLE IF NOT EXISTS public.platform_analytics (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    metric_name TEXT NOT NULL,
    metric_category TEXT NOT NULL CHECK (metric_category IN ('user_engagement', 'learning_outcomes', 'content_performance', 'system_usage', 'financial')),
    time_period TEXT NOT NULL CHECK (time_period IN ('hourly', 'daily', 'weekly', 'monthly')),
    period_start TIMESTAMPTZ NOT NULL,
    period_end TIMESTAMPTZ NOT NULL,
    metric_value DECIMAL(15,4) NOT NULL,
    metric_unit TEXT,
    dimensions JSONB, -- Additional breakdown dimensions
    calculated_at TIMESTAMPTZ DEFAULT NOW()
);

-- User session tracking table
CREATE TABLE IF NOT EXISTS public.user_sessions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    session_token TEXT UNIQUE NOT NULL,
    ip_address INET,
    user_agent TEXT,
    device_info JSONB,
    location_data JSONB,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    last_activity TIMESTAMPTZ DEFAULT NOW(),
    ended_at TIMESTAMPTZ,
    duration_minutes INTEGER,
    pages_visited INTEGER DEFAULT 0,
    actions_performed INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE
);

-- =============================================
-- ENABLE ROW LEVEL SECURITY
-- =============================================

ALTER TABLE public.content_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.moderation_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.moderation_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_violations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.automated_moderation ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_room_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_room_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.realtime_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_class_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_class_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_health_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.security_audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.platform_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_sessions ENABLE ROW LEVEL SECURITY;

-- =============================================
-- RLS POLICIES
-- =============================================

-- Content flags policies
CREATE POLICY "Users can create content flags" ON public.content_flags
    FOR INSERT WITH CHECK (reporter_id = auth.uid());

CREATE POLICY "Users can view their own flags" ON public.content_flags
    FOR SELECT USING (reporter_id = auth.uid() OR EXISTS (
        SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'moderator')
    ));

CREATE POLICY "Moderators and admins can view all flags" ON public.content_flags
    FOR SELECT USING (EXISTS (
        SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'moderator')
    ));

CREATE POLICY "Moderators can update flag status" ON public.moderation_queue
    FOR UPDATE USING (assigned_moderator_id = auth.uid() OR EXISTS (
        SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
    ));

-- Study rooms policies
CREATE POLICY "Users can view public study rooms" ON public.study_rooms
    FOR SELECT USING (is_public = true OR host_id = auth.uid() OR EXISTS (
        SELECT 1 FROM public.study_room_participants 
        WHERE room_id = id AND user_id = auth.uid()
    ));

CREATE POLICY "Users can create study rooms" ON public.study_rooms
    FOR INSERT WITH CHECK (host_id = auth.uid());

CREATE POLICY "Hosts can update their study rooms" ON public.study_rooms
    FOR UPDATE USING (host_id = auth.uid());

-- Study room participants policies
CREATE POLICY "Users can join study rooms" ON public.study_room_participants
    FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can view participants in their rooms" ON public.study_room_participants
    FOR SELECT USING (user_id = auth.uid() OR EXISTS (
        SELECT 1 FROM public.study_rooms 
        WHERE id = room_id AND (host_id = auth.uid() OR is_public = true)
    ));

-- Notifications policies
CREATE POLICY "Users can view their own notifications" ON public.realtime_notifications
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can update their own notifications" ON public.realtime_notifications
    FOR UPDATE USING (user_id = auth.uid());

-- Admin-only policies
CREATE POLICY "Admins can view system health metrics" ON public.system_health_metrics
    FOR SELECT USING (EXISTS (
        SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
    ));

CREATE POLICY "Admins can view security audit logs" ON public.security_audit_logs
    FOR SELECT USING (EXISTS (
        SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
    ));

CREATE POLICY "Admins can view platform analytics" ON public.platform_analytics
    FOR SELECT USING (EXISTS (
        SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
    ));

-- User sessions policies
CREATE POLICY "Users can view their own sessions" ON public.user_sessions
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Admins can view all sessions" ON public.user_sessions
    FOR SELECT USING (EXISTS (
        SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
    ));

-- =============================================
-- DATABASE FUNCTIONS
-- =============================================

-- Function to flag content
CREATE OR REPLACE FUNCTION public.flag_content(
    p_content_type TEXT,
    p_content_id UUID,
    p_flag_category TEXT,
    p_flag_reason TEXT,
    p_evidence_text TEXT DEFAULT NULL,
    p_anonymous BOOLEAN DEFAULT FALSE
)
RETURNS UUID AS $$
DECLARE
    flag_id UUID;
    queue_id UUID;
    priority_score INTEGER;
BEGIN
    -- Calculate priority score based on category and user history
    priority_score := CASE p_flag_category
        WHEN 'offensive' THEN 90
        WHEN 'inappropriate' THEN 80
        WHEN 'spam' THEN 60
        WHEN 'incorrect' THEN 40
        ELSE 30
    END;
    
    -- Create content flag
    INSERT INTO public.content_flags (
        content_type, content_id, reporter_id, flag_category,
        flag_reason, evidence_text, anonymous_report
    ) VALUES (
        p_content_type, p_content_id, auth.uid(), p_flag_category,
        p_flag_reason, p_evidence_text, p_anonymous
    ) RETURNING id INTO flag_id;
    
    -- Add to moderation queue
    INSERT INTO public.moderation_queue (
        content_flag_id, content_type, content_id, priority_score,
        review_deadline
    ) VALUES (
        flag_id, p_content_type, p_content_id, priority_score,
        NOW() + INTERVAL '24 hours'
    ) RETURNING id INTO queue_id;
    
    RETURN flag_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to process moderation queue
CREATE OR REPLACE FUNCTION public.process_moderation_queue(
    p_queue_id UUID,
    p_action_type TEXT,
    p_action_reason TEXT,
    p_new_content JSONB DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    queue_item RECORD;
    action_id UUID;
BEGIN
    -- Get queue item details
    SELECT * INTO queue_item FROM public.moderation_queue WHERE id = p_queue_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Queue item not found';
    END IF;
    
    -- Record moderation action
    INSERT INTO public.moderation_actions (
        queue_item_id, moderator_id, action_type, action_reason, new_content
    ) VALUES (
        p_queue_id, auth.uid(), p_action_type, p_action_reason, p_new_content
    ) RETURNING id INTO action_id;
    
    -- Update queue status
    UPDATE public.moderation_queue 
    SET status = 'completed', updated_at = NOW()
    WHERE id = p_queue_id;
    
    -- Update original flag
    UPDATE public.content_flags 
    SET status = 'resolved', resolved_by = auth.uid(), resolved_at = NOW()
    WHERE id = queue_item.content_flag_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get moderation statistics
CREATE OR REPLACE FUNCTION public.get_moderation_stats(
    p_date_from DATE DEFAULT CURRENT_DATE - INTERVAL '30 days',
    p_date_to DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    total_flags INTEGER,
    pending_flags INTEGER,
    resolved_flags INTEGER,
    avg_resolution_time_hours DECIMAL,
    top_categories JSONB,
    moderator_performance JSONB
) AS $$
BEGIN
    RETURN QUERY
    WITH flag_stats AS (
        SELECT 
            COUNT(*)::INTEGER as total,
            COUNT(CASE WHEN status = 'pending' THEN 1 END)::INTEGER as pending,
            COUNT(CASE WHEN status = 'resolved' THEN 1 END)::INTEGER as resolved,
            AVG(EXTRACT(EPOCH FROM (resolved_at - created_at))/3600) as avg_hours
        FROM public.content_flags
        WHERE created_at::DATE BETWEEN p_date_from AND p_date_to
    ),
    category_stats AS (
        SELECT jsonb_object_agg(flag_category, cnt) as categories
        FROM (
            SELECT flag_category, COUNT(*) as cnt
            FROM public.content_flags
            WHERE created_at::DATE BETWEEN p_date_from AND p_date_to
            GROUP BY flag_category
            ORDER BY cnt DESC
            LIMIT 5
        ) t
    ),
    moderator_stats AS (
        SELECT jsonb_object_agg(moderator_name, actions_count) as performance
        FROM (
            SELECT 
                COALESCE(p.name, 'Unknown') as moderator_name,
                COUNT(*) as actions_count
            FROM public.moderation_actions ma
            LEFT JOIN public.profiles p ON ma.moderator_id = p.id
            WHERE ma.created_at::DATE BETWEEN p_date_from AND p_date_to
            GROUP BY p.name
            ORDER BY actions_count DESC
            LIMIT 10
        ) t
    )
    SELECT 
        fs.total,
        fs.pending,
        fs.resolved,
        fs.avg_hours,
        cs.categories,
        ms.performance
    FROM flag_stats fs, category_stats cs, moderator_stats ms;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function for automated content moderation
CREATE OR REPLACE FUNCTION public.auto_moderate_content(
    p_content_type TEXT,
    p_content_id UUID,
    p_content_text TEXT,
    p_ai_result JSONB,
    p_confidence_score DECIMAL DEFAULT 0.0
)
RETURNS UUID AS $$
DECLARE
    moderation_id UUID;
    flags_detected TEXT[];
    action_to_take TEXT := 'none';
    requires_human BOOLEAN := FALSE;
BEGIN
    -- Extract flags from AI result
    flags_detected := ARRAY(SELECT jsonb_array_elements_text(p_ai_result->'flags'));
    
    -- Determine action based on confidence and flags
    IF p_confidence_score > 0.9 AND array_length(flags_detected, 1) > 0 THEN
        action_to_take := 'blocked';
        requires_human := TRUE;
    ELSIF p_confidence_score > 0.7 AND array_length(flags_detected, 1) > 0 THEN
        action_to_take := 'flagged';
        requires_human := TRUE;
    ELSIF p_confidence_score > 0.5 AND array_length(flags_detected, 1) > 0 THEN
        action_to_take := 'requires_review';
        requires_human := TRUE;
    END IF;
    
    INSERT INTO public.automated_moderation (
        content_type, content_id, content_text, ai_service_provider,
        moderation_result, confidence_score, flags_detected,
        action_taken, human_review_required
    ) VALUES (
        p_content_type, p_content_id, p_content_text, 'openai',
        p_ai_result, p_confidence_score, flags_detected,
        action_to_take, requires_human
    ) RETURNING id INTO moderation_id;
    
    RETURN moderation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to create study room
CREATE OR REPLACE FUNCTION public.create_study_room(
    p_name TEXT,
    p_description TEXT DEFAULT NULL,
    p_lesson_id UUID DEFAULT NULL,
    p_is_public BOOLEAN DEFAULT FALSE,
    p_max_participants INTEGER DEFAULT 10
)
RETURNS TABLE (
    room_id UUID,
    room_code TEXT
) AS $$
DECLARE
    new_room_id UUID;
    new_room_code TEXT;
BEGIN
    -- Generate unique 6-digit room code
    LOOP
        new_room_code := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
        EXIT WHEN NOT EXISTS (SELECT 1 FROM public.study_rooms WHERE room_code = new_room_code);
    END LOOP;
    
    INSERT INTO public.study_rooms (
        name, description, host_id, lesson_id, room_code,
        max_participants, is_public
    ) VALUES (
        p_name, p_description, auth.uid(), p_lesson_id, new_room_code,
        p_max_participants, p_is_public
    ) RETURNING id INTO new_room_id;
    
    -- Add host as participant
    INSERT INTO public.study_room_participants (
        room_id, user_id, role
    ) VALUES (
        new_room_id, auth.uid(), 'host'
    );
    
    RETURN QUERY SELECT new_room_id, new_room_code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to join study room
CREATE OR REPLACE FUNCTION public.join_study_room(
    p_room_code TEXT
)
RETURNS UUID AS $$
DECLARE
    room_record RECORD;
    participant_id UUID;
BEGIN
    -- Get room details
    SELECT * INTO room_record 
    FROM public.study_rooms 
    WHERE room_code = p_room_code AND status = 'active';
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Room not found or inactive';
    END IF;
    
    -- Check if room is full
    IF room_record.current_participants >= room_record.max_participants THEN
        RAISE EXCEPTION 'Room is full';
    END IF;
    
    -- Add participant
    INSERT INTO public.study_room_participants (
        room_id, user_id, role
    ) VALUES (
        room_record.id, auth.uid(), 'participant'
    ) ON CONFLICT (room_id, user_id) DO UPDATE 
    SET is_active = TRUE, joined_at = NOW()
    RETURNING id INTO participant_id;
    
    -- Update room participant count
    UPDATE public.study_rooms 
    SET current_participants = current_participants + 1
    WHERE id = room_record.id;
    
    RETURN participant_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to broadcast study room event
CREATE OR REPLACE FUNCTION public.broadcast_study_event(
    p_room_id UUID,
    p_event_type TEXT,
    p_event_data JSONB
)
RETURNS UUID AS $$
DECLARE
    event_id UUID;
BEGIN
    INSERT INTO public.study_room_events (
        room_id, user_id, event_type, event_data
    ) VALUES (
        p_room_id, auth.uid(), p_event_type, p_event_data
    ) RETURNING id INTO event_id;
    
    RETURN event_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get system health metrics
CREATE OR REPLACE FUNCTION public.get_system_health()
RETURNS TABLE (
    cpu_usage DECIMAL,
    memory_usage DECIMAL,
    active_connections INTEGER,
    error_rate DECIMAL,
    response_time_ms DECIMAL,
    status TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH latest_metrics AS (
        SELECT DISTINCT ON (metric_type) 
            metric_type, metric_value, status
        FROM public.system_health_metrics
        ORDER BY metric_type, recorded_at DESC
    )
    SELECT 
        COALESCE((SELECT metric_value FROM latest_metrics WHERE metric_type = 'cpu_usage'), 0),
        COALESCE((SELECT metric_value FROM latest_metrics WHERE metric_type = 'memory_usage'), 0),
        (SELECT COUNT(*)::INTEGER FROM public.user_sessions WHERE is_active = TRUE),
        COALESCE((SELECT metric_value FROM latest_metrics WHERE metric_type = 'error_rate'), 0),
        COALESCE((SELECT metric_value FROM latest_metrics WHERE metric_type = 'api_response_time'), 0),
        CASE 
            WHEN EXISTS (SELECT 1 FROM latest_metrics WHERE status = 'critical') THEN 'critical'
            WHEN EXISTS (SELECT 1 FROM latest_metrics WHERE status = 'warning') THEN 'warning'
            ELSE 'normal'
        END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user analytics
CREATE OR REPLACE FUNCTION public.get_user_analytics(
    p_date_from DATE DEFAULT CURRENT_DATE - INTERVAL '30 days',
    p_date_to DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    total_users INTEGER,
    active_users INTEGER,
    new_users INTEGER,
    user_retention_rate DECIMAL,
    avg_session_duration DECIMAL,
    top_user_activities JSONB
) AS $$
BEGIN
    RETURN QUERY
    WITH user_stats AS (
        SELECT 
            COUNT(*)::INTEGER as total,
            COUNT(CASE WHEN last_sign_in_at::DATE >= CURRENT_DATE - INTERVAL '7 days' THEN 1 END)::INTEGER as active,
            COUNT(CASE WHEN created_at::DATE BETWEEN p_date_from AND p_date_to THEN 1 END)::INTEGER as new_users
        FROM auth.users
    ),
    session_stats AS (
        SELECT 
            AVG(duration_minutes) as avg_duration
        FROM public.user_sessions
        WHERE started_at::DATE BETWEEN p_date_from AND p_date_to
        AND duration_minutes IS NOT NULL
    ),
    retention_stats AS (
        SELECT 
            COUNT(CASE WHEN return_user THEN 1 END)::DECIMAL / NULLIF(COUNT(*), 0) as retention
        FROM (
            SELECT 
                user_id,
                MIN(started_at::DATE) as first_session,
                MAX(started_at::DATE) as last_session,
                CASE WHEN MAX(started_at::DATE) > MIN(started_at::DATE) + INTERVAL '1 day' THEN TRUE ELSE FALSE END as return_user
            FROM public.user_sessions
            WHERE started_at::DATE >= p_date_from - INTERVAL '30 days'
            GROUP BY user_id
        ) t
        WHERE first_session BETWEEN p_date_from AND p_date_to
    )
    SELECT 
        us.total,
        us.active,
        us.new_users,
        COALESCE(rs.retention, 0),
        COALESCE(ss.avg_duration, 0),
        '{}'::JSONB -- Placeholder for activities
    FROM user_stats us, session_stats ss, retention_stats rs;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to log security events
CREATE OR REPLACE FUNCTION public.security_audit_log(
    p_event_type TEXT,
    p_user_id UUID DEFAULT NULL,
    p_resource_accessed TEXT DEFAULT NULL,
    p_action_performed TEXT DEFAULT NULL,
    p_success BOOLEAN DEFAULT TRUE,
    p_additional_context JSONB DEFAULT '{}'
)
RETURNS UUID AS $$
DECLARE
    log_id UUID;
    client_ip INET;
    client_agent TEXT;
BEGIN
    -- Get client information from current request
    client_ip := INET(current_setting('request.headers', true)::JSON->>'x-forwarded-for');
    client_agent := current_setting('request.headers', true)::JSON->>'user-agent';
    
    INSERT INTO public.security_audit_logs (
        event_type, user_id, ip_address, user_agent,
        resource_accessed, action_performed, success, additional_context
    ) VALUES (
        p_event_type, COALESCE(p_user_id, auth.uid()), client_ip, client_agent,
        p_resource_accessed, p_action_performed, p_success, p_additional_context
    ) RETURNING id INTO log_id;
    
    RETURN log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- TRIGGERS AND INDEXES
-- =============================================

-- Add updated_at triggers
CREATE TRIGGER update_content_flags_updated_at
    BEFORE UPDATE ON public.content_flags
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_moderation_queue_updated_at
    BEFORE UPDATE ON public.moderation_queue
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_study_rooms_updated_at
    BEFORE UPDATE ON public.study_rooms
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_live_class_sessions_updated_at
    BEFORE UPDATE ON public.live_class_sessions
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Create indexes for better performance
CREATE INDEX idx_content_flags_content ON public.content_flags(content_type, content_id);
CREATE INDEX idx_content_flags_reporter ON public.content_flags(reporter_id);
CREATE INDEX idx_content_flags_status ON public.content_flags(status);
CREATE INDEX idx_content_flags_created_at ON public.content_flags(created_at);

CREATE INDEX idx_moderation_queue_priority ON public.moderation_queue(priority_score DESC);
CREATE INDEX idx_moderation_queue_status ON public.moderation_queue(status);
CREATE INDEX idx_moderation_queue_assigned ON public.moderation_queue(assigned_moderator_id);

CREATE INDEX idx_user_violations_user_id ON public.user_violations(user_id);
CREATE INDEX idx_user_violations_active ON public.user_violations(is_active);

CREATE INDEX idx_study_rooms_code ON public.study_rooms(room_code);
CREATE INDEX idx_study_rooms_host ON public.study_rooms(host_id);
CREATE INDEX idx_study_rooms_status ON public.study_rooms(status);

CREATE INDEX idx_study_room_events_room ON public.study_room_events(room_id, timestamp);
CREATE INDEX idx_study_room_events_type ON public.study_room_events(event_type);

CREATE INDEX idx_notifications_user ON public.realtime_notifications(user_id, created_at DESC);
CREATE INDEX idx_notifications_unread ON public.realtime_notifications(user_id) WHERE read_at IS NULL;

CREATE INDEX idx_system_health_type_time ON public.system_health_metrics(metric_type, recorded_at DESC);
CREATE INDEX idx_security_logs_user_time ON public.security_audit_logs(user_id, created_at DESC);
CREATE INDEX idx_security_logs_event_type ON public.security_audit_logs(event_type);

CREATE INDEX idx_user_sessions_user ON public.user_sessions(user_id, started_at DESC);
CREATE INDEX idx_user_sessions_active ON public.user_sessions(is_active);