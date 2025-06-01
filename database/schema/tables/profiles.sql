-- =====================================================
-- TABLE: profiles
-- Description: User profiles with roles (teachers, students, admins)
-- =====================================================

CREATE TABLE profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    name TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('teacher', 'student', 'admin')),
    email TEXT UNIQUE NOT NULL
);

-- Indexes
CREATE INDEX idx_profiles_email ON profiles(email);
CREATE INDEX idx_profiles_role ON profiles(role);

-- Triggers
CREATE TRIGGER update_profiles_updated_at 
    BEFORE UPDATE ON profiles 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Comments
COMMENT ON TABLE profiles IS 'User profiles including teachers, students, and administrators';
COMMENT ON COLUMN profiles.role IS 'User role: teacher, student, or admin';
COMMENT ON COLUMN profiles.email IS 'Unique email address for authentication';