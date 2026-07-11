import os
import sys
from datetime import datetime, date

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from backend.app.database import db
from backend.app import create_app
from backend.app.models import School, Class, Teacher, Student, Course

app = create_app()

def seed_data():
    with app.app_context():
        # Check if already seeded
        if School.query.first():
            print("Data already seeded.")
            return

        print("Seeding dummy data...")

        # Create School
        school = School(name="Springfield Elementary", location="123 Main St, Springfield")
        db.session.add(school)
        db.session.commit()

        # Create Class
        cls = Class(class_name="Grade 10", section="A", academic_year="2023/2024")
        db.session.add(cls)
        db.session.commit()

        # Create Teachers
        teacher1 = Teacher(name="Edna Krabappel", subject="History", email="edna@school.com", hire_date=date(2010, 5, 1))
        teacher2 = Teacher(name="Dewey Largo", subject="Music", email="dewey@school.com", hire_date=date(2012, 8, 15))
        db.session.add_all([teacher1, teacher2])
        db.session.commit()

        # Create Courses
        course1 = Course(name="World History 101", code="WH101", school_id=school.id, teacher_id=teacher1.id)
        course2 = Course(name="Music Theory", code="MT101", school_id=school.id, teacher_id=teacher2.id)
        db.session.add_all([course1, course2])
        db.session.commit()

        # Create Students
        students = [
            Student(student_id="STU001", name="Bart Simpson", gender="Male", date_of_birth=date(2010, 4, 1), class_id=cls.id, phone="555-0101"),
            Student(student_id="STU002", name="Lisa Simpson", gender="Female", date_of_birth=date(2012, 5, 9), class_id=cls.id, phone="555-0102"),
            Student(student_id="STU003", name="Milhouse Van Houten", gender="Male", date_of_birth=date(2010, 7, 1), class_id=cls.id, phone="555-0103"),
            Student(student_id="STU004", name="Nelson Muntz", gender="Male", date_of_birth=date(2009, 10, 31), class_id=cls.id, phone="555-0104"),
            Student(student_id="STU005", name="Ralph Wiggum", gender="Male", date_of_birth=date(2011, 2, 14), class_id=cls.id, phone="555-0105"),
        ]
        db.session.add_all(students)
        db.session.commit()

        print("Successfully added dummy data!")

if __name__ == "__main__":
    seed_data()
