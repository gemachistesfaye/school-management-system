import os
import sys
import random
from datetime import datetime, date, timedelta

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from backend.app.database import db
from backend.app import create_app
from backend.app.models import School, Class, Teacher, Student, Course

app = create_app()

def seed_large_data():
    with app.app_context():
        print("Seeding 5 branches and 230 users...")

        # Create 5 Branches (Schools)
        schools = []
        for i in range(1, 6):
            branch_name = f"Springfield Branch {i}"
            school = School.query.filter_by(name=branch_name).first()
            if not school:
                school = School(name=branch_name, location=f"{100 * i} Main St, City {i}")
                db.session.add(school)
                db.session.commit()
            schools.append(school)

        print(f"Ensured {len(schools)} branches exist.")

        # Create 1 Class per school for simplicity
        classes = []
        for i, school in enumerate(schools):
            class_name = f"Grade {10 + i}"
            cls = Class.query.filter_by(class_name=class_name, section="A").first()
            if not cls:
                cls = Class(class_name=class_name, section="A", academic_year="2023/2024")
                db.session.add(cls)
                db.session.commit()
            classes.append(cls)

        # Create 30 Teachers total across branches
        existing_teachers = Teacher.query.count()
        teachers_to_add = max(0, 30 - existing_teachers)
        if teachers_to_add > 0:
            teachers = []
            for i in range(teachers_to_add):
                t = Teacher(
                    name=f"Teacher {existing_teachers + i + 1}", 
                    subject=random.choice(["Math", "Science", "History", "English", "Art"]),
                    email=f"teacher{existing_teachers + i + 1}@school.com",
                    hire_date=date(2015 + random.randint(0, 8), random.randint(1, 12), random.randint(1, 28))
                )
                teachers.append(t)
            db.session.add_all(teachers)
            db.session.commit()
            print(f"Added {teachers_to_add} teachers.")

        # Create 200 Students total across branches
        existing_students = Student.query.count()
        students_to_add = max(0, 200 - existing_students)
        if students_to_add > 0:
            students = []
            for i in range(students_to_add):
                s = Student(
                    student_id=f"STU{1000 + existing_students + i}",
                    name=f"Student Name {existing_students + i + 1}",
                    gender=random.choice(["Male", "Female"]),
                    date_of_birth=date(2008 + random.randint(0, 4), random.randint(1, 12), random.randint(1, 28)),
                    class_id=random.choice(classes).id,
                    phone=f"555-{random.randint(1000, 9999)}"
                )
                students.append(s)
            
            db.session.add_all(students)
            db.session.commit()
            print(f"Added {students_to_add} students.")

        print("Successfully seeded large dataset!")

if __name__ == "__main__":
    seed_large_data()
