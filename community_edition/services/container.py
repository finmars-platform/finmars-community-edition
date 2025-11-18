import subprocess


def down_containers() -> None:
    """
    Stop all running containers using 'make down' command.
    """
    result_down = subprocess.run(["make", "down"], check=False, capture_output=True, text=True)
    if result_down.returncode != 0:
        raise RuntimeError(f"Failed to stop containers: {result_down.stderr}")


def up_containers() -> None:
    """
    Start all containers using 'make up' command.
    """
    result_up = subprocess.run(["make", "up"], check=False, capture_output=True, text=True)
    if result_up.returncode != 0:
        raise RuntimeError(f"Failed to start containers: {result_up.stderr}")
