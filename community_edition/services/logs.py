import subprocess
from typing import Final

from .backup import PROJECT_DIR

DEFAULT_LOGS_COMMAND: Final[list[str]] = ["docker", "compose", "logs"]


def get_docker_compose_logs() -> str:
    try:
        result = subprocess.run(
            DEFAULT_LOGS_COMMAND,
            check=False,
            capture_output=True,
            text=True,
            cwd=PROJECT_DIR,
        )
        return result.stdout or result.stderr or ""
    except Exception as exc:  # pragma: no cover - defensive fallback
        return f"Failed to fetch docker compose logs: {exc}"
