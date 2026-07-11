from flask import Blueprint, request, jsonify
from ..models import User
from ..utils.security import verify_password, create_access_token

bp = Blueprint('auth', __name__)

@bp.post('/login')
def login():
    """
    User Login
    ---
    tags:
      - Authentication
    summary: Authenticate user and get access token
    parameters:
      - in: body
        name: body
        required: true
        schema:
          type: object
          required:
            - email
            - password
          properties:
            email:
              type: string
              example: admin@school.com
            password:
              type: string
              example: StrongPass!23
            portal:
              type: string
              example: staff
    responses:
      200:
        description: Successful login
        schema:
          type: object
          properties:
            access_token:
              type: string
            role:
              type: string
      401:
        description: Invalid credentials
      403:
        description: Access denied for portal
    """
    data = request.json
    email = data.get('email')
    pwd = data.get('password')
    portal = data.get('portal', 'staff')
    
    user = User.query.filter_by(email=email).first()
    if not user or not verify_password(pwd, user.password_hash):
        return jsonify({"error": "Invalid credentials"}), 401

    role = user.role.name
    
    if portal == 'staff':
        if role not in ['superadmin', 'school_director', 'teacher', 'staff']:
            return jsonify({"error": "Access denied. Please use the Student or Parent portal."}), 403
    elif portal == 'student':
        if role != 'student':
            return jsonify({"error": "Access denied. This portal is for students only."}), 403
    elif portal == 'parent':
        if role != 'parent':
            return jsonify({"error": "Access denied. This portal is for parents only."}), 403

    token = create_access_token(user.id, user.role.name, user.role.level)
    return jsonify({"access_token": token, "role": user.role.name})
