import os
import subprocess
import requests

from community_edition.services.env import load_env


API_URL = "https://license.finmars.com/api/v1/version/get-latest/?channel=stable"

VERSION_MAPPING = {
    "CORE_IMAGE_VERSION": "backend",
    "WORKFLOW_IMAGE_VERSION": "workflow",
    "PORTAL_IMAGE_VERSION": "portal",
    "VUE_PORTAL_IMAGE_VERSION": "vue-portal",
    "WORKFLOW_PORTAL_IMAGE_VERSION": "workflow-portal",
}


def get_latest_versions() -> dict[str, str]:
    """Fetch latest versions from API"""
    try:
        response = requests.get(API_URL, timeout=10)
        response.raise_for_status()
        data = response.json()

        # Create a mapping of app name to latest version
        latest_versions = {}
        for result in data.get("results", []):
            app_name = result.get("app")
            version = result.get("version")
            if app_name and version:
                latest_versions[app_name] = version

        return latest_versions
    except Exception as e:
        print(f"Error fetching latest versions: {e}")
        return {}


def get_current_versions():
    """Get current versions from .env file"""
    env = load_env()
    current_versions = {}

    for env_var, app_name in VERSION_MAPPING.items():
        current_versions[env_var] = {
            "app_name": app_name,
            "current_version": env.get(env_var, ""),
            "env_var": env_var,
        }

    return current_versions


def restart_containers():
    """Restart containers using make down and make up"""
    try:
        project_root = os.path.dirname(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        )

        # Stop containers
        result_down = subprocess.run(
            ["make", "down"],
            capture_output=True,
            text=True,
            cwd=project_root,
            env=os.environ.copy(),
        )
        if result_down.returncode != 0:
            return False, f"Failed to stop containers: {result_down.stderr}"

        # Start containers
        result_up = subprocess.run(["make", "up"], capture_output=True, text=True)
        if result_up.returncode != 0:
            return False, f"Failed to start containers: {result_up.stderr}"

        return True, "Containers restarted successfully"
    except Exception as e:
        return False, f"Error restarting containers: {str(e)}"
