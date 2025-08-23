from flask import Flask, request, render_template_string, redirect, url_for, render_template
import subprocess, os, sys, json, argparse, time

app = Flask(__name__)

STATE_FILE = '.init-setup-state.json'
LOG_FILE = 'init-setup-log.txt'
ENV_FILE = ".env"

# Define steps and associated commands and titles
def get_setup_steps():
    return [
        ('generate_env', ['make', 'generate-env'], 'Initial Settings'),
        ('init_cert', ['make', 'init-cert'], 'Request Certificates'),
        ('init_keycloak', ['make', 'init-keycloak'], 'Initializing Single-Sign-On'),
        ('docker_up', ['make', 'up'], 'Starting Services')
    ]

# State management
def default_state():
    state = { step: 'pending' for step, _, _ in get_setup_steps() }
    save_state(state)
    return state

def load_state():
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE) as f:
            return json.load(f)
    return default_state()

def load_env():
    env = {}
    # 1. Open the .env file
    with open(ENV_FILE) as f:
        for line in f:
            line = line.strip()            # remove spaces and newline
            if not line or line.startswith("#"):
                continue                   # skip blanks or comments
            key, value = line.split("=", 1)
            env[key] = value.strip().strip('"').strip("'")
    return env


def save_state(state):
    with open(STATE_FILE, 'w') as f:
        json.dump(state, f, indent=2)

# Logging helper
def append_log(title, stdout, stderr):
    with open(LOG_FILE, 'a') as logf:
        logf.write(f"\n\n### {title}\n")
        if stdout: logf.write(stdout)
        if stderr: logf.write(stderr)

# Autostart disable (systemd + cron)
def disable_autostart():
    try:
        subprocess.run(['systemctl', 'disable', 'init-setup'], check=False)
        unit_path = '/etc/systemd/system/init-setup.service'
        if os.path.exists(unit_path): os.remove(unit_path)
        subprocess.run(['systemctl', 'daemon-reload'], check=False)
    except Exception:
        pass
    try:
        subprocess.run("(crontab -l | grep -v 'init-setup.py --run-step') | crontab -", shell=True, check=False)
    except Exception:
        pass

# Runner: background run one pending requested step
def run_pending_step():
    state = load_state()
    print("[init-setup] Loaded state:", state)
    sys.stdout.flush()
    executed = False
    for step, cmd, title in get_setup_steps():

        if state.get(step) == 'requested':

            executed = True
            state[step] = 'in_progress'
            save_state(state)
            try:
                proc = subprocess.run(cmd, capture_output=True, text=True)
                append_log(title, proc.stdout, proc.stderr)
                state[step] = 'done' if proc.returncode == 0 else 'failed'
            except Exception as e:
                append_log(title, '', str(e))
                state[step] = 'failed'
            save_state(state)

            if step == 'docker_up':
                disable_autostart()

            # build a simple list of step names in order
            step_names = [name for name, _, _ in get_setup_steps()]

            # find where we just finished
            current_index = step_names.index(step)

            # look to see if there is a next one
            if current_index + 1 < len(step_names):
                next_step = step_names[current_index + 1]
                if state.get(next_step) == 'pending':
                    state[next_step] = 'requested'
                    save_state(state)

            if os.path.exists(LOG_FILE):
                with open(LOG_FILE) as logf:
                    print(logf.read())
            sys.stdout.flush()
            break


    if not executed:
        print("[init-setup] No requested steps found, nothing to run.")
        sys.stdout.flush()

# Flask routes
@app.route('/', methods=['GET','POST'])
def setup():
    state = load_state()
    if request.method == 'POST':
        step = request.form.get('step')
        if step == 'generate_env' and state.get(step) == 'pending':
            inp = (
                "P\n"
                f"{request.form['DOMAIN']}\n"
                f"{request.form['AUTH_DOMAIN']}\n"
                f"{request.form['ADMIN_USERNAME']}\n"
                f"{request.form['ADMIN_PASSWORD']}\n"
            )
            proc = subprocess.run(get_setup_steps()[0][1], input=inp, text=True, capture_output=True)
            append_log(get_setup_steps()[0][2], proc.stdout, proc.stderr)
            state['generate_env'] = 'done' if proc.returncode == 0 else 'failed'
            save_state(state)

            # build a simple list of step names in order
            step_names = [name for name, _, _ in get_setup_steps()]

            # find where we just finished
            current_index = step_names.index(step)

            # look to see if there is a next one
            if current_index + 1 < len(step_names):
                next_step = step_names[current_index + 1]
                if state.get(next_step) == 'pending':
                    state[next_step] = 'requested'
                    save_state(state)

            return redirect(url_for('setup'))
        if step in state and state[step] == 'pending':
            state[step] = 'requested'
            save_state(state)
        return redirect(url_for('setup'))

    logs = subprocess.run(['docker', 'compose', 'logs'], capture_output=True, text=True).stdout
    for step, _, title in get_setup_steps():
        status = state.get(step)
        if step == 'generate_env' and status == 'pending':
                return render_template("form.html")
        if status in ('requested','in_progress', 'pending'):
            return render_template("status.html", title=title, logs=logs, status=status)

    env = load_env()
    domain_name = env["DOMAIN_NAME"]
    return render_template("success.html", domain=domain_name)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--run-step', action='store_true')
    args = parser.parse_args()
    if args.run_step:
        run_pending_step()
    else:
        if os.path.exists(LOG_FILE): os.remove(LOG_FILE)
        app.run(host='0.0.0.0', port=8888)
