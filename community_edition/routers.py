from flask import Flask, jsonify, request, render_template, redirect, url_for
import subprocess

from community_edition.services.env import load_env, update_versions_in_env
from community_edition.services.setup import (
    get_setup_steps,
    load_state,
    save_state,
    append_log,
)
from community_edition.services.versions import (
    get_current_versions,
    get_latest_versions,
    restart_containers,
    VERSION_MAPPING,
)

app = Flask(__name__)


@app.route("/", methods=["GET", "POST"])
def setup():
    state = load_state()
    if request.method == "POST":
        step = request.form.get("step")
        if step == "generate_env" and state.get(step) == "pending":
            inp = (
                "P\n"
                f"{request.form['DOMAIN']}\n"
                f"{request.form['AUTH_DOMAIN']}\n"
                f"{request.form['ADMIN_USERNAME']}\n"
                f"{request.form['ADMIN_PASSWORD']}\n"
            )
            proc = subprocess.run(
                get_setup_steps()[0][1], input=inp, text=True, capture_output=True
            )
            append_log(get_setup_steps()[0][2], proc.stdout, proc.stderr)
            state["generate_env"] = "done" if proc.returncode == 0 else "failed"
            save_state(state)

            step_names = [name for name, _, _ in get_setup_steps()]

            current_index = step_names.index(step)

            if current_index + 1 < len(step_names):
                next_step = step_names[current_index + 1]
                if state.get(next_step) == "pending":
                    state[next_step] = "requested"
                    save_state(state)

            return redirect(url_for("setup"))
        if step in state and state[step] == "pending":
            state[step] = "requested"
            save_state(state)
        return redirect(url_for("setup"))

    logs = subprocess.run(
        ["docker", "compose", "logs"], capture_output=True, text=True
    ).stdout
    for step, _, title in get_setup_steps():
        status = state.get(step)
        if step == "generate_env" and status == "pending":
            return render_template("form.html")
        if status in ("requested", "in_progress", "pending"):
            return render_template("status.html", title=title, logs=logs, status=status)

    env = load_env()
    domain_name = env["DOMAIN_NAME"]
    return render_template("success.html", domain=domain_name)


@app.route("/versions", methods=["GET", "PUT"])
def versions():
    if request.method == "GET":
        current_versions = get_current_versions()
        latest_versions = get_latest_versions()

        version_data = {}
        for env_var, data in current_versions.items():
            app_name = data["app_name"]
            version_data[env_var] = {
                "app_name": app_name,
                "current_version": data["current_version"],
                "latest_version": latest_versions.get(app_name, ""),
                "env_var": env_var,
                "needs_update": data["current_version"]
                != latest_versions.get(app_name, "")
                and latest_versions.get(app_name, "") != "",
            }

        return render_template("versions.html", versions=version_data)

    elif request.method == "PUT":
        try:
            current_versions = get_current_versions()
            latest_versions = get_latest_versions()
            if not latest_versions:
                return jsonify(
                    {"success": False, "message": "Failed to fetch latest versions"}
                ), 500

            updates_needed = False
            for env_var, data in current_versions.items():
                app_name = data["app_name"]
                current_version = data["current_version"]
                latest_version = latest_versions.get(app_name, "")
                if current_version != latest_version and latest_version != "":
                    updates_needed = True
                    break

            if not updates_needed:
                return jsonify(
                    {
                        "success": False,
                        "message": "No updates available. All components are already up to date.",
                    }
                ), 400

            version_updates = {}
            for env_var, app_name in VERSION_MAPPING.items():
                if app_name in latest_versions:
                    version_updates[env_var] = latest_versions[app_name]

            success, message = update_versions_in_env(version_updates)
            if not success:
                return jsonify({"success": False, "message": message}), 500

            restart_success, restart_message = restart_containers()
            if not restart_success:
                return jsonify(
                    {
                        "success": False,
                        "message": f"Versions updated but failed to restart containers: {restart_message}",
                    }
                ), 500

            return jsonify(
                {"success": True, "message": f"{message}. {restart_message}"}
            )

        except Exception as e:
            return jsonify({"success": False, "message": f"Error: {str(e)}"}), 500
