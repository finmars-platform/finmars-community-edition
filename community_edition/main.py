import os
import logging
from community_edition.routers import app
from community_edition.services.setup import LOG_FILE


if __name__ == "__main__":
    if os.path.exists(LOG_FILE):
        os.remove(LOG_FILE)

    # Configure logging
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        handlers=[
            logging.StreamHandler(),  # Console output
            logging.FileHandler("app.log"),  # File output
        ],
    )

    app.run(host="0.0.0.0", port=8888)
