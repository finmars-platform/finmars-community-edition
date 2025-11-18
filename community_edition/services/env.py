import os

ENV_FILE = ".env"


def load_env() -> dict[str, str]:
    env: dict[str, str] = {}
    if not os.path.exists(ENV_FILE):
        return env

    with open(ENV_FILE) as f:
        for line in f:
            line_stripped = line.strip()
            if not line_stripped or line_stripped.startswith("#"):
                continue
            key, value = line_stripped.split("=", 1)
            env[key] = value.strip().strip('"').strip("'").strip()
    return env
