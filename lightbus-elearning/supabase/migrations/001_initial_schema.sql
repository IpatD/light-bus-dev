-- Enable Row Level Security
ALTER DEFAULT PRIVILEGES REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

-- Create profiles table
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    name TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('student', 'teacher', 'admin')),
    email TEXT UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS on profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for profiles
CREATE POLICY "Users can view their own profile" ON public.profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Admins can view all profiles" ON public.profiles
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Create lessons table
CREATE TABLE IF NOT EXISTS public.lessons (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    teacher_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    scheduled_at TIMESTAMPTZ NOT NULL,
    duration_minutes INTEGER,
    has_audio BOOLEAN DEFAULT FALSE,
    recording_path TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS on lessons
ALTER TABLE public.lessons ENABLE ROW LEVEL SECURITY;

-- Create lesson_participants table
CREATE TABLE IF NOT EXISTS public.lesson_participants (
    lesson_id UUID REFERENCES public.lessons(id) ON DELETE CASCADE,
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    enrolled_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (lesson_id, student_id)
);

-- Enable RLS on lesson_participants
ALTER TABLE public.lesson_participants ENABLE ROW LEVEL SECURITY;

-- Create sr_cards table (Spaced Repetition Cards)
CREATE TABLE IF NOT EXISTS public.sr_cards (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    lesson_id UUID REFERENCES public.lessons(id) ON DELETE CASCADE NOT NULL,
    created_by UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    front_content TEXT NOT NULL,
    back_content TEXT NOT NULL,
    card_type TEXT DEFAULT 'basic',
    difficulty_level INTEGER DEFAULT 1 CHECK (difficulty_level BETWEEN 1 AND 5),
    tags TEXT[] DEFAULT '{}',
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    approved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    approved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS on sr_cards
ALTER TABLE public.sr_cards ENABLE ROW LEVEL SECURITY;

-- Create sr_reviews table (Spaced Repetition Reviews)
CREATE TABLE IF NOT EXISTS public.sr_reviews (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    card_id UUID REFERENCES public.sr_cards(id) ON DELETE CASCADE NOT NULL,
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    scheduled_for TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    quality_rating INTEGER CHECK (quality_rating BETWEEN 0 AND 5),
    response_time_ms INTEGER,
    interval_days INTEGER NOT NULL DEFAULT 1,
    ease_factor DECIMAL(3,2) NOT NULL DEFAULT 2.5,
    repetition_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS on sr_reviews
ALTER TABLE public.sr_reviews ENABLE ROW LEVEL SECURITY;

-- Create sr_progress table (Student Progress Tracking)
CREATE TABLE IF NOT EXISTS public.sr_progress (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    lesson_id UUID REFERENCES public.lessons(id) ON DELETE CASCADE NOT NULL,
    cards_total INTEGER DEFAULT 0,
    cards_reviewed INTEGER DEFAULT 0,
    cards_learned INTEGER DEFAULT 0,
    average_quality DECIMAL(3,2) DEFAULT 0.0,
    study_streak INTEGER DEFAULT 0,
    last_review_date DATE,
    next_review_date DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(student_id, lesson_id)
);

-- Enable RLS on sr_progress
ALTER TABLE public.sr_progress ENABLE ROW LEVEL SECURITY;

-- Create transcripts table
CREATE TABLE IF NOT EXISTS public.transcripts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    lesson_id UUID REFERENCES public.lessons(id) ON DELETE CASCADE NOT NULL,
    content TEXT NOT NULL,
    transcript_type TEXT DEFAULT 'auto' CHECK (transcript_type IN ('auto', 'manual', 'corrected')),
    confidence_score DECIMAL(3,2),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS on transcripts
ALTER TABLE public.transcripts ENABLE ROW LEVEL SECURITY;

-- Create summaries table
CREATE TABLE IF NOT EXISTS public.summaries (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    lesson_id UUID REFERENCES public.lessons(id) ON DELETE CASCADE NOT NULL,
    content TEXT NOT NULL,
    summary_type TEXT DEFAULT 'auto' CHECK (summary_type IN ('auto', 'manual')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS on summaries
ALTER TABLE public.summaries ENABLE ROW LEVEL SECURITY;

-- RLS Policies for lessons
CREATE POLICY "Teachers can view their own lessons" ON public.lessons
    FOR SELECT USING (teacher_id = auth.uid());

CREATE POLICY "Students can view lessons they participate in" ON public.lessons
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.lesson_participants lp
            WHERE lp.lesson_id = id AND lp.student_id = auth.uid()
        )
    );

CREATE POLICY "Teachers can create lessons" ON public.lessons
    FOR INSERT WITH CHECK (teacher_id = auth.uid());

CREATE POLICY "Teachers can update their own lessons" ON public.lessons
    FOR UPDATE USING (teacher_id = auth.uid());

-- RLS Policies for lesson_participants
CREATE POLICY "View lesson participants" ON public.lesson_participants
    FOR SELECT USING (
        -- Teachers can see participants of their lessons
        EXISTS (
            SELECT 1 FROM public.lessons l
            WHERE l.id = lesson_id AND l.teacher_id = auth.uid()
        )
        OR
        -- Students can see their own participation
        student_id = auth.uid()
    );

-- RLS Policies for sr_cards
CREATE POLICY "Students can view approved cards from their lessons" ON public.sr_cards
    FOR SELECT USING (
        status = 'approved' AND
        EXISTS (
            SELECT 1 FROM public.lesson_participants lp
            WHERE lp.lesson_id = sr_cards.lesson_id AND lp.student_id = auth.uid()
        )
    );

CREATE POLICY "Teachers can view all cards from their lessons" ON public.sr_cards
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.lessons l
            WHERE l.id = lesson_id AND l.teacher_id = auth.uid()
        )
    );

CREATE POLICY "Teachers can create cards for their lessons" ON public.sr_cards
    FOR INSERT WITH CHECK (
        created_by = auth.uid() AND
        EXISTS (
            SELECT 1 FROM public.lessons l
            WHERE l.id = lesson_id AND l.teacher_id = auth.uid()
        )
    );

-- RLS Policies for sr_reviews
CREATE POLICY "Students can view their own reviews" ON public.sr_reviews
    FOR SELECT USING (student_id = auth.uid());

CREATE POLICY "Students can create their own reviews" ON public.sr_reviews
    FOR INSERT WITH CHECK (student_id = auth.uid());

CREATE POLICY "Teachers can view reviews for their lessons" ON public.sr_reviews
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.sr_cards sc
            JOIN public.lessons l ON sc.lesson_id = l.id
            WHERE sc.id = card_id AND l.teacher_id = auth.uid()
        )
    );

-- RLS Policies for sr_progress
CREATE POLICY "Students can view their own progress" ON public.sr_progress
    FOR SELECT USING (student_id = auth.uid());

CREATE POLICY "Students can update their own progress" ON public.sr_progress
    FOR UPDATE USING (student_id = auth.uid());

CREATE POLICY "Teachers can view progress for their lessons" ON public.sr_progress
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.lessons l
            WHERE l.id = lesson_id AND l.teacher_id = auth.uid()
        )
    );

-- Function to handle new user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, name, email, role)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'name', SPLIT_PART(NEW.email, '@', 1)),
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'role', 'student')
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to automatically create profile on user signup
CREATE OR REPLACE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add updated_at triggers
CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_lessons_updated_at
    BEFORE UPDATE ON public.lessons
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_sr_cards_updated_at
    BEFORE UPDATE ON public.sr_cards
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_sr_progress_updated_at
    BEFORE UPDATE ON public.sr_progress
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_transcripts_updated_at
    BEFORE UPDATE ON public.transcripts
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_summaries_updated_at
    BEFORE UPDATE ON public.summaries
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Create indexes for better performance
CREATE INDEX idx_profiles_role ON public.profiles(role);
CREATE INDEX idx_profiles_email ON public.profiles(email);
CREATE INDEX idx_lessons_teacher_id ON public.lessons(teacher_id);
CREATE INDEX idx_lessons_scheduled_at ON public.lessons(scheduled_at);
CREATE INDEX idx_lesson_participants_student_id ON public.lesson_participants(student_id);
CREATE INDEX idx_sr_cards_lesson_id ON public.sr_cards(lesson_id);
CREATE INDEX idx_sr_cards_status ON public.sr_cards(status);
CREATE INDEX idx_sr_reviews_student_id ON public.sr_reviews(student_id);
CREATE INDEX idx_sr_reviews_card_id ON public.sr_reviews(card_id);
CREATE INDEX idx_sr_reviews_scheduled_for ON public.sr_reviews(scheduled_for);
CREATE INDEX idx_sr_progress_student_id ON public.sr_progress(student_id);
CREATE INDEX idx_sr_progress_lesson_id ON public.sr_progress(lesson_id);