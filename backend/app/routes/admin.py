from flask import Blueprint, jsonify, request, send_file
from ..middleware.auth import rbac
from ..models import db, Student, Profile, Role, School, Class, User, Course, Teacher, Attendance, Grade, Fee, Exam
from ..utils.security import hash_password
import pandas as pd
import io
import csv
import time
from datetime import datetime, date
bp = Blueprint('admin', __name__)

@bp.post('/bulk-import/teachers')
@rbac(80)
def bulk_import_teachers():
    """Upload an Excel/CSV containing teacher rows.
    Expected columns: email, full_name, subject, school_name
    Generates a temporary password: <lowercase_firstname>123
    """
    file = request.files.get('excel')
    if not file:
        return jsonify(error='No file provided'), 400
    try:
        df = pd.read_excel(file)
    except Exception as e:
        return jsonify(error='Failed to read file'), 400

    created = 0
    errors = []
    for idx, row in df.iterrows():
        try:
            # Basic validation
            email = str(row.get('email')).strip()
            name = str(row.get('full_name')).strip()
            subject = str(row.get('subject')).strip()
            school_name = str(row.get('school_name')).strip()
            if not email or not name or not subject:
                raise ValueError('Missing required fields')

            # Get or create school
            school = School.query.filter_by(name=school_name).first()
            if not school:
                school = School(name=school_name, location='')
                db.session.add(school)
                db.session.flush()

            # Role
            teacher_role = Role.query.filter_by(name='teacher').first()
            if not teacher_role:
                teacher_role = Role(name='teacher', level=30)
                db.session.add(teacher_role)
                db.session.flush()

            # Temporary password and email based on requirement
            email = f"{name.replace(' ', '').lower()}@school.com"
            first_name = name.split()[0].lower()
            temp_password = f"{first_name}123"
            pwd_hash = hash_password(temp_password)

            # User
            user = User(email=email, password_hash=pwd_hash,
                        role_id=teacher_role.id, school_id=school.id,
                        must_change_password=True)
            db.session.add(user)
            db.session.flush()

            # Profile
            profile = Profile(user_id=user.id, full_name=name, school_id=school.id)
            db.session.add(profile)

            # Teacher record
            teacher = Teacher(name=name, subject=subject, email=email, school_id=school.id)
            db.session.add(teacher)
            created += 1
        except Exception as e:
            errors.append(f"Row {idx+2}: {str(e)}")
    db.session.commit()
    return jsonify(created_teachers=created, errors=errors), 200

@bp.post('/bulk-import/students')
@rbac(80)
def bulk_import_students():
    """Upload an Excel/CSV containing student rows with parent info.
    Expected columns: email, full_name, gender, date_of_birth, class_name, school_name,
                      parent_name, parent_email
    Temporary password: <lowercase_firstname>123
    """
    file = request.files.get('excel')
    if not file:
        return jsonify(error='No file provided'), 400
    try:
        df = pd.read_excel(file)
    except Exception as e:
        return jsonify(error='Failed to read file'), 400

    created_students = 0
    created_parents = 0
    errors = []
    for idx, row in df.iterrows():
        try:
            email = str(row.get('email')).strip()
            name = str(row.get('full_name')).strip()
            gender = str(row.get('gender')).strip()
            dob = row.get('date_of_birth')
            class_name = str(row.get('class_name')).strip()
            school_name = str(row.get('school_name')).strip()
            parent_name = str(row.get('parent_name')).strip()
            parent_email = str(row.get('parent_email')).strip()
            if not all([email, name, gender, dob, class_name, school_name, parent_name, parent_email]):
                raise ValueError('Missing required fields')

            # School
            school = School.query.filter_by(name=school_name).first()
            if not school:
                school = School(name=school_name, location='')
                db.session.add(school)
                db.session.flush()

            # Ensure student role
            student_role = Role.query.filter_by(name='student').first()
            if not student_role:
                student_role = Role(name='student', level=10)
                db.session.add(student_role)
                db.session.flush()

            # Ensure parent role
            parent_role = Role.query.filter_by(name='parent').first()
            if not parent_role:
                parent_role = Role(name='parent', level=10)
                db.session.add(parent_role)
                db.session.flush()

            # Create (or fetch) parent user
            if not parent_email or parent_email == 'nan':
                 parent_email = f"parent_{int(time.time())}{idx}@school.com"
            parent_user = User.query.filter_by(email=parent_email).first()
            if not parent_user:
                first_parent = parent_name.split()[0].lower()
                current_year = datetime.utcnow().year
                parent_pwd = f"{first_parent}{current_year}"
                parent_user = User(email=parent_email,
                                   password_hash=hash_password(parent_pwd),
                                   role_id=parent_role.id,
                                   school_id=school.id,
                                   must_change_password=True)
                db.session.add(parent_user)
                db.session.flush()
                parent_profile = Profile(user_id=parent_user.id,
                                         full_name=parent_name,
                                         school_id=school.id)
                db.session.add(parent_profile)
                db.session.flush()
                created_parents += 1
            else:
                parent_profile = Profile.query.filter_by(user_id=parent_user.id).first()
                if not parent_profile:
                    parent_profile = Profile(user_id=parent_user.id,
                                             full_name=parent_name,
                                             school_id=school.id)
                    db.session.add(parent_profile)
                    db.session.flush()

            # Temporary password and email for student
            first_student = name.split()[0].lower()
            student_pwd = f"{first_student}123"
            email = f"{name.replace(' ', '').lower()}@school.com"
            
            student_user = User(email=email,
                                password_hash=hash_password(student_pwd),
                                role_id=student_role.id,
                                school_id=school.id,
                                must_change_password=True)
            db.session.add(student_user)
            db.session.flush()

            # Profile for student
            student_profile = Profile(user_id=student_user.id,
                                      full_name=name,
                                      school_id=school.id,
                                      parent_id=parent_profile.id)
            db.session.add(student_profile)
            db.session.flush()

            # Class handling
            grade_str = ''.join(filter(str.isdigit, class_name))
            grade_val = grade_str if grade_str else '1'
            formatted_class_name = f"Grade {grade_val}"
            
            section_val = str(row.get('section')).strip()
            if not section_val or section_val == 'nan':
                section_val = 'A'
            
            cls = Class.query.filter_by(class_name=formatted_class_name, section=section_val).first()
            if not cls:
                cls = Class(class_name=formatted_class_name, section=section_val, academic_year=f'{datetime.utcnow().year}/{datetime.utcnow().year+1}')
                db.session.add(cls)
                db.session.flush()

            # Student record and ID generation
            count = Student.query.join(Class).filter(Class.class_name == formatted_class_name).count()
            new_num = count + 1 # count includes already committed, but what about current transaction?
            # To be safe for bulk insert without flush every time for count:
            # We can query max ID or just use a loop counter but since we add one by one, count might be stale if not flushed.
            # Actually, we can just do flush after each student.
            student_id = f"{new_num:04d}/{grade_val}"

            student = Student(student_id=student_id,
                              name=name,
                              gender=gender,
                              date_of_birth=dob,
                              class_id=cls.id,
                              parent_id=parent_profile.id)
            db.session.add(student)
            created_students += 1
        except Exception as e:
            errors.append(f"Row {idx+2}: {str(e)}")
    db.session.commit()
    return jsonify(created_students=created_students,
                   created_parents=created_parents,
                   errors=errors), 200

@bp.get('/dashboard')
@rbac(80)
def dashboard():
    return jsonify({"message": "Admin dashboard"})

@bp.get('/school-metrics')
@rbac(80)
def school_metrics():
    """
    Dashboard Metrics
    ---
    tags:
      - Dashboard
    summary: Get school statistics and aggregated metrics
    security:
      - Bearer: []
    responses:
      200:
        description: Dashboard metrics including student count, attendance rate, etc.
    """
    try:
        students_count = Student.query.count()
        teachers_count = Teacher.query.count()
        classes_count = Class.query.count()
        
        # Count parents (users with parent role)
        parent_role = Role.query.filter_by(name='parent').first()
        parents_count = User.query.filter_by(role_id=parent_role.id).count() if parent_role else 0
        
        # Attendance rate (last 30 days)
        today = date.today()
        thirty_days_ago = date(today.year, today.month - 1, today.day) if today.month > 1 else date(today.year - 1, 12, today.day)
        total_attendance = Attendance.query.filter(Attendance.date >= thirty_days_ago).count()
        present_attendance = Attendance.query.filter(Attendance.date >= thirty_days_ago, Attendance.status == 'Present').count()
        attendance_rate = round((present_attendance / total_attendance * 100), 1) if total_attendance > 0 else 0
        
        # Fee collection
        total_fees = db.session.query(db.func.sum(Fee.amount)).scalar() or 0
        paid_fees = db.session.query(db.func.sum(Fee.paid_amount)).scalar() or 0
        
        # Subjects count
        subjects_count = Course.query.count()
        
        return jsonify({
            "students": students_count,
            "teachers": teachers_count,
            "classes": classes_count,
            "parents": parents_count,
            "attendance_rate": f"{attendance_rate}%",
            "subjects": subjects_count,
            "fees_collected": f"{paid_fees:,.2f}",
            "total_fees": f"{total_fees:,.2f}"
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@bp.get('/reports/<string:report_type>')
@rbac(80)
def generate_report(report_type):
    """Generate CSV reports for various data types."""
    try:
        output = io.StringIO()
        writer = csv.writer(output)
        
        if report_type == 'students':
            writer.writerow(['Student ID', 'Name', 'Gender', 'DOB', 'Class', 'Phone', 'Enrollment Date'])
            students = Student.query.all()
            for s in students:
                writer.writerow([s.student_id, s.name, s.gender, s.date_of_birth, 
                               s.class_.class_name if s.class_ else '', s.phone, s.enrollment_date])
            filename = 'students-report.csv'
            
        elif report_type == 'attendance':
            writer.writerow(['Student ID', 'Student Name', 'Date', 'Status'])
            records = Attendance.query.all()
            for r in records:
                writer.writerow([r.student.student_id if r.student else '', 
                               r.student.name if r.student else '', r.date, r.status])
            filename = 'attendance-report.csv'
            
        elif report_type == 'teachers':
            writer.writerow(['Name', 'Subject', 'Email', 'Phone', 'Hire Date'])
            teachers = Teacher.query.all()
            for t in teachers:
                writer.writerow([t.name, t.subject, t.email, t.phone, t.hire_date])
            filename = 'teachers-report.csv'
            
        elif report_type == 'classes':
            writer.writerow(['Class Name', 'Section', 'Academic Year', 'Students'])
            classes = Class.query.all()
            for c in classes:
                count = Student.query.filter_by(class_id=c.id).count()
                writer.writerow([c.class_name, c.section, c.academic_year, count])
            filename = 'classes-report.csv'
            
        elif report_type == 'academic':
            writer.writerow(['Student ID', 'Student Name', 'Subject', 'Exam Type', 'Score', 'Total'])
            grades = Grade.query.all()
            for g in grades:
                writer.writerow([g.student.student_id if g.student else '',
                               g.student.name if g.student else '', 
                               g.subject if hasattr(g, 'subject') else 'N/A',
                               g.exam_type, g.score, g.total_marks])
            filename = 'academic-report.csv'
            
        elif report_type == 'financial':
            writer.writerow(['Student ID', 'Student Name', 'Amount', 'Paid', 'Status', 'Due Date'])
            fees = Fee.query.all()
            for f in fees:
                writer.writerow([f.student.student_id if f.student else '',
                               f.student.name if f.student else '',
                               f.amount, f.paid_amount, f.status, f.due_date])
            filename = 'financial-report.csv'
            
        else:
            return jsonify({"error": "Invalid report type"}), 400
        
        output.seek(0)
        return send_file(
            io.BytesIO(output.getvalue().encode('utf-8-sig')),
            mimetype='text/csv',
            as_attachment=True,
            download_name=filename
        )
    except Exception as e:
        return jsonify({"error": f"Report generation failed: {str(e)}"}), 500

@bp.get('/parents')
@rbac(80)
def get_parents():
    parent_role = Role.query.filter_by(name='parent').first()
    if not parent_role:
        return jsonify({"parents": []})
    parent_user_ids = [u.id for u in User.query.filter_by(role_id=parent_role.id).all()]
    profiles = Profile.query.filter(Profile.user_id.in_(parent_user_ids)).all()
    res = []
    for p in profiles:
        children_count = Student.query.filter_by(parent_id=p.id).count()
        children = Student.query.filter_by(parent_id=p.id).all()
        res.append({
            "id": p.id,
            "name": p.full_name,
            "email": p.user.email if p.user else '',
            "children": children_count,
            "student_names": [c.name for c in children]
        })
    return jsonify({"parents": res})

@bp.get('/subjects')
@rbac(80)
def get_subjects():
    """
    List all subjects
    ---
    tags:
      - Subjects
    summary: Retrieve all courses/subjects
    security:
      - Bearer: []
    responses:
      200:
        description: List of subjects
    """
    courses = Course.query.all()
    res = []
    for c in courses:
        res.append({
            "id": c.id,
            "name": c.name,
            "code": c.code,
            "teacher": c.teacher.name if c.teacher else '',
            "teacher_id": c.teacher_id,
            "school_id": c.school_id,
            "stream": c.stream or ''
        })
    return jsonify({"subjects": res})

@bp.post('/subjects')
@rbac(80)
def add_subject():
    data = request.json
    name = data.get('name')
    code = data.get('code')
    teacher_id = data.get('teacher_id')
    school_id = data.get('school_id', 1)
    stream = data.get('stream')

    if not all([name, code]):
        return jsonify({"error": "Missing name or code"}), 400

    try:
        course = Course(
            name=name,
            code=code,
            teacher_id=teacher_id if teacher_id else None,
            school_id=school_id,
            stream=stream if stream in ('natural', 'social') else None
        )
        db.session.add(course)
        db.session.commit()
        return jsonify({"message": "Subject created"}), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": str(e)}), 500

@bp.delete('/subjects/<int:id>')
@rbac(80)
def delete_subject(id):
    c = Course.query.get(id)
    if c:
        db.session.delete(c)
        db.session.commit()
    return jsonify({"message": "Deleted"}), 200

@bp.get('/exams')
@rbac(80)
def get_exams():
    exams = Exam.query.all()
    res = []
    for e in exams:
        res.append({
            "id": e.id,
            "name": e.exam_name,
            "date": str(e.exam_date),
            "year": e.academic_year
        })
    return jsonify({"exams": res})

@bp.post('/exams')
@rbac(80)
def add_exam():
    data = request.json
    exam = Exam(
        exam_name=data.get('name'),
        exam_date=datetime.strptime(data.get('date'), '%Y-%m-%d').date(),
        academic_year=data.get('year', f'{datetime.utcnow().year}/{datetime.utcnow().year+1}')
    )
    db.session.add(exam)
    db.session.commit()
    return jsonify({"message": "Exam created"}), 201

@bp.delete('/exams/<int:id>')
@rbac(80)
def delete_exam(id):
    e = Exam.query.get(id)
    if e:
        db.session.delete(e)
        db.session.commit()
    return jsonify({"message": "Deleted"}), 200

@bp.get('/attendance')
@rbac(80)
def get_attendance():
    """
    Get Attendance
    ---
    tags:
      - Attendance
    summary: Retrieve daily attendance records
    security:
      - Bearer: []
    parameters:
      - in: query
        name: date
        type: string
        description: Date in YYYY-MM-DD format (defaults to today)
        required: false
    responses:
      200:
        description: List of attendance records
    """
    date_str = request.args.get('date')
    query_date = datetime.strptime(date_str, '%Y-%m-%d').date() if date_str else date.today()
    records = Attendance.query.filter_by(date=query_date).all()
    res = []
    for r in records:
        res.append({
            "id": r.id,
            "student_id": r.student_id,
            "student_name": r.student.name if r.student else '',
            "date": str(r.date),
            "status": r.status,
            "class_name": r.student.class_.class_name if r.student and r.student.class_ else ''
        })
    return jsonify({"attendance": res})

@bp.post('/attendance')
@rbac(80)
def mark_attendance():
    data = request.json
    records = data.get('records', [])
    count = 0
    for rec in records:
        existing = Attendance.query.filter_by(
            student_id=rec.get('student_id'),
            date=datetime.strptime(rec.get('date'), '%Y-%m-%d').date()
        ).first()
        if existing:
            existing.status = rec.get('status', 'Present')
        else:
            att = Attendance(
                student_id=rec.get('student_id'),
                date=datetime.strptime(rec.get('date'), '%Y-%m-%d').date(),
                status=rec.get('status', 'Present')
            )
            db.session.add(att)
        count += 1
    db.session.commit()
    return jsonify({"message": f"{count} attendance records saved"}), 200

@bp.get('/grades')
@rbac(80)
def get_grades():
    """
    Get Grades
    ---
    tags:
      - Grades
    summary: Retrieve all student grades
    security:
      - Bearer: []
    responses:
      200:
        description: List of grades
    """
    grades = Grade.query.all()
    res = []
    for g in grades:
        res.append({
            "id": g.id,
            "student_id": g.student_id,
            "student_name": g.student.name if g.student else '',
            "course_id": g.course_id,
            "course_name": g.course.name if g.course else '',
            "exam_type": g.exam_type,
            "score": g.score,
            "total_marks": g.total_marks
        })
    return jsonify({"grades": res})

@bp.post('/grades')
@rbac(80)
def add_grade():
    """
    Add a grade for a student
    ---
    tags:
      - Grades
    summary: Create a new grade record
    security:
      - Bearer: []
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          properties:
            student_id:
              type: integer
            course_id:
              type: integer
            exam_type:
              type: string
              enum: [Quiz, Mid, Final]
            score:
              type: number
            total_marks:
              type: number
    responses:
      201:
        description: Grade created
    """
    data = request.json
    student_id = data.get('student_id')
    course_id = data.get('course_id')
    exam_type = data.get('exam_type')
    score = data.get('score')
    total_marks = data.get('total_marks')

    if not all([student_id, course_id, exam_type, score is not None, total_marks]):
        return jsonify({"error": "Missing required fields"}), 400

    if exam_type not in ('Quiz', 'Mid', 'Final'):
        return jsonify({"error": "Invalid exam type. Must be Quiz, Mid, or Final"}), 400

    try:
        grade = Grade(
            student_id=student_id,
            course_id=course_id,
            exam_type=exam_type,
            score=float(score),
            total_marks=float(total_marks)
        )
        db.session.add(grade)
        db.session.commit()
        return jsonify({"message": "Grade created successfully"}), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": str(e)}), 500

@bp.delete('/grades/<int:id>')
@rbac(80)
def delete_grade(id):
    g = Grade.query.get(id)
    if g:
        db.session.delete(g)
        db.session.commit()
    return jsonify({"message": "Deleted"}), 200

@bp.post('/cascade-register')
@rbac(80)
def cascade_register():
    """
    Register new student with parent
    ---
    tags:
      - Registration
    summary: Create a student and parent profile at once
    security:
      - Bearer: []
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          properties:
            student:
              type: object
              properties:
                name:
                  type: string
                  example: Jane Doe
                email:
                  type: string
                  example: jane@student.school.com
            parent:
              type: object
              properties:
                name:
                  type: string
                  example: John Doe
                email:
                  type: string
                  example: john@parent.school.com
    responses:
      201:
        description: Registration successful
      400:
        description: Invalid payload
    """
    data = request.json
    if not data or 'student' not in data or 'parent' not in data:
        return jsonify({"error": "Invalid payload"}), 400
    student_data = data['student']
    parent_data = data['parent']
    # Basic validation
    if not all(k in student_data for k in ("email", "name")) or not all(k in parent_data for k in ("email", "name")):
        return jsonify({"error": "Missing fields"}), 400
    try:
        # Ensure parent role exists
        parent_role = Role.query.filter_by(name='parent').first()
        if not parent_role:
            parent_role = Role(name='parent', level=10)
            db.session.add(parent_role)
            db.session.flush()
        # Create a user for parent (optional, could be just profile)
        pwd_hash = hash_password('default-pass')  # you may want a generated password
        
        # Simpler: create profile directly without a user (since parent may not log in)
        # Create parent profile
        parent_profile = Profile(full_name=parent_data['name'], school_id=1)  # assuming admin's school_id=1
        db.session.add(parent_profile)
        db.session.flush()
        # Create student profile (optional) then student record
        # For now we just create Student record linking to parent_profile.id
        # Generate a simple student_id
        student_id = f"STU{int(datetime.utcnow().timestamp())}"  # unique-ish
        student = Student(student_id=student_id, name=student_data['name'], gender='Other', date_of_birth=date(2000, 1, 1), class_id=1, parent_id=parent_profile.id)
        db.session.add(student)
        db.session.commit()
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": str(e)}), 500
    return jsonify({"message": f"Student {student.name} and parent {parent_profile.full_name} created"}), 201

@bp.get('/students')
@rbac(80)
def get_students():
    """
    Get all students
    ---
    tags:
      - Students
    summary: List all enrolled students
    security:
      - Bearer: []
    responses:
      200:
        description: List of students
    """
    students = Student.query.all()
    res = []
    for s in students:
        res.append({
            "id": s.id,
            "name": s.name,
            "student_id": s.student_id,
            "class_id": s.class_id,
            "class_name": s.class_.class_name if s.class_ else '',
            "section": s.class_.section if s.class_ else '',
            "gender": s.gender,
            "date_of_birth": str(s.date_of_birth) if s.date_of_birth else '',
            "phone": s.phone or '',
            "address": s.address or '',
            "enrollment_date": str(s.enrollment_date) if s.enrollment_date else '',
            "parent_id": s.parent_id
        })
    return jsonify({"students": res})

@bp.post('/students')
@rbac(80)
def add_student():
    """
    Add a single student
    ---
    tags:
      - Students
    summary: Register a new student and parent profile
    security:
      - Bearer: []
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          properties:
            name:
              type: string
              example: Timmy
            parent_name:
              type: string
              example: Timmy's Dad
            class_id:
              type: integer
              example: 1
            gender:
              type: string
              example: Male
            date_of_birth:
              type: string
              example: 2010-05-12
    responses:
      201:
        description: Student created successfully
    """
    data = request.json
    name = data.get('name')
    parent_name = data.get('parent_name')
    class_id = data.get('class_id')
    gender = data.get('gender')
    dob_str = data.get('date_of_birth')
    dob = date(2010, 1, 1)  # safe default
    if dob_str and isinstance(dob_str, str):
        try:
            dob = datetime.strptime(dob_str, '%Y-%m-%d').date()
        except ValueError:
            pass
    elif isinstance(dob_str, date):
        dob = dob_str
    
    if not all([name, parent_name, class_id]):
        return jsonify({"error": "Missing name, parent_name, or class"}), 400

    try:
        current_year = datetime.utcnow().year

        cls = Class.query.get(class_id)
        if not cls:
            return jsonify({"error": "Invalid class selected"}), 400

        class_name = cls.class_name
        grade_str = ''.join(filter(str.isdigit, class_name))
        grade_val = grade_str if grade_str else '1'

        # Generate Student ID: e.g. 0001/9
        count = Student.query.join(Class).filter(Class.class_name == class_name).count()
        new_num = count + 1
        student_id = f"{new_num:04d}/{grade_val}"

        # Get or create default school
        school = School.query.first()
        if not school:
            school = School(name='Default School', location='')
            db.session.add(school)
            db.session.flush()
        sid = school.id

        # Parent User & Profile
        parent_role = Role.query.filter_by(name='parent').first()
        if not parent_role:
            parent_role = Role(name='parent', level=10)
            db.session.add(parent_role)
            db.session.flush()
        
        parent_first = parent_name.split()[0].lower()
        parent_username = f"{parent_first}_{int(time.time())}@school.com"
        parent_pwd = hash_password(f"{parent_first}{current_year}")

        parent_user = User(email=parent_username, password_hash=parent_pwd, role_id=parent_role.id, school_id=sid, must_change_password=True)
        db.session.add(parent_user)
        db.session.flush()

        parent_profile = Profile(user_id=parent_user.id, full_name=parent_name, school_id=sid)
        db.session.add(parent_profile)
        db.session.flush()

        # Student User & Profile
        student_role = Role.query.filter_by(name='student').first()
        if not student_role:
            student_role = Role(name='student', level=10)
            db.session.add(student_role)
            db.session.flush()

        student_first = name.split()[0].lower()
        student_username = f"{name.replace(' ', '').lower()}_{int(time.time())}@school.com"
        student_pwd = hash_password(f"{student_first}123")

        student_user = User(email=student_username, password_hash=student_pwd, role_id=student_role.id, school_id=sid, must_change_password=True)
        db.session.add(student_user)
        db.session.flush()

        student_profile = Profile(user_id=student_user.id, full_name=name, school_id=sid, parent_id=parent_profile.id)
        db.session.add(student_profile)
        db.session.flush()

        # Student Record
        student = Student(student_id=student_id, name=name, gender=gender, date_of_birth=dob, class_id=cls.id, parent_id=parent_profile.id)
        db.session.add(student)
        db.session.commit()

        return jsonify({"message": "Student created successfully", "student_id": student_id}), 201

    except Exception as e:
        db.session.rollback()
        return jsonify({"error": str(e)}), 500

@bp.get('/classes')
@rbac(80)
def get_classes():
    classes = Class.query.all()
    res = []
    for c in classes:
        count = Student.query.filter_by(class_id=c.id).count()
        res.append({
            "id": c.id,
            "class_name": c.class_name,
            "section": c.section,
            "academic_year": c.academic_year,
            "student_count": count
        })
    return jsonify({"classes": res})

@bp.post('/classes')
@rbac(80)
def add_class():
    data = request.json
    c_name = data.get('class_name')
    c_section = data.get('section')
    c_year = data.get('academic_year')
    if not all([c_name, c_section, c_year]):
        return jsonify({"error": "Missing fields"}), 400
    try:
        cls = Class(class_name=c_name, section=c_section, academic_year=c_year)
        db.session.add(cls)
        db.session.commit()
        return jsonify({"message": "Class created"}), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": str(e)}), 500

@bp.delete('/classes/<int:id>')
@rbac(80)
def delete_class(id):
    cls = Class.query.get(id)
    if cls:
        db.session.delete(cls)
        db.session.commit()
    return jsonify({"message": "Deleted"}), 200

@bp.get('/teachers')
@rbac(80)
def get_teachers():
    teachers = Teacher.query.all()
    res = []
    for t in teachers:
        res.append({
            "id": t.id,
            "name": t.name,
            "email": t.email,
            "subject": t.subject,
            "phone": t.phone,
            "hire_date": str(t.hire_date) if t.hire_date else None
        })
    return jsonify({"teachers": res})

@bp.post('/teachers')
@rbac(80)
def add_teacher():
    data = request.json
    name = data.get('name')
    email = data.get('email')
    subject = data.get('subject')
    phone = data.get('phone')
    hire_date = data.get('hire_date')

    if not all([name, email, subject]):
        return jsonify({"error": "Missing required fields"}), 400

    try:
        current_year = datetime.utcnow().year

        # Get or create default school
        school = School.query.first()
        if not school:
            school = School(name='Default School', location='')
            db.session.add(school)
            db.session.flush()
        sid = school.id
        
        teacher_role = Role.query.filter_by(name='teacher').first()
        if not teacher_role:
            teacher_role = Role(name='teacher', level=30)
            db.session.add(teacher_role)
            db.session.flush()
        
        first_name = name.split()[0].lower()
        email = f"{name.replace(' ', '').lower()}_{int(time.time())}@school.com"
        teacher_pwd = hash_password(f"{first_name}123")

        teacher_user = User(email=email, password_hash=teacher_pwd, role_id=teacher_role.id, school_id=sid, must_change_password=True)
        db.session.add(teacher_user)
        db.session.flush()

        teacher_profile = Profile(user_id=teacher_user.id, full_name=name, school_id=sid)
        db.session.add(teacher_profile)
        db.session.flush()

        t_date = datetime.strptime(hire_date, '%Y-%m-%d').date() if hire_date else datetime.utcnow().date()
        teacher = Teacher(name=name, email=email, subject=subject, phone=phone, hire_date=t_date)
        db.session.add(teacher)
        db.session.commit()

        return jsonify({"message": "Teacher created successfully"}), 201

    except Exception as e:
        db.session.rollback()
        return jsonify({"error": str(e)}), 500

@bp.delete('/teachers/<int:id>')
@rbac(80)
def delete_teacher(id):
    t = Teacher.query.get(id)
    if t:
        db.session.delete(t)
        db.session.commit()
    return jsonify({"message": "Deleted"}), 200

@bp.delete('/students/<int:id>')
@rbac(80)
def delete_student(id):
    """
    Delete a student
    ---
    tags:
      - Students
    summary: Remove a student by ID
    security:
      - Bearer: []
    parameters:
      - in: path
        name: id
        type: integer
        required: true
    responses:
      200:
        description: Deleted successfully
    """
    s = Student.query.get(id)
    if s:
        db.session.delete(s)
        db.session.commit()
    return jsonify({"message": "Deleted"}), 200

@bp.put('/students/<int:id>')
@rbac(80)
def edit_student(id):
    """
    Update a student
    ---
    tags:
      - Students
    summary: Modify a student by ID
    security:
      - Bearer: []
    parameters:
      - in: path
        name: id
        type: integer
        required: true
      - in: body
        name: body
        required: true
        schema:
          type: object
          properties:
            name:
              type: string
    responses:
      200:
        description: Student updated
    """
    s = Student.query.get(id)
    if not s:
        return jsonify({"error": "Not found"}), 404
    data = request.json
    if 'name' in data: s.name = data['name']
    if 'phone' in data: s.phone = data['phone']
    if 'address' in data: s.address = data['address']
    if 'gender' in data: s.gender = data['gender']
    if 'date_of_birth' in data:
        dob_val = data['date_of_birth']
        if isinstance(dob_val, str):
            try:
                s.date_of_birth = datetime.strptime(dob_val, '%Y-%m-%d').date()
            except ValueError:
                pass
        elif isinstance(dob_val, date):
            s.date_of_birth = dob_val
    if 'class_id' in data: s.class_id = data['class_id']
    try:
        db.session.commit()
        return jsonify({"message": "Student updated"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": str(e)}), 500

@bp.put('/teachers/<int:id>')
@rbac(80)
def edit_teacher(id):
    t = Teacher.query.get(id)
    if not t: return jsonify({"error": "Not found"}), 404
    data = request.json
    if 'name' in data: t.name = data['name']
    if 'subject' in data: t.subject = data['subject']
    if 'phone' in data: t.phone = data['phone']
    if 'email' in data: t.email = data['email']
    if 'hire_date' in data:
        t.hire_date = datetime.strptime(data['hire_date'], '%Y-%m-%d').date() if data['hire_date'] else t.hire_date
    try:
        db.session.commit()
        return jsonify({"message": "Teacher updated"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": str(e)}), 500

@bp.put('/classes/<int:id>')
@rbac(80)
def edit_class(id):
    c = Class.query.get(id)
    if not c: return jsonify({"error": "Not found"}), 404
    data = request.json
    if 'class_name' in data: c.class_name = data['class_name']
    if 'section' in data: c.section = data['section']
    if 'academic_year' in data: c.academic_year = data['academic_year']
    try:
        db.session.commit()
        return jsonify({"message": "Class updated"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": str(e)}), 500

# ── Parents CRUD ─────────────────────────────────────────────────────────

@bp.post('/parents')
@rbac(80)
def add_parent():
    data = request.json
    name = data.get('name')
    email = data.get('email')
    phone = data.get('phone')
    if not name:
        return jsonify({"error": "Missing name"}), 400
    try:
        school = School.query.first()
        if not school:
            school = School(name='Default School', location='')
            db.session.add(school)
            db.session.flush()
        sid = school.id

        parent_role = Role.query.filter_by(name='parent').first()
        if not parent_role:
            parent_role = Role(name='parent', level=10)
            db.session.add(parent_role)
            db.session.flush()

        p_email = email or f"{name.replace(' ','').lower()}_{int(time.time())}@school.com"
        pwd = hash_password(f"{name.split()[0].lower()}2026")
        user = User(email=p_email, password_hash=pwd, role_id=parent_role.id, school_id=sid, must_change_password=True)
        db.session.add(user)
        db.session.flush()

        profile = Profile(user_id=user.id, full_name=name, school_id=sid)
        db.session.add(profile)
        db.session.commit()
        return jsonify({"message": "Parent created successfully"}), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": str(e)}), 500

@bp.put('/parents/<int:id>')
@rbac(80)
def edit_parent(id):
    p = Profile.query.get(id)
    if not p: return jsonify({"error": "Not found"}), 404
    data = request.json
    if 'name' in data: p.full_name = data['name']
    if 'email' in data and p.user:
        p.user.email = data['email']
    try:
        db.session.commit()
        return jsonify({"message": "Parent updated"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": str(e)}), 500

@bp.delete('/parents/<int:id>')
@rbac(80)
def delete_parent(id):
    p = Profile.query.get(id)
    if p:
        db.session.delete(p)
        db.session.commit()
    return jsonify({"message": "Deleted"}), 200

# ── Subjects Edit ────────────────────────────────────────────────────────

@bp.put('/subjects/<int:id>')
@rbac(80)
def edit_subject(id):
    c = Course.query.get(id)
    if not c: return jsonify({"error": "Not found"}), 404
    data = request.json
    if 'name' in data: c.name = data['name']
    if 'code' in data: c.code = data['code']
    if 'teacher_id' in data: c.teacher_id = data['teacher_id']
    if 'stream' in data: c.stream = data['stream'] if data['stream'] in ('natural', 'social') else None
    try:
        db.session.commit()
        return jsonify({"message": "Subject updated"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": str(e)}), 500

# ── Export CSV Endpoints ─────────────────────────────────────────────────

@bp.get('/export/students')
@rbac(80)
def export_students():
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(['Student ID', 'Name', 'Gender', 'Date of Birth', 'Class', 'Phone', 'Parent'])
    for s in Student.query.all():
        writer.writerow([
            s.student_id, s.name, s.gender,
            str(s.date_of_birth) if s.date_of_birth else '',
            s.class_.class_name if s.class_ else '',
            s.phone or '',
            s.parent.full_name if s.parent else ''
        ])
    output.seek(0)
    return send_file(io.BytesIO(output.getvalue().encode('utf-8-sig')),
                     mimetype='text/csv', as_attachment=True, download_name='students.csv')

@bp.get('/export/teachers')
@rbac(80)
def export_teachers():
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(['Name', 'Email', 'Subject', 'Phone', 'Hire Date'])
    for t in Teacher.query.all():
        writer.writerow([t.name, t.email, t.subject, t.phone or '', str(t.hire_date) if t.hire_date else ''])
    output.seek(0)
    return send_file(io.BytesIO(output.getvalue().encode('utf-8-sig')),
                     mimetype='text/csv', as_attachment=True, download_name='teachers.csv')

@bp.get('/export/parents')
@rbac(80)
def export_parents():
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(['Name', 'Email', 'Children Count'])
    profiles = Profile.query.filter(Profile.parent_id.is_(None)).all()
    for p in profiles:
        children = Student.query.filter_by(parent_id=p.id).count()
        writer.writerow([p.full_name, p.user.email if p.user else '', children])
    output.seek(0)
    return send_file(io.BytesIO(output.getvalue().encode('utf-8-sig')),
                     mimetype='text/csv', as_attachment=True, download_name='parents.csv')

@bp.get('/export/classes')
@rbac(80)
def export_classes():
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(['Class Name', 'Section', 'Academic Year', 'Student Count'])
    for c in Class.query.all():
        count = Student.query.filter_by(class_id=c.id).count()
        writer.writerow([c.class_name, c.section, c.academic_year, count])
    output.seek(0)
    return send_file(io.BytesIO(output.getvalue().encode('utf-8-sig')),
                     mimetype='text/csv', as_attachment=True, download_name='classes.csv')

@bp.get('/export/subjects')
@rbac(80)
def export_subjects():
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(['Name', 'Code', 'Teacher'])
    for c in Course.query.all():
        writer.writerow([c.name, c.code, c.teacher.name if c.teacher else ''])
    output.seek(0)
    return send_file(io.BytesIO(output.getvalue().encode('utf-8-sig')),
                     mimetype='text/csv', as_attachment=True, download_name='subjects.csv')

