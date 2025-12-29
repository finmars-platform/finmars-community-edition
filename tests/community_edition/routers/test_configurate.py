import types

from community_edition.routers import configurate as cfg


class TestRoot:
    def test_setup_renders_form_when_generate_env_pending(app, client, monkeypatch):
        fake_completed = types.SimpleNamespace(stdout="logs")
        monkeypatch.setattr(cfg.subprocess, "run", lambda *a, **k: fake_completed)

        monkeypatch.setattr(cfg, "load_state", lambda: {"generate_env": "pending"})
        monkeypatch.setattr(
            cfg,
            "get_setup_steps",
            lambda: [("generate_env", ["make", "generate-env"], "Initial Settings")],
        )

        resp = client.get("/")

        assert resp.status_code == 200
        assert b"<form" in resp.data

    def test_setup_renders_status_when_step_requested(app, client, monkeypatch):
        fake_completed = types.SimpleNamespace(stdout="logs")
        monkeypatch.setattr(cfg.subprocess, "run", lambda *a, **k: fake_completed)

        state = {"generate_env": "done", "init_cert": "requested"}
        monkeypatch.setattr(cfg, "load_state", lambda: state)
        monkeypatch.setattr(
            cfg,
            "get_setup_steps",
            lambda: [
                ("generate_env", ["make", "generate-env"], "Initial Settings"),
                ("init_cert", ["make", "init-cert"], "Request Certificates"),
            ],
        )

        resp = client.get("/")

        assert resp.status_code == 200
        assert b"logs" in resp.data


class TestVersions:
    def test_versions_get_renders_template(self, app, auth_client, monkeypatch):
        monkeypatch.setattr(
            cfg,
            "get_current_versions",
            lambda: {
                "CORE_IMAGE_VERSION": {
                    "app_name": "backend",
                    "current_version": "1.0.0",
                    "env_var": "CORE_IMAGE_VERSION",
                }
            },
        )
        monkeypatch.setattr(
            cfg,
            "get_latest_versions",
            lambda: {"backend": "1.1.0"},
        )

        resp = auth_client.get("/versions")

        assert resp.status_code == 200
        assert b"1.0.0" in resp.data
        assert b"1.1.0" in resp.data


class TestBackup:
    def test_backup_get_lists_backups(self, app, auth_client, monkeypatch):
        monkeypatch.setattr(
            cfg,
            "get_backup_list",
            lambda: [
                {
                    "timestamp": "20250101000000",
                    "created": "2025-01-01 00:00:00",
                    "size": 123,
                }
            ],
        )

        resp = auth_client.get("/backup")

        assert resp.status_code == 200
        assert b"20250101000000" in resp.data

    def test_backup_post_creates_backup_success(app, auth_client, monkeypatch):
        called = {}

        def fake_create():
            called["ok"] = True

        monkeypatch.setattr(cfg, "create_backup", fake_create)

        resp = auth_client.post("/backup")

        assert resp.status_code == 200
        assert resp.get_json()["success"] is True
        assert called.get("ok") is True

    def test_backup_delete_requires_timestamp(app, auth_client, monkeypatch):
        resp = auth_client.delete("/backup", json={})

        assert resp.status_code == 400
        assert resp.get_json()["success"] is False

    def test_backup_delete_calls_delete_backup(app, auth_client, monkeypatch):
        called = {}

        def fake_delete(timestamp):
            called["ts"] = timestamp

        monkeypatch.setattr(cfg, "delete_backup", fake_delete)

        resp = auth_client.delete("/backup", json={"timestamp": "20250101000000"})

        assert resp.status_code == 200
        data = resp.get_json()
        assert data["success"] is True
        assert called.get("ts") == "20250101000000"


class TestLogs:
    def test_logs_page_renders_with_logs_text(self, app, auth_client, fake_get_logs):
        resp = auth_client.get("/logs")

        assert resp.status_code == 200
        assert b"fake-logs-output" in resp.data
        assert fake_get_logs.get("called") is True

    def test_logs_download_returns_text_file_with_logs(self, app, auth_client, fake_get_logs):
        fake_get_logs["text"] = "downloadable-logs"
        resp = auth_client.get("/logs/download")

        assert resp.status_code == 200
        assert resp.mimetype == "text/plain"
        assert b"downloadable-logs" in resp.data
        content_disposition = resp.headers.get("Content-Disposition", "")
        assert "attachment" in content_disposition
        assert "finmars-logs.txt" in content_disposition


class TestKeycloakUsers:
    def test_add_user_get_renders_page_and_users_table(self, app, auth_client, monkeypatch):
        def fake_list_users():
            return [
                {"username": "u1", "firstName": "User", "lastName": "One", "email": "u1@example.com", "enabled": True},
                {"username": "u2", "firstName": None, "lastName": None, "email": None, "enabled": False},
            ]

        monkeypatch.setattr(cfg, "list_keycloak_users", fake_list_users)

        resp = auth_client.get("/keycloak/add-user")

        assert resp.status_code == 200
        # table header and some values
        assert b"Current users" in resp.data
        assert b"u1@example.com" in resp.data
        assert b"u2" in resp.data

    def test_add_user_post_validates_and_calls_service(self, app, auth_client, monkeypatch):
        created = {}

        def fake_add_user(username, password):
            created["username"] = username
            created["password"] = password

        def fake_list_users():
            return []

        monkeypatch.setattr(cfg, "add_keycloak_user", fake_add_user)
        monkeypatch.setattr(cfg, "list_keycloak_users", fake_list_users)

        resp = auth_client.post(
            "/keycloak/add-user",
            data={"username": "alice", "password": "secret"},
            follow_redirects=True,
        )

        assert resp.status_code == 200
        assert created["username"] == "alice"
        assert created["password"] == "secret"
        # success flash should mention the user
        assert b"alice" in resp.data

    def test_add_user_post_missing_fields_shows_error(self, app, auth_client, monkeypatch):
        # list_keycloak_users is still required for rendering
        monkeypatch.setattr(cfg, "list_keycloak_users", lambda: [])

        resp = auth_client.post(
            "/keycloak/add-user",
            data={"username": "", "password": ""},
            follow_redirects=True,
        )

        assert resp.status_code == 200
        assert b"Username and password are required" in resp.data
