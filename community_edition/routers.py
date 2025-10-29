from flask import Flask, jsonify, request, render_template, redirect, url_for, send_file
import subprocess
import os

from community_edition.services.env import load_env
from community_edition.services.setup import (
    get_setup_steps,
    load_state,
    save_state,
    append_log,
)
from community_edition.services.versions import (
    get_current_versions,
    get_latest_versions,
    set_versions_in_env,
)
from community_edition.services.backup import (
    get_backup_list,
    create_backup,
    delete_backup,
    restore_backup,
)
from community_edition.services.container import (
    down_containers,
    up_containers,
)


setup_steps = get_setup_steps()

app = Flask(__name__)


@app.route("/", methods=["GET", "POST"])
def setup():
    state = load_state()
    if request.method == "POST":
        step = request.form.get("step")
        if step == "generate_env" and state.get(step) == "pending":
            if 'backup_file' in request.files and (backup_file:=request.files['backup_file']).filename != '':
                os.makedirs(os.path.join(os.getcwd(), "tmp"), exist_ok=True)
                backup_path = os.path.join(os.getcwd(), "tmp", "backup.zip")
                backup_file.save(backup_path)
            else:
                state["restore_backup"] = "skip"

            inp = (
                "P\n"
                f"{request.form['DOMAIN']}\n"
                f"{request.form['AUTH_DOMAIN']}\n"
                f"{request.form['ADMIN_USERNAME']}\n"
                f"{request.form['ADMIN_PASSWORD']}\n"
            )
            proc = subprocess.run(
                setup_steps[0][1], input=inp, text=True, capture_output=True
            )
            append_log(setup_steps[0][2], proc.stdout, proc.stderr)
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
            set_versions_in_env()
            
            down_containers()
            up_containers()

            return jsonify({"success": True, "message": "Versions updated successfully. Containers restarted with new versions."})
        except Exception as e:
            return jsonify({"success": False, "message": str(e)}), 500

 
@app.route("/backup", methods=["GET", "POST", "PUT", "DELETE"])
def backup():
    if request.method == "GET":
        backups = get_backup_list()
        return render_template("backup.html", backups=backups)

    elif request.method == "POST":
        try:
            create_backup()
            return jsonify(
                {"success": True, "message": "Backup created successfully"}
            ), 200
        except Exception as e:
            return jsonify({"success": False, "message": str(e)}), 500

    elif request.method == "DELETE":
        data = request.get_json()
        timestamp = data.get("timestamp")
        if not timestamp:
            return jsonify({"success": False, "message": "Timestamp required"}), 400

        try:
            delete_backup(timestamp)
            return jsonify(
                {"success": True, "message": "Backup deleted successfully"}
            ), 200
        except Exception as e:
            return jsonify({"success": False, "message": str(e)}), 500


@app.route("/backup/<timestamp>/download")
def download_backup(timestamp):
    """Download a backup dump.zip file"""
    try:
        from community_edition.services.backup import BACKUP_DIR
        import os
        
        dump_file_path = os.path.join(BACKUP_DIR, timestamp, "dump.zip")
        
        if not os.path.exists(dump_file_path):
            return jsonify({"success": False, "message": "Backup file not found"}), 404
        
        return send_file(
            dump_file_path,
            as_attachment=True,
            download_name=f"backup_{timestamp}.zip",
            mimetype="application/zip"
        )
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@app.route("/backup/<timestamp>/restore", methods=["POST"])
def restore_backup_route(timestamp):
    """Restore a backup by stopping containers, running restore, and starting containers"""
    try:
        down_containers()
        
        create_backup()
        restore_backup(timestamp)
        
        up_containers()
        
        return jsonify({
            "success": True, 
            "message": f"Backup {timestamp} restored successfully. Containers stopped, backup restored, and containers restarted."
        }), 200
        
    except Exception as e:
        try:
            up_containers()
        except Exception as up_error:
            return jsonify({
                "success": False, 
                "message": f"Restore failed: {str(e)}. Additionally, failed to restart containers: {str(up_error)}"
            }), 500
        
        return jsonify({"success": False, "message": str(e)}), 500
