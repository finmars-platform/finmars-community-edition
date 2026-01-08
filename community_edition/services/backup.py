import logging
import os
import shutil
import subprocess
from datetime import datetime

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
        dump_zip_filepath = os.path.join(BACKUP_DIR, folder, "dump.zip")
        if not os.path.exists(dump_zip_filepath):
            continue

        folder_datetime = datetime.strptime(folder, "%Y%m%d%H%M%S")

        backups.append(
            {
                "date": folder_datetime.strftime("%Y-%m-%d"),
                "size": os.path.getsize(dump_zip_filepath),
                "created": folder_datetime.strftime("%Y-%m-%d %H:%M:%S"),
                "path": dump_zip_filepath,
                "timestamp": folder,
            }
        )
    return sorted(backups, key=lambda x: x["created"], reverse=True)


def create_backup() -> None:
    """Create a backup by calling the create-dumps.sh script"""
    result = subprocess.run(["make", "create-dumps"], check=False, capture_output=True, text=True)

    if result.returncode != 0:
        raise RuntimeError(f"Backup creation failed: {result.stderr}")

    logger.info(f"Backup created successfully: {result.stdout}")


def delete_backup(backup_filename) -> None:
    """Delete a backup directory"""
    backup_path = os.path.join(BACKUP_DIR, backup_filename)

    if not os.path.exists(backup_path):
        raise ValueError("Backup not found")

    shutil.rmtree(backup_path)


def _run_restore_with_tmp_backup(tmp_backup_path: str) -> None:
    """Run restore-backup script using the backup file located at tmp_backup_path."""
    if not os.path.exists(tmp_backup_path):
        raise ValueError(f"Backup file not found for restore: {tmp_backup_path}")

    result = subprocess.run(
        ["make", "restore-backup"],
        check=False,
        capture_output=True,
        text=True,
        cwd=PROJECT_DIR,
    )

    if result.returncode != 0:
        if os.path.exists(tmp_backup_path):
            os.remove(tmp_backup_path)
        raise RuntimeError(f"Restore script failed: {result.stderr}")

    logger.info(f"Backup restored successfully: {result.stdout}")


def restore_backup(timestamp: str) -> None:
    """Restore a backup by copying it to tmp/backup.zip and running restore script"""
    backup_path = os.path.join(BACKUP_DIR, timestamp)
    dump_zip_path = os.path.join(backup_path, "dump.zip")
    tmp_backup_path = os.path.join(PROJECT_DIR, "tmp", "backup.zip")

    if not os.path.exists(dump_zip_path):
        raise ValueError(f"Backup dump.zip not found for timestamp: {timestamp}")

    tmp_dir = os.path.join(PROJECT_DIR, "tmp")
    os.makedirs(tmp_dir, exist_ok=True)
    shutil.copy2(dump_zip_path, tmp_backup_path)

    _run_restore_with_tmp_backup(tmp_backup_path)


def restore_backup_from_uploaded_file() -> None:
    """Restore a backup from an uploaded file saved as tmp/backup.zip."""
    tmp_backup_path = os.path.join(PROJECT_DIR, "tmp", "backup.zip")
    _run_restore_with_tmp_backup(tmp_backup_path)
