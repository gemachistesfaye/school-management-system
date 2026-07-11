from flask import request, jsonify, g
from functools import wraps
from ..utils.security import decode_token

ROLE_LEVEL = {
    'superadmin': 100,
    'admin': 80,
    'teacher': 50,
    'student': 10,
    'parent': 10,
}

def register_auth_middleware(app):
    @app.before_request
    def load_user():
        exempt = ["/api/auth/login", "/api/health", "/apidocs", "/apispec_1", "/flasgger_static"]
        if any(request.path.startswith(p) for p in exempt):
            return

        auth = request.headers.get("Authorization", "")
        if not auth.startswith("Bearer "):
            return jsonify({"error": "Missing Bearer token"}), 401
        token = auth.split()[1]
        try:
            payload = decode_token(token)
            g.user_id = payload["sub"]
            g.role = payload["role"]
            g.role_level = payload["level"]
        except PermissionError as e:
            return jsonify({"error": str(e)}), 401

def rbac(min_level: int):
    def decorator(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            if getattr(g, "role_level", 0) < min_level:
                return jsonify({"error": "Forbidden - insufficient role"}), 403
            return fn(*args, **kwargs)
        return wrapper
    return decorator
