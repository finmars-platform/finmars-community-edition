import json
import os
import subprocess
import sys


STATE_FILE = ".init-setup-state.json"
LOG_FILE = "init-setup-log.txt"


def get_setup_steps() -> list[tuple[str, list[str], str]]:
    return [
        ("generate_env", ["make", "generate-env"], "Initial Settings"),
        ("init_cert", ["make", "init-cert"], "Request Certificates"),
        ("init_keycloak", ["make", "init-keycloak"], "Initializing Single-Sign-On"),
        ("docker_up", ["make", "up"], "Starting Services"),
    ]


def append_log(title: str, stdout: str, stderr: str) -> None:
    with open(LOG_FILE, "a") as logf:
        logf.write(f"\n\n### {title}\n")
        if stdout:
            logf.write(stdout)
        if stderr:
            logf.write(stderr)


# wrap to class
def save_state(state: dict[str, str]) -> None:
    with open(STATE_FILE, "w") as f:
        json.dump(state, f, indent=2)


def default_state() -> dict[str, str]:
    state = {step: "pending" for step, _, _ in get_setup_steps()}
    save_state(state)
    return state


def load_state() -> dict[str, str]:
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE) as f:
            return json.load(f)
    return default_state()


def disable_autostart() -> None:
    try:
        subprocess.run(["systemctl", "disable", "init-setup"], check=False)
        unit_path = "/etc/systemd/system/init-setup.service"
        if os.path.exists(unit_path):
            os.remove(unit_path)
        subprocess.run(["systemctl", "daemon-reload"], check=False)
    except Exception:
        pass
    try:
        subprocess.run(
            "(crontab -l | grep -v 'init-setup.py --run-step') | crontab -",
            shell=True,
            check=False,
        )
    except Exception:
        pass


def run_pending_step() -> None:
    state = load_state()
    print("[init-setup] Loaded state:", state)
    sys.stdout.flush()
    executed = False
    for step, cmd, title in get_setup_steps():
        if state.get(step) == "requested":
            executed = True
            state[step] = "in_progress"
            save_state(state)
            try:
                proc = subprocess.run(cmd, capture_output=True, text=True)
                append_log(title, proc.stdout, proc.stderr)
                state[step] = "done" if proc.returncode == 0 else "failed"
            except Exception as e:
                append_log(title, "", str(e))
                state[step] = "failed"
            save_state(state)

            if step == "docker_up":
                disable_autostart()

            # build a simple list of step names in order
            step_names = [name for name, _, _ in get_setup_steps()]

            # find where we just finished
            current_index = step_names.index(step)

            # look to see if there is a next one
            if current_index + 1 < len(step_names):
                next_step = step_names[current_index + 1]
                if state.get(next_step) == "pending":
                    state[next_step] = "requested"
                    save_state(state)

            if os.path.exists(LOG_FILE):
                with open(LOG_FILE) as logf:
                    print(logf.read())
            sys.stdout.flush()
            break

    if not executed:
        print("[init-setup] No requested steps found, nothing to run.")
        sys.stdout.flush()


if __name__ == "__main__":
    run_pending_step()
