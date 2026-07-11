-- ============================================================
-- SCHOOL MANAGEMENT SYSTEM - SUPABASE SCHEMA
-- ============================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- 2. ENUMS
-- ============================================================
CREATE TYPE user_role AS ENUM ('superadmin', 'admin', 'teacher', 'student', 'parent');
CREATE TYPE account_status AS ENUM ('active', 'inactive', 'suspended');
CREATE TYPE attendance_status AS ENUM ('present', 'absent', 'late', 'excused');
CREATE TYPE assessment_type AS ENUM ('assignment', 'quiz', 'mid_exam', 'final_exam');
CREATE TYPE announcement_target AS ENUM ('all', 'students', 'teachers', 'parents', 'class');

-- ============================================================
-- 3. TABLES
-- ============================================================

-- Schools (multi-tenant)
CREATE TABLE schools (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(255) NOT NULL,
  code VARCHAR(50) UNIQUE NOT NULL,
  address TEXT,
  phone VARCHAR(50),
  email VARCHAR(255),
  logo_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Profiles (extends Supabase auth.users)
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  school_id UUID REFERENCES schools(id) ON DELETE SET NULL,
  role user_role NOT NULL DEFAULT 'student',
  first_name VARCHAR(100) NOT NULL,
  middle_name VARCHAR(100),
  last_name VARCHAR(100) NOT NULL,
  phone VARCHAR(50),
  address TEXT,
  photo_url TEXT,
  gender VARCHAR(10),
  date_of_birth DATE,
  status account_status DEFAULT 'active',
  last_login TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Students
CREATE TABLE students (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
  school_id UUID REFERENCES schools(id) ON DELETE CASCADE NOT NULL,
  student_id VARCHAR(50) UNIQUE NOT NULL,
  admission_date DATE NOT NULL DEFAULT CURRENT_DATE,
  academic_year VARCHAR(20) NOT NULL,
  parent_id UUID REFERENCES parents(id) ON DELETE SET NULL,
  archived BOOLEAN DEFAULT FALSE,
  archived_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Teachers
CREATE TABLE teachers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
  school_id UUID REFERENCES schools(id) ON DELETE CASCADE NOT NULL,
  teacher_id VARCHAR(50) UNIQUE NOT NULL,
  qualification TEXT,
  experience INTEGER DEFAULT 0,
  department VARCHAR(100),
  hire_date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Parents
CREATE TABLE parents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
  school_id UUID REFERENCES schools(id) ON DELETE CASCADE NOT NULL,
  occupation VARCHAR(100),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Student-Parent Relationship (one parent -> many students)
CREATE TABLE student_parents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID REFERENCES students(id) ON DELETE CASCADE NOT NULL,
  parent_id UUID REFERENCES parents(id) ON DELETE CASCADE NOT NULL,
  relationship VARCHAR(50) DEFAULT 'guardian',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(student_id, parent_id)
);

-- Classes
CREATE TABLE classes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID REFERENCES schools(id) ON DELETE CASCADE NOT NULL,
  grade VARCHAR(50) NOT NULL,
  section VARCHAR(50) NOT NULL,
  academic_year VARCHAR(20) NOT NULL,
  class_teacher_id UUID REFERENCES teachers(id) ON DELETE SET NULL,
  capacity INTEGER DEFAULT 40,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(school_id, grade, section, academic_year)
);

-- Student Classes (students enrolled in classes)
CREATE TABLE student_classes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID REFERENCES students(id) ON DELETE CASCADE NOT NULL,
  class_id UUID REFERENCES classes(id) ON DELETE CASCADE NOT NULL,
  academic_year VARCHAR(20) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(student_id, class_id, academic_year)
);

-- Subjects
CREATE TABLE subjects (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID REFERENCES schools(id) ON DELETE CASCADE NOT NULL,
  name VARCHAR(200) NOT NULL,
  code VARCHAR(50) NOT NULL,
  description TEXT,
  grade_level VARCHAR(50),
  credit_hours INTEGER DEFAULT 1,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(school_id, code)
);

-- Teacher-Subject Assignment
CREATE TABLE teacher_subjects (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  teacher_id UUID REFERENCES teachers(id) ON DELETE CASCADE NOT NULL,
  subject_id UUID REFERENCES subjects(id) ON DELETE CASCADE NOT NULL,
  class_id UUID REFERENCES classes(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(teacher_id, subject_id, class_id)
);

-- Attendance
CREATE TABLE attendance (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID REFERENCES students(id) ON DELETE CASCADE NOT NULL,
  class_id UUID REFERENCES classes(id) ON DELETE CASCADE NOT NULL,
  subject_id UUID REFERENCES subjects(id) ON DELETE SET NULL,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  status attendance_status NOT NULL DEFAULT 'present',
  remarks TEXT,
  marked_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(student_id, class_id, date)
);

-- Exams
CREATE TABLE exams (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID REFERENCES schools(id) ON DELETE CASCADE NOT NULL,
  name VARCHAR(200) NOT NULL,
  type assessment_type NOT NULL DEFAULT 'quiz',
  subject_id UUID REFERENCES subjects(id) ON DELETE CASCADE NOT NULL,
  class_id UUID REFERENCES classes(id) ON DELETE CASCADE NOT NULL,
  term VARCHAR(50),
  total_marks DECIMAL(10,2) NOT NULL DEFAULT 100,
  passing_marks DECIMAL(10,2) NOT NULL DEFAULT 50,
  exam_date DATE,
  start_time TIME,
  end_time TIME,
  status VARCHAR(20) DEFAULT 'scheduled',
  created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Exam Results / Grades
CREATE TABLE exam_results (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  exam_id UUID REFERENCES exams(id) ON DELETE CASCADE NOT NULL,
  student_id UUID REFERENCES students(id) ON DELETE CASCADE NOT NULL,
  score DECIMAL(10,2) NOT NULL,
  grade VARCHAR(5),
  remarks TEXT,
  is_approved BOOLEAN DEFAULT FALSE,
  approved_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  approved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(exam_id, student_id)
);

-- Grade calculation helper
CREATE TYPE letter_grade AS ENUM ('A+', 'A', 'B+', 'B', 'C+', 'C', 'D', 'F');

-- Announcements
CREATE TABLE announcements (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID REFERENCES schools(id) ON DELETE CASCADE NOT NULL,
  title VARCHAR(300) NOT NULL,
  message TEXT NOT NULL,
  target audience NOT NULL DEFAULT 'all',
  class_id UUID REFERENCES classes(id) ON DELETE SET NULL,
  status VARCHAR(20) DEFAULT 'published',
  scheduled_at TIMESTAMPTZ,
  created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Notifications
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID REFERENCES schools(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  title VARCHAR(300) NOT NULL,
  message TEXT,
  type VARCHAR(50) DEFAULT 'info',
  icon_emoji VARCHAR(10),
  is_read BOOLEAN DEFAULT FALSE,
  link_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Audit Logs
CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID REFERENCES schools(id) ON DELETE CASCADE NOT NULL,
  actor_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  actor_role user_role,
  action VARCHAR(100) NOT NULL,
  entity_type VARCHAR(50) NOT NULL,
  entity_id UUID,
  details JSONB,
  ip_address VARCHAR(50),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- School Settings
CREATE TABLE school_settings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID REFERENCES schools(id) ON DELETE CASCADE UNIQUE NOT NULL,
  settings JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 4. INDEXES
-- ============================================================
CREATE INDEX idx_profiles_school_role ON profiles(school_id, role);
CREATE INDEX idx_profiles_email ON profiles(id);
CREATE INDEX idx_students_school ON students(school_id);
CREATE INDEX idx_students_user ON students(user_id);
CREATE INDEX idx_students_archived ON students(archived);
CREATE INDEX idx_teachers_school ON teachers(school_id);
CREATE INDEX idx_parents_school ON parents(school_id);
CREATE INDEX idx_classes_school ON classes(school_id);
CREATE INDEX idx_classes_teacher ON classes(class_teacher_id);
CREATE INDEX idx_student_classes_student ON student_classes(student_id);
CREATE INDEX idx_student_classes_class ON student_classes(class_id);
CREATE INDEX idx_subjects_school ON subjects(school_id);
CREATE INDEX idx_teacher_subjects_teacher ON teacher_subjects(teacher_id);
CREATE INDEX idx_teacher_subjects_subject ON teacher_subjects(subject_id);
CREATE INDEX idx_attendance_student ON attendance(student_id);
CREATE INDEX idx_attendance_date ON attendance(date);
CREATE INDEX idx_attendance_class_date ON attendance(class_id, date);
CREATE INDEX idx_exams_school ON exams(school_id);
CREATE INDEX idx_exam_results_exam ON exam_results(exam_id);
CREATE INDEX idx_exam_results_student ON exam_results(student_id);
CREATE INDEX idx_announcements_school ON announcements(school_id);
CREATE INDEX idx_notifications_user ON notifications(user_id, is_read);
CREATE INDEX idx_audit_logs_school ON audit_logs(school_id);
CREATE INDEX idx_audit_logs_actor ON audit_logs(actor_id);
CREATE INDEX idx_audit_logs_created ON audit_logs(created_at DESC);

-- ============================================================
-- 5. AUTO-UPDATE UPDATED_AT TRIGGERS
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_schools_updated_at BEFORE UPDATE ON schools FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER update_students_updated_at BEFORE UPDATE ON students FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER update_teachers_updated_at BEFORE UPDATE ON teachers FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER update_parents_updated_at BEFORE UPDATE ON parents FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER update_classes_updated_at BEFORE UPDATE ON classes FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER update_subjects_updated_at BEFORE UPDATE ON subjects FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER update_attendance_updated_at BEFORE UPDATE ON attendance FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER update_exams_updated_at BEFORE UPDATE ON exams FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER update_exam_results_updated_at BEFORE UPDATE ON exam_results FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER update_announcements_updated_at BEFORE UPDATE ON announcements FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER update_school_settings_updated_at BEFORE UPDATE ON school_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- 6. ROW LEVEL SECURITY POLICIES
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE schools ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE students ENABLE ROW LEVEL SECURITY;
ALTER TABLE teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE parents ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_parents ENABLE ROW LEVEL SECURITY;
ALTER TABLE classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE exams ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE school_settings ENABLE ROW LEVEL SECURITY;

-- Helper function: Get current user's school_id
CREATE OR REPLACE FUNCTION get_user_school_id()
RETURNS UUID AS $$
  SELECT school_id FROM profiles WHERE id = auth.uid();
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Helper function: Get current user's role
CREATE OR REPLACE FUNCTION get_user_role()
RETURNS user_role AS $$
  SELECT role FROM profiles WHERE id = auth.uid();
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Helper function: Check if user is admin of their school
CREATE OR REPLACE FUNCTION is_school_admin()
RETURNS BOOLEAN AS $$
  SELECT role IN ('admin', 'superadmin') FROM profiles WHERE id = auth.uid();
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- === SCHOOLS POLICY ===
CREATE POLICY "Users can view their own school"
  ON schools FOR SELECT
  USING (id = get_user_school_id() OR get_user_role() = 'superadmin');

CREATE POLICY "Superadmin can manage schools"
  ON schools FOR ALL
  USING (get_user_role() = 'superadmin');

-- === PROFILES POLICY ===
CREATE POLICY "Users can view profiles in their school"
  ON profiles FOR SELECT
  USING (school_id = get_user_school_id() OR id = auth.uid());

CREATE POLICY "Admins can manage profiles in their school"
  ON profiles FOR INSERT
  WITH CHECK (school_id = get_user_school_id() AND is_school_admin());

CREATE POLICY "Admins can update profiles in their school"
  ON profiles FOR UPDATE
  USING (school_id = get_user_school_id() AND is_school_admin())
  WITH CHECK (school_id = get_user_school_id() AND is_school_admin());

-- === STUDENTS POLICY ===
CREATE POLICY "View students in school"
  ON students FOR SELECT
  USING (school_id = get_user_school_id() OR get_user_role() = 'superadmin');

CREATE POLICY "Admin manages students"
  ON students FOR ALL
  USING (school_id = get_user_school_id() AND is_school_admin());

CREATE POLICY "Teachers view their class students"
  ON students FOR SELECT
  USING (
    school_id = get_user_school_id() 
    AND EXISTS (
      SELECT 1 FROM teacher_subjects ts
      JOIN student_classes sc ON sc.class_id = ts.class_id
      WHERE sc.student_id = students.id
      AND ts.teacher_id = (SELECT id FROM teachers WHERE user_id = auth.uid())
    )
  );

CREATE POLICY "Parents view their children"
  ON students FOR SELECT
  USING (
    school_id = get_user_school_id()
    AND EXISTS (
      SELECT 1 FROM student_parents sp
      JOIN parents p ON p.id = sp.parent_id
      WHERE sp.student_id = students.id
      AND p.user_id = auth.uid()
    )
  );

-- === TEACHERS POLICY ===
CREATE POLICY "View teachers in school"
  ON teachers FOR SELECT
  USING (school_id = get_user_school_id());

CREATE POLICY "Admin manages teachers"
  ON teachers FOR ALL
  USING (school_id = get_user_school_id() AND is_school_admin());

-- === PARENTS POLICY ===
CREATE POLICY "View parents in school"
  ON parents FOR SELECT
  USING (school_id = get_user_school_id());

CREATE POLICY "Admin manages parents"
  ON parents FOR ALL
  USING (school_id = get_user_school_id() AND is_school_admin());

-- === CLASSES POLICY ===
CREATE POLICY "View classes in school"
  ON classes FOR SELECT
  USING (school_id = get_user_school_id());

CREATE POLICY "Admin manages classes"
  ON classes FOR ALL
  USING (school_id = get_user_school_id() AND is_school_admin());

CREATE POLICY "Teachers view assigned classes"
  ON classes FOR SELECT
  USING (
    school_id = get_user_school_id()
    AND EXISTS (
      SELECT 1 FROM teacher_subjects 
      WHERE class_id = classes.id 
      AND teacher_id = (SELECT id FROM teachers WHERE user_id = auth.uid())
    )
  );

-- === SUBJECTS POLICY ===
CREATE POLICY "View subjects in school"
  ON subjects FOR SELECT
  USING (school_id = get_user_school_id());

CREATE POLICY "Admin manages subjects"
  ON subjects FOR ALL
  USING (school_id = get_user_school_id() AND is_school_admin());

-- === TEACHER_SUBJECTS POLICY ===
CREATE POLICY "View teacher_subjects in school"
  ON teacher_subjects FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM subjects s 
      JOIN schools sc ON sc.id = s.school_id
      WHERE s.id = teacher_subjects.subject_id 
      AND sc.id = get_user_school_id()
    )
  );

CREATE POLICY "Admin manages teacher_subjects"
  ON teacher_subjects FOR ALL
  USING (is_school_admin());

-- === ATTENDANCE POLICY ===
CREATE POLICY "View attendance"
  ON attendance FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM student_classes sc
      JOIN classes c ON c.id = sc.class_id
      WHERE sc.student_id = attendance.student_id
      AND c.school_id = get_user_school_id()
    )
  );

CREATE POLICY "Teachers mark attendance"
  ON attendance FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM teacher_subjects
      WHERE class_id = attendance.class_id
      AND teacher_id = (SELECT id FROM teachers WHERE user_id = auth.uid())
    )
  );

CREATE POLICY "Teachers update attendance"
  ON attendance FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM teacher_subjects
      WHERE class_id = attendance.class_id
      AND teacher_id = (SELECT id FROM teachers WHERE user_id = auth.uid())
    )
  );

-- === EXAMS POLICY ===
CREATE POLICY "View exams in school"
  ON exams FOR SELECT
  USING (school_id = get_user_school_id());

CREATE POLICY "Admin manages exams"
  ON exams FOR ALL
  USING (school_id = get_user_school_id() AND is_school_admin());

-- === EXAM RESULTS POLICY ===
CREATE POLICY "View exam results"
  ON exam_results FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM exams e
      JOIN classes c ON c.id = e.class_id
      WHERE e.id = exam_results.exam_id
      AND c.school_id = get_user_school_id()
    )
  );

CREATE POLICY "Teachers manage exam results"
  ON exam_results FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM exams e
      JOIN teacher_subjects ts ON ts.subject_id = e.subject_id
      WHERE e.id = exam_results.exam_id
      AND ts.teacher_id = (SELECT id FROM teachers WHERE user_id = auth.uid())
    )
  );

-- === ANNOUNCEMENTS POLICY ===
CREATE POLICY "View announcements in school"
  ON announcements FOR SELECT
  USING (school_id = get_user_school_id());

CREATE POLICY "Admin manages announcements"
  ON announcements FOR ALL
  USING (school_id = get_user_school_id() AND is_school_admin());

-- === NOTIFICATIONS POLICY ===
CREATE POLICY "Users view own notifications"
  ON notifications FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "System creates notifications"
  ON notifications FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Users update own notifications"
  ON notifications FOR UPDATE
  USING (user_id = auth.uid());

-- === AUDIT LOGS POLICY ===
CREATE POLICY "View audit logs in school"
  ON audit_logs FOR SELECT
  USING (school_id = get_user_school_id() AND is_school_admin());

CREATE POLICY "System creates audit logs"
  ON audit_logs FOR INSERT
  WITH CHECK (true);

-- === SCHOOL SETTINGS POLICY ===
CREATE POLICY "View settings"
  ON school_settings FOR SELECT
  USING (school_id = get_user_school_id());

CREATE POLICY "Admin manages settings"
  ON school_settings FOR ALL
  USING (school_id = get_user_school_id() AND is_school_admin());

-- ============================================================
-- 7. AUTO-CREATE PROFILE ON USER SIGNUP
-- ============================================================
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

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================
-- 8. AUTO AUDIT LOG FUNCTION
-- ============================================================
CREATE OR REPLACE FUNCTION create_audit_log(
  p_action VARCHAR,
  p_entity_type VARCHAR,
  p_entity_id UUID,
  p_details JSONB DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_school_id UUID;
  v_role user_role;
BEGIN
  SELECT school_id, role INTO v_school_id, v_role 
  FROM profiles WHERE id = auth.uid();
  
  INSERT INTO audit_logs (school_id, actor_id, actor_role, action, entity_type, entity_id, details)
  VALUES (v_school_id, auth.uid(), v_role, p_action, p_entity_type, p_entity_id, p_details)
  RETURNING id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 9. CREATE NOTIFICATION FUNCTION
-- ============================================================
CREATE OR REPLACE FUNCTION create_notification(
  p_user_id UUID,
  p_title VARCHAR,
  p_message TEXT DEFAULT NULL,
  p_type VARCHAR DEFAULT 'info',
  p_icon_emoji VARCHAR DEFAULT NULL,
  p_link_url TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_school_id UUID;
BEGIN
  SELECT school_id INTO v_school_id FROM profiles WHERE id = p_user_id;
  
  INSERT INTO notifications (school_id, user_id, title, message, type, icon_emoji, link_url)
  VALUES (v_school_id, p_user_id, p_title, p_message, p_type, p_icon_emoji, p_link_url)
  RETURNING id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 10. LETTER GRADE CALCULATION FUNCTION
-- ============================================================
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

-- Auto-calculate letter grade on insert/update
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

CREATE TRIGGER auto_calculate_grade_trigger
  BEFORE INSERT OR UPDATE ON exam_results
  FOR EACH ROW EXECUTE FUNCTION auto_calculate_grade();