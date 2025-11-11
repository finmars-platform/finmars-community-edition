import logging
import os

from community_edition.app import create_app
from community_edition.services.setup import LOG_FILE


if __name__ == "__main__":
    if os.path.exists(LOG_FILE):
        os.remove(LOG_FILE)

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        handlers=[
            logging.StreamHandler(),
            logging.FileHandler("app.log"),
        ],
    )

    app = create_app()
    app.run(host="0.0.0.0", port=8888)
