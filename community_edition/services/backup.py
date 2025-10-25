import logging
import os
import shutil
from datetime import datetime, timezone
import subprocess
from community_edition.services.env import load_env

env = load_env()

PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BACKUP_DIR = os.path.join(PROJECT_DIR, "dumps")

logger = logging.getLogger(__name__)


def get_backup_list() -> list[dict]:
    """Get list of available backups"""
    backups = []

    if not os.path.exists(BACKUP_DIR):
        logger.error(f"Backup directory not found: {BACKUP_DIR}")
        return []

    for folder in os.listdir(BACKUP_DIR):
        backup_path = os.path.join(BACKUP_DIR, folder)
        core_sql = os.path.join(backup_path, "core.sql")
        workflow_sql = os.path.join(backup_path, "workflow.sql")
        storage_tar = os.path.join(backup_path, "storage.tar.gz")
        description_txt = os.path.join(backup_path, "description.txt")

        if not all(
            [
                os.path.exists(core_sql),
                os.path.exists(workflow_sql),
                os.path.exists(storage_tar),
            ]
        ):
            continue

        if os.path.exists(description_txt):
            with open(description_txt, "r", encoding="utf-8") as f:
                description = f.read().strip()
        else:
            description = "No description provided"

        backups.append(
            {
                "description": description,
                "size": sum(
                    os.path.getsize(os.path.join(backup_path, f))
                    for f in os.listdir(backup_path)
                ),
                "created": datetime.fromtimestamp(
                    os.stat(backup_path).st_ctime
                ).strftime("%Y-%m-%d %H:%M:%S"),
                "path": backup_path,
                "timestamp": folder,
            }
        )
    return sorted(backups, key=lambda x: x["created"], reverse=True)


def create_backup(description: str) -> None:
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
    subprocess.run(
        ["./scripts/export-sql.sh", timestamp], capture_output=True, text=True
    )
    subprocess.run(
        ["./scripts/download-storage.sh", timestamp], capture_output=True, text=True
    )
    with open(f"{BACKUP_DIR}/{timestamp}/description.txt", "w", encoding="utf-8") as f:
        f.write(description.strip())


def delete_backup(backup_filename) -> None:
    """Delete a backup directory"""
    backup_path = os.path.join(BACKUP_DIR, backup_filename)

    if not os.path.exists(backup_path):
        raise ValueError("Backup not found")

    shutil.rmtree(backup_path)
