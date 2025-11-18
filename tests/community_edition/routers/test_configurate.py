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
