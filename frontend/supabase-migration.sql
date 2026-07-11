-- ============================================================
-- SUPABASE MIGRATION: Add missing tables & features
-- Only adds what doesn't already exist
-- ============================================================

-- 1. Create ENUMs if they don't exist
DO $$ BEGIN
  CREATE TYPE user_role AS ENUM ('superadmin', 'admin', 'teacher', 'student', 'parent');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE account_status AS ENUM ('active', 'inactive', 'suspended');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE attendance_status AS ENUM ('present', 'absent', 'late', 'excused');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE assessment_type AS ENUM ('assignment', 'quiz', 'mid_exam', 'final_exam');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE announcement_target AS ENUM ('all', 'students', 'teachers', 'parents', 'class');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 2. Add missing columns to existing tables
ALTER TABLE schools ADD COLUMN IF NOT EXISTS code VARCHAR(50) UNIQUE;
ALTER TABLE schools ADD COLUMN IF NOT EXISTS logo_url TEXT;
ALTER TABLE schools ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Add UUID columns alongside existing int IDs for Supabase compatibility
ALTER TABLE schools ADD COLUMN IF NOT EXISTS uuid UUID DEFAULT uuid_generate_v4();

-- Add profile columns that Supabase profiles table needs
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS first_name VARCHAR(100);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS middle_name VARCHAR(100);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS last_name VARCHAR(100);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS phone VARCHAR(50);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS photo_url TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS gender VARCHAR(10);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS date_of_birth DATE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS role user_role DEFAULT 'student';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS status account_status DEFAULT 'active';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS last_login TIMESTAMPTZ;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Add uuid to profiles for Supabase auth compatibility
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS uuid UUID DEFAULT uuid_generate_v4();

-- Students table additions
ALTER TABLE students ADD COLUMN IF NOT EXISTS school_id INTEGER REFERENCES schools(id);
ALTER TABLE students ADD COLUMN IF NOT EXISTS user_id INTEGER REFERENCES profiles(id);
ALTER TABLE students ADD COLUMN IF NOT EXISTS academic_year VARCHAR(20);
ALTER TABLE students ADD COLUMN IF NOT EXISTS archived BOOLEAN DEFAULT FALSE;
ALTER TABLE students ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ;
ALTER TABLE students ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE students ADD COLUMN IF NOT EXISTS uuid UUID DEFAULT uuid_generate_v4();

-- Teachers table additions
ALTER TABLE teachers ADD COLUMN IF NOT EXISTS school_id INTEGER REFERENCES schools(id);
ALTER TABLE teachers ADD COLUMN IF NOT EXISTS user_id INTEGER REFERENCES profiles(id);
ALTER TABLE teachers ADD COLUMN IF NOT EXISTS teacher_id VARCHAR(50) UNIQUE;
ALTER TABLE teachers ADD COLUMN IF NOT EXISTS qualification TEXT;
ALTER TABLE teachers ADD COLUMN IF NOT EXISTS experience INTEGER DEFAULT 0;
ALTER TABLE teachers ADD COLUMN IF NOT EXISTS department VARCHAR(100);
ALTER TABLE teachers ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE teachers ADD COLUMN IF NOT EXISTS uuid UUID DEFAULT uuid_generate_v4();

-- Classes table additions
ALTER TABLE classes ADD COLUMN IF NOT EXISTS school_id INTEGER REFERENCES schools(id);
ALTER TABLE classes ADD COLUMN IF NOT EXISTS class_teacher_id INTEGER REFERENCES teachers(id);
ALTER TABLE classes ADD COLUMN IF NOT EXISTS capacity INTEGER DEFAULT 40;
ALTER TABLE classes ADD COLUMN IF NOT EXISTS grade VARCHAR(50);
ALTER TABLE classes ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE classes ADD COLUMN IF NOT EXISTS uuid UUID DEFAULT uuid_generate_v4();

-- Create new tables that don't exist
CREATE TABLE IF NOT EXISTS parents (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES profiles(id),
  school_id INTEGER REFERENCES schools(id),
  occupation VARCHAR(100),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  uuid UUID DEFAULT uuid_generate_v4()
);

CREATE TABLE IF NOT EXISTS student_parents (
  id SERIAL PRIMARY KEY,
  student_id INTEGER REFERENCES students(id) ON DELETE CASCADE,
  parent_id INTEGER REFERENCES parents(id) ON DELETE CASCADE,
  relationship VARCHAR(50) DEFAULT 'guardian',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(student_id, parent_id)
);

CREATE TABLE IF NOT EXISTS student_classes (
  id SERIAL PRIMARY KEY,
  student_id INTEGER REFERENCES students(id) ON DELETE CASCADE,
  class_id INTEGER REFERENCES classes(id) ON DELETE CASCADE,
  academic_year VARCHAR(20),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(student_id, class_id, academic_year)
);

CREATE TABLE IF NOT EXISTS subjects (
  id SERIAL PRIMARY KEY,
  school_id INTEGER REFERENCES schools(id),
  name VARCHAR(200) NOT NULL,
  code VARCHAR(50) NOT NULL,
  description TEXT,
  grade_level VARCHAR(50),
  credit_hours INTEGER DEFAULT 1,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  uuid UUID DEFAULT uuid_generate_v4(),
  UNIQUE(school_id, code)
);

CREATE TABLE IF NOT EXISTS teacher_subjects (
  id SERIAL PRIMARY KEY,
  teacher_id INTEGER REFERENCES teachers(id) ON DELETE CASCADE,
  subject_id INTEGER REFERENCES subjects(id) ON DELETE CASCADE,
  class_id INTEGER REFERENCES classes(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(teacher_id, subject_id, class_id)
);

CREATE TABLE IF NOT EXISTS exams (
  id SERIAL PRIMARY KEY,
  school_id INTEGER REFERENCES schools(id),
  name VARCHAR(200) NOT NULL,
  type assessment_type DEFAULT 'quiz',
  subject_id INTEGER REFERENCES subjects(id),
  class_id INTEGER REFERENCES classes(id),
  term VARCHAR(50),
  total_marks DECIMAL(10,2) DEFAULT 100,
  passing_marks DECIMAL(10,2) DEFAULT 50,
  exam_date DATE,
  start_time TIME,
  end_time TIME,
  status VARCHAR(20) DEFAULT 'scheduled',
  created_by INTEGER REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  uuid UUID DEFAULT uuid_generate_v4()
);

CREATE TABLE IF NOT EXISTS exam_results (
  id SERIAL PRIMARY KEY,
  exam_id INTEGER REFERENCES exams(id) ON DELETE CASCADE,
  student_id INTEGER REFERENCES students(id) ON DELETE CASCADE,
  score DECIMAL(10,2) NOT NULL,
  grade VARCHAR(5),
  remarks TEXT,
  is_approved BOOLEAN DEFAULT FALSE,
  approved_by INTEGER REFERENCES profiles(id),
  approved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(exam_id, student_id)
);

CREATE TABLE IF NOT EXISTS announcements (
  id SERIAL PRIMARY KEY,
  school_id INTEGER REFERENCES schools(id),
  title VARCHAR(300) NOT NULL,
  message TEXT NOT NULL,
  target announcement_target DEFAULT 'all',
  class_id INTEGER REFERENCES classes(id),
  status VARCHAR(20) DEFAULT 'published',
  scheduled_at TIMESTAMPTZ,
  created_by INTEGER REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  uuid UUID DEFAULT uuid_generate_v4()
);

CREATE TABLE IF NOT EXISTS notifications (
  id SERIAL PRIMARY KEY,
  school_id INTEGER REFERENCES schools(id),
  user_id INTEGER REFERENCES profiles(id),
  title VARCHAR(300) NOT NULL,
  message TEXT,
  type VARCHAR(50) DEFAULT 'info',
  icon_emoji VARCHAR(10),
  is_read BOOLEAN DEFAULT FALSE,
  link_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS audit_logs (
  id SERIAL PRIMARY KEY,
  school_id INTEGER REFERENCES schools(id),
  actor_id INTEGER REFERENCES profiles(id),
  actor_role user_role,
  action VARCHAR(100) NOT NULL,
  entity_type VARCHAR(50) NOT NULL,
  entity_id INTEGER,
  details JSONB,
  ip_address VARCHAR(50),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS school_settings (
  id SERIAL PRIMARY KEY,
  school_id INTEGER REFERENCES schools(id) UNIQUE,
  settings JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Update updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Create triggers for tables that have updated_at
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_schools_updated_at') THEN
    CREATE TRIGGER update_schools_updated_at BEFORE UPDATE ON schools FOR EACH ROW EXECUTE FUNCTION update_updated_at();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_profiles_updated_at') THEN
    CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_students_updated_at') THEN
    CREATE TRIGGER update_students_updated_at BEFORE UPDATE ON students FOR EACH ROW EXECUTE FUNCTION update_updated_at();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_teachers_updated_at') THEN
    CREATE TRIGGER update_teachers_updated_at BEFORE UPDATE ON teachers FOR EACH ROW EXECUTE FUNCTION update_updated_at();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_classes_updated_at') THEN
    CREATE TRIGGER update_classes_updated_at BEFORE UPDATE ON classes FOR EACH ROW EXECUTE FUNCTION update_updated_at();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_subjects_updated_at') THEN
    CREATE TRIGGER update_subjects_updated_at BEFORE UPDATE ON subjects FOR EACH ROW EXECUTE FUNCTION update_updated_at();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_exams_updated_at') THEN
    CREATE TRIGGER update_exams_updated_at BEFORE UPDATE ON exams FOR EACH ROW EXECUTE FUNCTION update_updated_at();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_exam_results_updated_at') THEN
    CREATE TRIGGER update_exam_results_updated_at BEFORE UPDATE ON exam_results FOR EACH ROW EXECUTE FUNCTION update_updated_at();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_announcements_updated_at') THEN
    CREATE TRIGGER update_announcements_updated_at BEFORE UPDATE ON announcements FOR EACH ROW EXECUTE FUNCTION update_updated_at();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_school_settings_updated_at') THEN
    CREATE TRIGGER update_school_settings_updated_at BEFORE UPDATE ON school_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at();
  END IF;
END $$;

-- 5. Helper functions
CREATE OR REPLACE FUNCTION calculate_letter_grade(p_score DECIMAL, p_total DECIMAL)
RETURNS VARCHAR AS $$
DECLARE
  v_pct DECIMAL;
BEGIN
  IF p_total <= 0 THEN RETURN 'F'; END IF;
  v_pct := (p_score / p_total) * 100;
  RETURN CASE
    WHEN v_pct >= 95 THEN 'A+'
    WHEN v_pct >= 90 THEN 'A'
    WHEN v_pct >= 85 THEN 'B+'
    WHEN v_pct >= 80 THEN 'B'
    WHEN v_pct >= 75 THEN 'C+'
    WHEN v_pct >= 70 THEN 'C'
    WHEN v_pct >= 60 THEN 'D'
    ELSE 'F'
  END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Auto-calculate letter grade
CREATE OR REPLACE FUNCTION auto_calculate_grade()
RETURNS TRIGGER AS $$
DECLARE
  v_total DECIMAL;
BEGIN
  SELECT total_marks INTO v_total FROM exams WHERE id = NEW.exam_id;
  NEW.grade := calculate_letter_grade(NEW.score, v_total);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS auto_calculate_grade_trigger ON exam_results;
CREATE TRIGGER auto_calculate_grade_trigger
  BEFORE INSERT OR UPDATE ON exam_results
  FOR EACH ROW EXECUTE FUNCTION auto_calculate_grade();

-- 6. Indexes
CREATE INDEX IF NOT EXISTS idx_profiles_uuid ON profiles(uuid);
CREATE INDEX IF NOT EXISTS idx_students_school ON students(school_id);
CREATE INDEX IF NOT EXISTS idx_students_archived ON students(archived);
CREATE INDEX IF NOT EXISTS idx_teachers_school ON teachers(school_id);
CREATE INDEX IF NOT EXISTS idx_parents_school ON parents(school_id);
CREATE INDEX IF NOT EXISTS idx_classes_school ON classes(school_id);
CREATE INDEX IF NOT EXISTS idx_subjects_school ON subjects(school_id);
CREATE INDEX IF NOT EXISTS idx_attendance_date ON attendance(date);
CREATE INDEX IF NOT EXISTS idx_exams_school ON exams(school_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_audit_logs_school ON audit_logs(school_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at DESC);

-- 7. Enable Row Level Security where possible
-- (Note: RLS on existing tables may require ownership)
ALTER TABLE schools ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE students ENABLE ROW LEVEL SECURITY;
ALTER TABLE teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE parents ENABLE ROW LEVEL SECURITY;
ALTER TABLE classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE exams ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE school_settings ENABLE ROW LEVEL SECURITY;

-- 8. Auto-create profile on auth signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, role, first_name, last_name)
  VALUES (
    NEW.id,
    COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'student'),
    COALESCE(NEW.raw_user_meta_data->>'first_name', 'User'),
    COALESCE(NEW.raw_user_meta_data->>'last_name', 'Unknown')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();