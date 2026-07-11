from flask import Flask
from .database import init_db
from .middleware.auth import register_auth_middleware
from .routes import register_routes
from .config import Config

def create_app():
    from flask_cors import CORS

    app = Flask(__name__)
    # Enable CORS for API routes
    CORS(app, resources={r"/api/*": {"origins": "*"}})
    app.config.from_object(Config)  # load directly, no string import needed

    init_db(app)
    register_auth_middleware(app)
    register_routes(app)

    # Initialize Swagger UI
    from flasgger import Swagger
    swagger_config = {
        "headers": [],
        "specs": [
            {
                "endpoint": 'apispec_1',
                "route": '/apispec_1.json',
                "rule_filter": lambda rule: True,
                "model_filter": lambda tag: True,
            }
        ],
        "static_url_path": "/flasgger_static",
        "swagger_ui": True,
        "specs_route": "/apidocs/"
    }
    
    swagger_template = {
        "swagger": "2.0",
        "info": {
            "title": "School Management API",
            "description": "API Documentation for School Management System",
            "version": "1.0.0"
        },
        "securityDefinitions": {
            "Bearer": {
                "type": "apiKey",
                "name": "Authorization",
                "in": "header",
                "description": "JWT Authorization header using the Bearer scheme. Example: \"Bearer {token}\""
            }
        },
        "security": [
            {
                "Bearer": []
            }
        ]
    }
    Swagger(app, config=swagger_config, template=swagger_template)

    return app
