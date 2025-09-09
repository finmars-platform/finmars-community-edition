import os
from community_edition.routers import app
from community_edition.services.setup import LOG_FILE


if __name__ == "__main__":
    if os.path.exists(LOG_FILE):
        os.remove(LOG_FILE)

    app.run(host="0.0.0.0", port=8888)
