from community_edition.routers import authentication as auth_router


class TestLogin:
    def test_login_redirects_to_setup_when_credentials_not_configured(self, app, client, monkeypatch):
        monkeypatch.setattr(
            auth_router,
            "load_env",
            lambda: {},
        )

        resp = client.get("/login", follow_redirects=False)

        assert resp.status_code == 302
        assert resp.headers["Location"].endswith("/")

    def test_login_renders_form_on_get_when_credentials_present(self, app, client, monkeypatch):
        monkeypatch.setattr(
            auth_router,
            "load_env",
            lambda: {"ADMIN_USERNAME": "admin", "ADMIN_PASSWORD": "secret"},
        )

        resp = client.get("/login")

        assert resp.status_code == 200
        assert b"<form" in resp.data

    def test_login_sets_session_and_redirects_on_valid_credentials(self, app, client, monkeypatch):
        monkeypatch.setattr(
            auth_router,
            "load_env",
            lambda: {"ADMIN_USERNAME": "admin", "ADMIN_PASSWORD": "secret"},
        )

        resp = client.post(
            "/login",
            data={"username": "admin", "password": "secret", "next_url": "/"},
            follow_redirects=False,
        )

        assert resp.status_code == 302
        assert resp.headers["Location"].endswith("/")

        with client.session_transaction() as sess:
            assert sess.get("authenticated") is True
