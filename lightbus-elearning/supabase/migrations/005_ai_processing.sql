-- AI Processing and Analytics Schema for Phase 3
-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create processing_jobs table for tracking AI operations
CREATE TABLE IF NOT EXISTS public.processing_jobs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    lesson_id UUID REFERENCES public.lessons(id) ON DELETE CASCADE NOT NULL,
    job_type TEXT NOT NULL CHECK (job_type IN ('transcription', 'summarization', 'flashcard_generation', 'content_analysis')),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'cancelled')),
    progress_percentage INTEGER DEFAULT 0 CHECK (progress_percentage BETWEEN 0 AND 100),
    input_data JSONB,
    output_data JSONB,
    error_message TEXT,
    ai_service_provider TEXT CHECK (ai_service_provider IN ('openai', 'assemblyai', 'custom')),
    api_request_id TEXT,
    processing_started_at TIMESTAMPTZ,
    processing_completed_at TIMESTAMPTZ,
    estimated_completion_time TIMESTAMPTZ,
    cost_cents INTEGER DEFAULT 0,
    created_by UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create content_analysis table for storing analysis results
CREATE TABLE IF NOT EXISTS public.content_analysis (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    lesson_id UUID REFERENCES public.lessons(id) ON DELETE CASCADE NOT NULL,
    processing_job_id UUID REFERENCES public.processing_jobs(id) ON DELETE CASCADE,
    analysis_type TEXT NOT NULL CHECK (analysis_type IN ('key_concepts', 'learning_objectives', 'prerequisites', 'difficulty_assessment', 'topic_extraction')),
    analysis_data JSONB NOT NULL,
    confidence_score DECIMAL(3,2) CHECK (confidence_score BETWEEN 0.0 AND 1.0),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create auto_generated_cards table for AI-created flashcards
CREATE TABLE IF NOT EXISTS public.auto_generated_cards (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    lesson_id UUID REFERENCES public.lessons(id) ON DELETE CASCADE NOT NULL,
    processing_job_id UUID REFERENCES public.processing_jobs(id) ON DELETE CASCADE,
    sr_card_id UUID REFERENCES public.sr_cards(id) ON DELETE CASCADE,
    front_content TEXT NOT NULL,
    back_content TEXT NOT NULL,
    card_type TEXT DEFAULT 'basic' CHECK (card_type IN ('basic', 'cloze', 'multiple_choice', 'true_false')),
    difficulty_level INTEGER DEFAULT 1 CHECK (difficulty_level BETWEEN 1 AND 5),
    confidence_score DECIMAL(3,2) CHECK (confidence_score BETWEEN 0.0 AND 1.0),
    source_text TEXT,
    source_timestamp_start INTEGER,
    source_timestamp_end INTEGER,
    tags TEXT[] DEFAULT '{}',
    quality_score DECIMAL(3,2) DEFAULT 0.0,
    review_status TEXT DEFAULT 'pending' CHECK (review_status IN ('pending', 'approved', 'rejected', 'needs_review')),
    reviewed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    auto_approved BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create processing_logs table for debugging and monitoring
CREATE TABLE IF NOT EXISTS public.processing_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    processing_job_id UUID REFERENCES public.processing_jobs(id) ON DELETE CASCADE NOT NULL,
    log_level TEXT NOT NULL CHECK (log_level IN ('debug', 'info', 'warning', 'error')),
    message TEXT NOT NULL,
    details JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create student_analytics table for enhanced analytics
CREATE TABLE IF NOT EXISTS public.student_analytics (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    lesson_id UUID REFERENCES public.lessons(id) ON DELETE CASCADE,
    analytics_date DATE NOT NULL DEFAULT CURRENT_DATE,
    study_time_minutes INTEGER DEFAULT 0,
    cards_reviewed INTEGER DEFAULT 0,
    cards_correct INTEGER DEFAULT 0,
    average_response_time_ms INTEGER DEFAULT 0,
    learning_velocity DECIMAL(5,2) DEFAULT 0.0,
    retention_rate DECIMAL(3,2) DEFAULT 0.0,
    difficulty_progression DECIMAL(3,2) DEFAULT 0.0,
    engagement_score DECIMAL(3,2) DEFAULT 0.0,
    predicted_mastery_date DATE,
    risk_score DECIMAL(3,2) DEFAULT 0.0 CHECK (risk_score BETWEEN 0.0 AND 1.0),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(student_id, lesson_id, analytics_date)
);

-- Create learning_insights table for AI-generated recommendations
CREATE TABLE IF NOT EXISTS public.learning_insights (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    lesson_id UUID REFERENCES public.lessons(id) ON DELETE CASCADE,
    insight_type TEXT NOT NULL CHECK (insight_type IN ('weakness_identification', 'study_recommendation', 'optimal_timing', 'progress_prediction', 'intervention_needed')),
    insight_data JSONB NOT NULL,
    priority_level INTEGER DEFAULT 1 CHECK (priority_level BETWEEN 1 AND 5),
    confidence_score DECIMAL(3,2) CHECK (confidence_score BETWEEN 0.0 AND 1.0),
    is_active BOOLEAN DEFAULT TRUE,
    expires_at TIMESTAMPTZ,
    acted_upon BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create system_metrics table for performance monitoring
CREATE TABLE IF NOT EXISTS public.system_metrics (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    metric_name TEXT NOT NULL,
    metric_value DECIMAL(10,4) NOT NULL,
    metric_unit TEXT,
    metric_category TEXT CHECK (metric_category IN ('performance', 'usage', 'cost', 'quality', 'user_engagement')),
    metadata JSONB,
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS on all new tables
ALTER TABLE public.processing_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_analysis ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auto_generated_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.processing_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.learning_insights ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_metrics ENABLE ROW LEVEL SECURITY;

-- RLS Policies for processing_jobs
CREATE POLICY "Teachers can view processing jobs for their lessons" ON public.processing_jobs
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.lessons l
            WHERE l.id = lesson_id AND l.teacher_id = auth.uid()
        )
    );

CREATE POLICY "Teachers can create processing jobs for their lessons" ON public.processing_jobs
    FOR INSERT WITH CHECK (
        created_by = auth.uid() AND
        EXISTS (
            SELECT 1 FROM public.lessons l
            WHERE l.id = lesson_id AND l.teacher_id = auth.uid()
        )
    );

-- RLS Policies for content_analysis
CREATE POLICY "Teachers can view content analysis for their lessons" ON public.content_analysis
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.lessons l
            WHERE l.id = lesson_id AND l.teacher_id = auth.uid()
        )
    );

-- RLS Policies for auto_generated_cards
CREATE POLICY "Teachers can view auto-generated cards for their lessons" ON public.auto_generated_cards
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.lessons l
            WHERE l.id = lesson_id AND l.teacher_id = auth.uid()
        )
    );

CREATE POLICY "Teachers can update auto-generated cards for their lessons" ON public.auto_generated_cards
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.lessons l
            WHERE l.id = lesson_id AND l.teacher_id = auth.uid()
        )
    );

-- RLS Policies for student_analytics
CREATE POLICY "Students can view their own analytics" ON public.student_analytics
    FOR SELECT USING (student_id = auth.uid());

CREATE POLICY "Teachers can view analytics for their lessons" ON public.student_analytics
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.lessons l
            WHERE l.id = lesson_id AND l.teacher_id = auth.uid()
        )
    );

-- RLS Policies for learning_insights
CREATE POLICY "Students can view their own insights" ON public.learning_insights
    FOR SELECT USING (student_id = auth.uid());

CREATE POLICY "Teachers can view insights for their lessons" ON public.learning_insights
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.lessons l
            WHERE l.id = lesson_id AND l.teacher_id = auth.uid()
        )
    );

-- RLS Policies for system_metrics
CREATE POLICY "Admins can view all system metrics" ON public.system_metrics
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Database Functions for AI Processing

-- Function to create a processing job
CREATE OR REPLACE FUNCTION public.create_processing_job(
    p_lesson_id UUID,
    p_job_type TEXT,
    p_input_data JSONB DEFAULT NULL,
    p_ai_service_provider TEXT DEFAULT 'openai'
)
RETURNS UUID AS $$
DECLARE
    job_id UUID;
BEGIN
    INSERT INTO public.processing_jobs (
        lesson_id,
        job_type,
        input_data,
        ai_service_provider,
        created_by
    ) VALUES (
        p_lesson_id,
        p_job_type,
        p_input_data,
        p_ai_service_provider,
        auth.uid()
    )
    RETURNING id INTO job_id;
    
    RETURN job_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update processing status
CREATE OR REPLACE FUNCTION public.update_processing_status(
    p_job_id UUID,
    p_status TEXT,
    p_progress_percentage INTEGER DEFAULT NULL,
    p_error_message TEXT DEFAULT NULL,
    p_output_data JSONB DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE public.processing_jobs
    SET 
        status = p_status,
        progress_percentage = COALESCE(p_progress_percentage, progress_percentage),
        error_message = p_error_message,
        output_data = COALESCE(p_output_data, output_data),
        processing_started_at = CASE 
            WHEN p_status = 'processing' AND processing_started_at IS NULL 
            THEN NOW() 
            ELSE processing_started_at 
        END,
        processing_completed_at = CASE 
            WHEN p_status IN ('completed', 'failed', 'cancelled') 
            THEN NOW() 
            ELSE processing_completed_at 
        END,
        updated_at = NOW()
    WHERE id = p_job_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to store transcript
CREATE OR REPLACE FUNCTION public.store_transcript(
    p_lesson_id UUID,
    p_content TEXT,
    p_transcript_type TEXT DEFAULT 'auto',
    p_confidence_score DECIMAL DEFAULT NULL,
    p_processing_job_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    transcript_id UUID;
BEGIN
    INSERT INTO public.transcripts (
        lesson_id,
        content,
        transcript_type,
        confidence_score
    ) VALUES (
        p_lesson_id,
        p_content,
        p_transcript_type,
        p_confidence_score
    )
    RETURNING id INTO transcript_id;
    
    -- Update processing job if provided
    IF p_processing_job_id IS NOT NULL THEN
        PERFORM public.update_processing_status(
            p_processing_job_id,
            'completed',
            100,
            NULL,
            jsonb_build_object('transcript_id', transcript_id)
        );
    END IF;
    
    RETURN transcript_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to store AI-generated cards
CREATE OR REPLACE FUNCTION public.store_ai_cards(
    p_lesson_id UUID,
    p_processing_job_id UUID,
    p_cards JSONB
)
RETURNS INTEGER AS $$
DECLARE
    card_data JSONB;
    cards_created INTEGER := 0;
    auto_card_id UUID;
BEGIN
    FOR card_data IN SELECT * FROM jsonb_array_elements(p_cards)
    LOOP
        INSERT INTO public.auto_generated_cards (
            lesson_id,
            processing_job_id,
            front_content,
            back_content,
            card_type,
            difficulty_level,
            confidence_score,
            source_text,
            source_timestamp_start,
            source_timestamp_end,
            tags,
            quality_score
        ) VALUES (
            p_lesson_id,
            p_processing_job_id,
            card_data->>'front_content',
            card_data->>'back_content',
            COALESCE(card_data->>'card_type', 'basic'),
            COALESCE((card_data->>'difficulty_level')::INTEGER, 1),
            COALESCE((card_data->>'confidence_score')::DECIMAL, 0.8),
            card_data->>'source_text',
            (card_data->>'source_timestamp_start')::INTEGER,
            (card_data->>'source_timestamp_end')::INTEGER,
            COALESCE(
                ARRAY(SELECT jsonb_array_elements_text(card_data->'tags')),
                ARRAY[]::TEXT[]
            ),
            COALESCE((card_data->>'quality_score')::DECIMAL, 0.0)
        )
        RETURNING id INTO auto_card_id;
        
        cards_created := cards_created + 1;
    END LOOP;
    
    -- Update processing job status
    PERFORM public.update_processing_status(
        p_processing_job_id,
        'completed',
        100,
        NULL,
        jsonb_build_object('cards_created', cards_created)
    );
    
    RETURN cards_created;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get processing status
CREATE OR REPLACE FUNCTION public.get_processing_status(p_job_id UUID)
RETURNS TABLE (
    job_id UUID,
    lesson_id UUID,
    job_type TEXT,
    status TEXT,
    progress_percentage INTEGER,
    error_message TEXT,
    created_at TIMESTAMPTZ,
    processing_started_at TIMESTAMPTZ,
    processing_completed_at TIMESTAMPTZ,
    estimated_completion_time TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pj.id,
        pj.lesson_id,
        pj.job_type,
        pj.status,
        pj.progress_percentage,
        pj.error_message,
        pj.created_at,
        pj.processing_started_at,
        pj.processing_completed_at,
        pj.estimated_completion_time
    FROM public.processing_jobs pj
    WHERE pj.id = p_job_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to calculate student analytics
CREATE OR REPLACE FUNCTION public.calculate_student_analytics(
    p_student_id UUID,
    p_lesson_id UUID DEFAULT NULL,
    p_date DATE DEFAULT CURRENT_DATE
)
RETURNS VOID AS $$
DECLARE
    lesson_record RECORD;
    analytics_data RECORD;
BEGIN
    -- If lesson_id is provided, calculate for specific lesson
    -- Otherwise, calculate for all lessons the student participates in
    FOR lesson_record IN 
        SELECT DISTINCT l.id as lesson_id
        FROM public.lessons l
        JOIN public.lesson_participants lp ON l.id = lp.lesson_id
        WHERE lp.student_id = p_student_id
        AND (p_lesson_id IS NULL OR l.id = p_lesson_id)
    LOOP
        -- Calculate analytics for this lesson
        SELECT 
            COALESCE(SUM(EXTRACT(EPOCH FROM (r.completed_at - r.created_at))/60), 0) as study_time_minutes,
            COUNT(r.id) as cards_reviewed,
            COUNT(CASE WHEN r.quality_rating >= 3 THEN 1 END) as cards_correct,
            COALESCE(AVG(r.response_time_ms), 0) as avg_response_time_ms,
            COALESCE(AVG(r.quality_rating), 0) as avg_quality,
            COUNT(CASE WHEN r.quality_rating >= 4 THEN 1 END)::DECIMAL / NULLIF(COUNT(r.id), 0) as retention_rate
        INTO analytics_data
        FROM public.sr_reviews r
        JOIN public.sr_cards c ON r.card_id = c.id
        WHERE r.student_id = p_student_id
        AND c.lesson_id = lesson_record.lesson_id
        AND DATE(r.completed_at) = p_date
        AND r.completed_at IS NOT NULL;
        
        -- Insert or update analytics record
        INSERT INTO public.student_analytics (
            student_id,
            lesson_id,
            analytics_date,
            study_time_minutes,
            cards_reviewed,
            cards_correct,
            average_response_time_ms,
            retention_rate,
            engagement_score
        ) VALUES (
            p_student_id,
            lesson_record.lesson_id,
            p_date,
            analytics_data.study_time_minutes::INTEGER,
            analytics_data.cards_reviewed::INTEGER,
            analytics_data.cards_correct::INTEGER,
            analytics_data.avg_response_time_ms::INTEGER,
            COALESCE(analytics_data.retention_rate, 0.0),
            LEAST(1.0, analytics_data.study_time_minutes / 30.0) -- Engagement based on study time
        )
        ON CONFLICT (student_id, lesson_id, analytics_date)
        DO UPDATE SET
            study_time_minutes = EXCLUDED.study_time_minutes,
            cards_reviewed = EXCLUDED.cards_reviewed,
            cards_correct = EXCLUDED.cards_correct,
            average_response_time_ms = EXCLUDED.average_response_time_ms,
            retention_rate = EXCLUDED.retention_rate,
            engagement_score = EXCLUDED.engagement_score,
            updated_at = NOW();
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add updated_at triggers for new tables
CREATE TRIGGER update_processing_jobs_updated_at
    BEFORE UPDATE ON public.processing_jobs
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_content_analysis_updated_at
    BEFORE UPDATE ON public.content_analysis
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_auto_generated_cards_updated_at
    BEFORE UPDATE ON public.auto_generated_cards
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_student_analytics_updated_at
    BEFORE UPDATE ON public.student_analytics
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_learning_insights_updated_at
    BEFORE UPDATE ON public.learning_insights
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Create indexes for better performance
CREATE INDEX idx_processing_jobs_lesson_id ON public.processing_jobs(lesson_id);
CREATE INDEX idx_processing_jobs_status ON public.processing_jobs(status);
CREATE INDEX idx_processing_jobs_job_type ON public.processing_jobs(job_type);
CREATE INDEX idx_processing_jobs_created_by ON public.processing_jobs(created_by);

CREATE INDEX idx_content_analysis_lesson_id ON public.content_analysis(lesson_id);
CREATE INDEX idx_content_analysis_analysis_type ON public.content_analysis(analysis_type);

CREATE INDEX idx_auto_generated_cards_lesson_id ON public.auto_generated_cards(lesson_id);
CREATE INDEX idx_auto_generated_cards_review_status ON public.auto_generated_cards(review_status);
CREATE INDEX idx_auto_generated_cards_processing_job_id ON public.auto_generated_cards(processing_job_id);

CREATE INDEX idx_processing_logs_job_id ON public.processing_logs(processing_job_id);
CREATE INDEX idx_processing_logs_log_level ON public.processing_logs(log_level);
CREATE INDEX idx_processing_logs_created_at ON public.processing_logs(created_at);

CREATE INDEX idx_student_analytics_student_id ON public.student_analytics(student_id);
CREATE INDEX idx_student_analytics_lesson_id ON public.student_analytics(lesson_id);
CREATE INDEX idx_student_analytics_date ON public.student_analytics(analytics_date);

CREATE INDEX idx_learning_insights_student_id ON public.learning_insights(student_id);
CREATE INDEX idx_learning_insights_lesson_id ON public.learning_insights(lesson_id);
CREATE INDEX idx_learning_insights_insight_type ON public.learning_insights(insight_type);
CREATE INDEX idx_learning_insights_priority_level ON public.learning_insights(priority_level);

CREATE INDEX idx_system_metrics_metric_name ON public.system_metrics(metric_name);
CREATE INDEX idx_system_metrics_metric_category ON public.system_metrics(metric_category);
CREATE INDEX idx_system_metrics_recorded_at ON public.system_metrics(recorded_at);