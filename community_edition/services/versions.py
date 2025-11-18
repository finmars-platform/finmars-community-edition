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


def get_current_versions() -> dict[str, dict[str, str]]:
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


def set_versions_in_env() -> None:
    result = subprocess.run(["make", "update-versions"], check=False, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"Failed to update versions: {result.stderr}")
