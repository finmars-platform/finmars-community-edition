from urllib.parse import urlparse, urljoin

from flask import Blueprint, request, redirect, url_for, session, flash, render_template
from community_edition.services.authentication import desired_next_url
from community_edition.services.env import load_env

env = load_env()

authentication = Blueprint("authentication", __name__)


@authentication.route("/login", methods=["GET", "POST"])
def login():
    auth_login = env.get("ADMIN_USERNAME")
    auth_password = env.get("ADMIN_PASSWORD")
    if not auth_login or not auth_password:
        flash(
            "Credentials are not configured. Set ADMIN_USERNAME and ADMIN_PASSWORD in .env.",
            "warning",
        )
        return redirect(url_for("setup"))

    next_param = request.args.get("next") or request.form.get("next_url")
    redirect_target = desired_next_url(next_param)

    if session.get("authenticated"):
        return redirect(redirect_target)


    if request.method == "POST":
        username = request.form.get("username", "").strip()
        password = request.form.get("password", "")
        if username == auth_login and password == auth_password:
            session["authenticated"] = True
            return redirect(redirect_target)
        flash("Invalid username or password.", "error")

    return render_template("login.html", next_url=redirect_target)
