import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from backend.app.database import db
from backend.app import create_app
from backend.app.models import School, Student, Teacher, User, Profile, Role
from backend.app.utils.security import hash_password

app = create_app()

def fix_users_and_profiles():
    with app.app_context():
        # Ensure student and teacher roles exist
        student_role = Role.query.filter_by(name='student').first()
        if not student_role:
            student_role = Role(name='student', level=10)
            db.session.add(student_role)
            
        teacher_role = Role.query.filter_by(name='teacher').first()
        if not teacher_role:
            teacher_role = Role(name='teacher', level=50)
            db.session.add(teacher_role)
            
        db.session.commit()

        # Add users for all students
        students = Student.query.all()
        for s in students:
            # Check if profile already exists for this student name (approximate)
            if not Profile.query.filter_by(full_name=s.name).first():
                # school_id based on student ID to distribute evenly
                school_id = (s.id % 5) + 1
                
                user = User(
                    email=f"{s.student_id.lower()}@student.school.com", 
                    password_hash=hash_password("Pass123"), 
                    role_id=student_role.id,
                    school_id=school_id
                )
                db.session.add(user)
                db.session.flush() # get user ID
                
                profile = Profile(user_id=user.id, full_name=s.name, school_id=school_id)
                db.session.add(profile)
        
        # Add users for all teachers
        teachers = Teacher.query.all()
        for t in teachers:
            if not Profile.query.filter_by(full_name=t.name).first():
                user = User(
                    email=t.email or f"{t.name.replace(' ', '').lower()}@teacher.school.com", 
                    password_hash=hash_password("Pass123"), 
                    role_id=teacher_role.id,
                    school_id=1 # fallback
                )
                db.session.add(user)
                db.session.flush()
                
                profile = Profile(user_id=user.id, full_name=t.name, school_id=1)
                db.session.add(profile)

        db.session.commit()
        print("Successfully generated User and Profile records for all students and teachers!")

if __name__ == "__main__":
    fix_users_and_profiles()
