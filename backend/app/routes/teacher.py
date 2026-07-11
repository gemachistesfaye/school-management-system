from flask import Blueprint, jsonify, request
from ..middleware.auth import rbac
from ..models import db, Student, Course, Grade, Attendance, Class

bp = Blueprint('teacher', __name__)

@bp.get('/dashboard')
@rbac(50)
def dashboard():
    return jsonify({"message": "Teacher dashboard"})

@bp.get('/students')
@rbac(50)
def get_students():
    """Get all students (for teacher to view)."""
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
            "gender": s.gender
        })
    return jsonify({"students": res})

@bp.get('/subjects')
@rbac(50)
def get_subjects():
    """Get all courses/subjects."""
    courses = Course.query.all()
    res = []
    for c in courses:
        res.append({
            "id": c.id,
            "name": c.name,
            "code": c.code,
            "teacher": c.teacher.name if c.teacher else '',
            "teacher_id": c.teacher_id
        })
    return jsonify({"subjects": res})

@bp.get('/classes')
@rbac(50)
def get_classes():
    """Get all classes."""
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

# ── Grades CRUD ──────────────────────────────────────────────────────

@bp.get('/grades')
@rbac(50)
def get_grades():
    """Get all grades."""
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
@rbac(50)
def add_grade():
    """Add a grade for a student."""
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
@rbac(50)
def delete_grade(id):
    """Delete a grade."""
    g = Grade.query.get(id)
    if g:
        db.session.delete(g)
        db.session.commit()
    return jsonify({"message": "Deleted"}), 200

# ── Attendance ───────────────────────────────────────────────────────

@bp.get('/attendance')
@rbac(50)
def get_attendance():
    """Get attendance records."""
    date_str = request.args.get('date')
    from datetime import datetime, date
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
@rbac(50)
def mark_attendance():
    """Mark/bulk update attendance."""
    from datetime import datetime
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
