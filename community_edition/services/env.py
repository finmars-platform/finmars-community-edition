ENV_FILE = ".env"


def load_env() -> dict[str, str]:
    env = {}
    with open(ENV_FILE) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            key, value = line.split("=", 1)
            env[key] = value.strip().strip('"').strip("'")
    return env


def update_versions_in_env(version_updates: dict[str, str]) -> tuple[bool, str]:
    if not version_updates:
        return False, "No version updates provided"

    with open(ENV_FILE, "r") as f:
        lines = f.readlines()

    with open(f"{ENV_FILE}.bak", "w") as f:
        f.writelines(lines)

    updated_lines = []
    updated_count = 0

    for line in lines:
        updated = False
        for env_var, new_version in version_updates.items():
            if line.startswith(f"{env_var}="):
                updated_lines.append(f"{env_var}={new_version}\n")
                updated_count += 1
                updated = True
                break

        if not updated:
            updated_lines.append(line)

    with open(ENV_FILE, "w") as f:
        f.writelines(updated_lines)

    return True, f"Updated {updated_count} versions"
