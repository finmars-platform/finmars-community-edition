import json
import subprocess
from typing import Any, Final

from .backup import PROJECT_DIR

ADD_KEYCLOAK_USER_CMD: Final[list[str]] = ["make", "add-user"]
LIST_KEYCLOAK_USERS_CMD: Final[list[str]] = ["make", "list-users"]


def add_keycloak_user(username: str, password: str) -> str:
    username = username.strip()
    if not username or not password:
        raise ValueError("Username and password are required.")

    cmd = [*ADD_KEYCLOAK_USER_CMD, f"USERNAME={username}", f"PASSWORD={password}"]

    result = subprocess.run(
        cmd,
        check=False,
        capture_output=True,
        text=True,
        cwd=PROJECT_DIR,
    )

    stdout = result.stdout or ""
    stderr = result.stderr or ""
    combined_output = stdout + (f"\n{stderr}" if stderr else "")

    if result.returncode != 0:
        raise RuntimeError(
            f"Failed to add Keycloak user via CLI.\nCommand: {' '.join(cmd)}\nOutput:\n{combined_output}".strip()
        )

    return combined_output.strip()


def list_keycloak_users() -> list[dict[str, Any]]:
    """
    Return parsed list of users from `make list-users`, which calls the list-keycloak-users.sh helper.
    """
    result = subprocess.run(
        LIST_KEYCLOAK_USERS_CMD,
        check=False,
        capture_output=True,
        text=True,
        cwd=PROJECT_DIR,
    )

    if result.returncode != 0:
        stdout = result.stdout or ""
        stderr = result.stderr or ""
        combined_output = stdout + (f"\n{stderr}" if stderr else "")
        raise RuntimeError(
            "Failed to list Keycloak users via CLI.\n"
            f"Command: {' '.join(LIST_KEYCLOAK_USERS_CMD)}\n"
            f"Output:\n{combined_output}".strip()
        )

    raw = (result.stdout or "").strip()
    if not raw:
        return []

    # Sometimes Make prints the invoked command before JSON, e.g.
    # "./scripts/list-keycloak-users.sh [ { ... } ]"
    # Strip everything before the first '[' so we only parse the JSON array.
    start_idx = raw.find("[")
    if start_idx == -1:  # pragma: no cover - defensive
        raise RuntimeError(f"Unexpected Keycloak users output, JSON array not found:\n{raw}")

    json_str = raw[start_idx:]
    try:
        data = json.loads(json_str)
    except json.JSONDecodeError as exc:  # pragma: no cover - defensive
        raise RuntimeError(f"Failed to parse Keycloak users JSON: {exc}\nRaw output:\n{raw}") from exc

    if not isinstance(data, list):  # pragma: no cover - defensive
        raise RuntimeError(f"Unexpected Keycloak users format: {type(data)!r}")

    return data
