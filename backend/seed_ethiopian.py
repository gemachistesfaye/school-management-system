"""Seed the database with Ethiopian-based sample data.
20 students, 10 teachers, parents, classes (Grade 1-10), and subjects.
"""
import os, sys, time
from datetime import date

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from backend.app.database import db
from backend.app import create_app
from backend.app.models import School, Class, Teacher, Student, Course, Profile, Role, User
from backend.app.utils.security import hash_password

app = create_app()

ETH_MALE = [
    "Abebe", "Kebede", "Lemma", "Tesfaye", "Girma", "Hailu", "Dawit",
    "Tadesse", "Bekele", "Yohannes", "Worku", "Alemu", "Dereje", "Getachew",
    "Mulugeta", "Fikru", "Solomon", "Biruk", "Nahom", "Ermias"
]
ETH_FEMALE = [
    "Tigist", "Almaz", "Hiwot", "Sara", "Bethlehem", "Meron", "Kidist",
    "Selam", "Rahel", "Alem", "Tsion", "Yeshi", "Nardos", "Birtukan",
    "Meseret", "Firehiwot", "Aster", "Liya", "Mahlet", "Eden"
]
ETH_LAST = [
    "Tesfaye", "Bekele", "Tadesse", "Kebede", "Haile", "Mengistu", "Wolde",
    "Gebre", "Debebe", "Assefa", "Mekonnen", "Abera", "Desta", "Negash",
    "Ayele", "Tessema", "Kassa", "Eshete", "Bogale", "Worku"
]

SUBJECTS = [
    ("Amharic", "AMH101"), ("English", "ENG101"), ("Mathematics", "MAT101"),
    ("Physics", "PHY101"), ("Chemistry", "CHM101"), ("Biology", "BIO101"),
    ("History", "HIS101"), ("Geography", "GEO101"), ("Civics", "CIV101"),
    ("ICT", "ICT101")
]


def seed():
    with app.app_context():
        # ── Wipe old data ────────────────────────────────────────────
        print("Dropping old data...")
        Student.query.delete()
        Course.query.delete()
        Teacher.query.delete()
        Class.query.delete()
        db.session.commit()

        # ── School ───────────────────────────────────────────────────
        school = School.query.first()
        if not school:
            school = School(name="Haramaya Academy", location="Harar, Ethiopia")
            db.session.add(school)
            db.session.commit()
        else:
            school.name = "Haramaya Academy"
            school.location = "Harar, Ethiopia"
            db.session.commit()

        # ── Roles ────────────────────────────────────────────────────
        parent_role = Role.query.filter_by(name='parent').first()
        if not parent_role:
            parent_role = Role(name='parent', level=10)
            db.session.add(parent_role)
            db.session.flush()

        student_role = Role.query.filter_by(name='student').first()
        if not student_role:
            student_role = Role(name='student', level=10)
            db.session.add(student_role)
            db.session.flush()
        db.session.commit()

        # ── Classes (Grade 1–10, section A) ──────────────────────────
        classes = []
        for g in range(1, 11):
            cls = Class(class_name=f"Grade {g}", section="A", academic_year="2025/2026")
            db.session.add(cls)
            classes.append(cls)
        db.session.commit()

        # ── Teachers (10) ────────────────────────────────────────────
        teachers = []
        for i, (subj_name, subj_code) in enumerate(SUBJECTS):
            fname = ETH_MALE[i] if i < 7 else ETH_FEMALE[i - 7]
            lname = ETH_LAST[i]
            full = f"{fname} {lname}"
            email = f"{fname.lower()}.{lname.lower()}@school.com"
            phone = f"+2519{10+i:02d}{100+i*11:04d}"
            t = Teacher(
                name=full, subject=subj_name, email=email, phone=phone,
                hire_date=date(2018 + (i % 5), 9, 1)
            )
            db.session.add(t)
            teachers.append(t)
        db.session.commit()

        # ── Courses / Subjects (10) ──────────────────────────────────
        for i, (subj_name, subj_code) in enumerate(SUBJECTS):
            c = Course(
                name=subj_name, code=subj_code,
                school_id=school.id, teacher_id=teachers[i].id
            )
            db.session.add(c)
        db.session.commit()

        # ── Parents (20) + Students (20) ─────────────────────────────
        for i in range(20):
            gender = "Male" if i < 12 else "Female"
            fname = ETH_MALE[i] if gender == "Male" else ETH_FEMALE[i - 12]
            lname = ETH_LAST[i]
            student_name = f"{fname} {lname}"

            # Parent
            p_first = ETH_MALE[(i + 5) % 20] if i % 2 == 0 else ETH_FEMALE[(i + 3) % 20]
            p_last = ETH_LAST[(i + 7) % 20]
            parent_name = f"{p_first} {p_last}"

            p_email = f"parent_{p_first.lower()}_{int(time.time()) + i}@school.com"
            p_user = User(email=p_email, password_hash=hash_password(f"{p_first.lower()}2026"), role_id=parent_role.id, must_change_password=True)
            db.session.add(p_user)
            db.session.flush()

            p_profile = Profile(user_id=p_user.id, full_name=parent_name, school_id=school.id)
            db.session.add(p_profile)
            db.session.flush()

            # Student
            s_email = f"{fname.lower()}.{lname.lower()}@school.com"
            s_user = User(email=s_email, password_hash=hash_password(f"{fname.lower()}123"), role_id=student_role.id, must_change_password=True)
            db.session.add(s_user)
            db.session.flush()

            s_profile = Profile(user_id=s_user.id, full_name=student_name, school_id=school.id, parent_id=p_profile.id)
            db.session.add(s_profile)
            db.session.flush()

            cls = classes[i % 10]
            grade_num = ''.join(filter(str.isdigit, cls.class_name)) or '1'
            student = Student(
                student_id=f"{i+1:04d}/{grade_num}",
                name=student_name,
                gender=gender,
                date_of_birth=date(2008 + (i % 6), 1 + (i % 12), 1 + (i % 28)),
                class_id=cls.id,
                phone=f"+2519{20+i:02d}{200+i*7:04d}",
                parent_id=p_profile.id
            )
            db.session.add(student)

        db.session.commit()
        print("✅ Ethiopian seed data created: 10 classes, 10 teachers, 10 subjects, 20 parents, 20 students.")


if __name__ == "__main__":
    seed()
