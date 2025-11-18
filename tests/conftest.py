import pytest

from community_edition.app import create_app


@pytest.fixture
def app(tmp_path, monkeypatch):
    """
    Application fixture that:
    - uses a temporary working directory
    - provides a minimal .env with admin credentials
    - returns a real Flask app created by create_app()
    """
    monkeypatch.chdir(tmp_path)

    env_path = tmp_path / ".env"
    env_path.write_text(
        "\n".join(
            [
                "ADMIN_USERNAME=admin",
                "ADMIN_PASSWORD=secret",
                "FLASK_SECRET_KEY=test-secret",
                "DOMAIN_NAME=example.com",
            ]
        )
        + "\n",
        encoding="utf-8",
    )

    app = create_app()
    app.config.update(TESTING=True)
    return app


@pytest.fixture
def client(app):
    return app.test_client()


@pytest.fixture
def auth_client(client):
    """
    Test client with an authenticated session
    (matches the basic auth/session check in app.before_request).
    """
    with client.session_transaction() as sess:
        sess["authenticated"] = True
    return client
