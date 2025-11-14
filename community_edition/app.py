from flask import Flask, request, session

from community_edition.routers.authentication import authentication
from community_edition.routers.configurate import configurate
from community_edition.services.authentication import redirect_to_login
from community_edition.services.env import load_env


def create_app() -> Flask:
    app = Flask(__name__)
    env = load_env()
    app.secret_key = env.get("FLASK_SECRET_KEY") or "finmars-secret-key"
    app.register_blueprint(configurate)
    app.register_blueprint(authentication)

    @app.before_request
    def require_basic_auth():
        allowlisted_endpoints = {"configurate.setup", "authentication.login", "static"}

        if request.endpoint in allowlisted_endpoints or request.endpoint is None:
            return

        env = load_env()
        auth_login = env.get("ADMIN_USERNAME")
        auth_password = env.get("ADMIN_PASSWORD")
        if not auth_login or not auth_password:
            return

        if session.get("authenticated"):
            return

        if request.authorization:
            auth = request.authorization
            if auth.username == auth_login and auth.password == auth_password:
                session["authenticated"] = True
                return

        return redirect_to_login()

    return app
