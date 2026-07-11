-- ============================================================
-- FIX: Column "school_id" does not exist
-- Run this SQL in Supabase SQL Editor
-- ============================================================

-- 1. First check and add school_id to tables that need it
ALTER TABLE teachers ADD COLUMN IF NOT EXISTS school_id INTEGER;
ALTER TABLE classes ADD COLUMN IF NOT EXISTS school_id INTEGER;
ALTER TABLE attendance ADD COLUMN IF NOT EXISTS school_id INTEGER;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS school_id INTEGER;

-- 2. Add role column to profiles (needed by app)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS role VARCHAR(20) DEFAULT 'student';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'active';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS first_name VARCHAR(100);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS middle_name VARCHAR(100);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS last_name VARCHAR(100);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS phone VARCHAR(50);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS photo_url TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS gender VARCHAR(10);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS date_of_birth DATE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS last_login TIMESTAMPTZ;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 3. Add missing student columns
ALTER TABLE students ADD COLUMN IF NOT EXISTS school_id INTEGER;
ALTER TABLE students ADD COLUMN IF NOT EXISTS user_id INTEGER;
ALTER TABLE students ADD COLUMN IF NOT EXISTS academic_year VARCHAR(20);
ALTER TABLE students ADD COLUMN IF NOT EXISTS archived BOOLEAN DEFAULT FALSE;
ALTER TABLE students ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ;
ALTER TABLE students ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 4. Add teacher columns
ALTER TABLE teachers ADD COLUMN IF NOT EXISTS user_id INTEGER;
ALTER TABLE teachers ADD COLUMN IF NOT EXISTS teacher_id VARCHAR(50);
ALTER TABLE teachers ADD COLUMN IF NOT EXISTS qualification TEXT;
ALTER TABLE teachers ADD COLUMN IF NOT EXISTS experience INTEGER DEFAULT 0;
ALTER TABLE teachers ADD COLUMN IF NOT EXISTS department VARCHAR(100);
ALTER TABLE teachers ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 5. Add class columns
ALTER TABLE classes ADD COLUMN IF NOT EXISTS class_teacher_id INTEGER;
ALTER TABLE classes ADD COLUMN IF NOT EXISTS capacity INTEGER DEFAULT 40;
ALTER TABLE classes ADD COLUMN IF NOT EXISTS grade VARCHAR(50);
ALTER TABLE classes ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 6. Add attendance columns
ALTER TABLE attendance ADD COLUMN IF NOT EXISTS subject_id INTEGER;
ALTER TABLE attendance ADD COLUMN IF NOT EXISTS class_id INTEGER;
ALTER TABLE attendance ADD COLUMN IF NOT EXISTS remarks TEXT;
ALTER TABLE attendance ADD COLUMN IF NOT EXISTS marked_by INTEGER;
ALTER TABLE attendance ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 7. Also add uuid columns for future Supabase compatibility
ALTER TABLE schools ADD COLUMN IF NOT EXISTS code VARCHAR(50);
ALTER TABLE schools ADD COLUMN IF NOT EXISTS logo_url TEXT;
ALTER TABLE schools ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 8. Create NEW tables that definitely don't exist
CREATE TABLE IF NOT EXISTS parents (
  id SERIAL PRIMARY KEY,
  user_id INTEGER,
  school_id INTEGER,
  occupation VARCHAR(100),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
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
  school_id INTEGER,
  name VARCHAR(200) NOT NULL,
  code VARCHAR(50) NOT NULL,
  description TEXT,
  grade_level VARCHAR(50),
  credit_hours INTEGER DEFAULT 1,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
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
  school_id INTEGER,
  name VARCHAR(200) NOT NULL,
  type VARCHAR(20) DEFAULT 'quiz',
  subject_id INTEGER,
  class_id INTEGER,
  term VARCHAR(50),
  total_marks DECIMAL(10,2) DEFAULT 100,
  passing_marks DECIMAL(10,2) DEFAULT 50,
  exam_date DATE,
  start_time TIME,
  end_time TIME,
  status VARCHAR(20) DEFAULT 'scheduled',
  created_by INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS exam_results (
  id SERIAL PRIMARY KEY,
  exam_id INTEGER REFERENCES exams(id) ON DELETE CASCADE,
  student_id INTEGER REFERENCES students(id) ON DELETE CASCADE,
  score DECIMAL(10,2) NOT NULL,
  grade VARCHAR(5),
  remarks TEXT,
  is_approved BOOLEAN DEFAULT FALSE,
  approved_by INTEGER,
  approved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(exam_id, student_id)
);

CREATE TABLE IF NOT EXISTS announcements (
  id SERIAL PRIMARY KEY,
  school_id INTEGER,
  title VARCHAR(300) NOT NULL,
  message TEXT NOT NULL,
  target VARCHAR(20) DEFAULT 'all',
  class_id INTEGER,
  status VARCHAR(20) DEFAULT 'published',
  scheduled_at TIMESTAMPTZ,
  created_by INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS notifications (
  id SERIAL PRIMARY KEY,
  school_id INTEGER,
  user_id INTEGER,
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
  school_id INTEGER,
  actor_id INTEGER,
  actor_role VARCHAR(20),
  action VARCHAR(100) NOT NULL,
  entity_type VARCHAR(50) NOT NULL,
  entity_id INTEGER,
  details JSONB,
  ip_address VARCHAR(50),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS school_settings (
  id SERIAL PRIMARY KEY,
  school_id INTEGER UNIQUE,
  settings JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9. Create indexes
CREATE INDEX IF NOT EXISTS idx_students_school ON students(school_id);
CREATE INDEX IF NOT EXISTS idx_students_archived ON students(archived);
CREATE INDEX IF NOT EXISTS idx_teachers_school ON teachers(school_id);
CREATE INDEX IF NOT EXISTS idx_parents_school ON parents(school_id);
CREATE INDEX IF NOT EXISTS idx_classes_school ON classes(school_id);
CREATE INDEX IF NOT EXISTS idx_subjects_school ON subjects(school_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_audit_logs_school ON audit_logs(school_id);

-- 10. Function to auto-create profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (id, role, first_name, last_name)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data ->> 'role', 'student'),
    COALESCE(NEW.raw_user_meta_data ->> 'first_name', 'User'),
    COALESCE(NEW.raw_user_meta_data ->> 'last_name', 'Unknown')
  );
  RETURN NEW;
END;
$$;

-- Drop existing trigger if any, then create
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();