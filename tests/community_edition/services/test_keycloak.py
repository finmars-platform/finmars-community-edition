import json
import types

import pytest

from community_edition.services import keycloak


class TestAddKeycloakUser:
    def test_add_keycloak_user_raises_for_missing_credentials(self):
        with pytest.raises(ValueError):
            keycloak.add_keycloak_user("", "pass")
        with pytest.raises(ValueError):
            keycloak.add_keycloak_user("user", "")

    def test_add_keycloak_user_calls_make_and_returns_output(self, monkeypatch, tmp_path):
        # Run from a temp project dir so cwd is well-defined
        monkeypatch.chdir(tmp_path)

        recorded = {}

        def fake_run(cmd, check, capture_output, text, cwd):
            recorded["cmd"] = cmd
            recorded["check"] = check
            recorded["capture_output"] = capture_output
            recorded["text"] = text
            recorded["cwd"] = cwd
            return types.SimpleNamespace(returncode=0, stdout="ok", stderr="")

        monkeypatch.setattr(keycloak.subprocess, "run", fake_run)

        out = keycloak.add_keycloak_user("alice", "secret")

        assert out == "ok"
        assert recorded["cmd"][:2] == ["make", "add-user"]
        assert "USERNAME=alice" in recorded["cmd"]
        assert "PASSWORD=secret" in recorded["cmd"]
        assert recorded["capture_output"] is True
        assert recorded["text"] is True

    def test_add_keycloak_user_raises_on_non_zero_exit(self, monkeypatch, tmp_path):
        monkeypatch.chdir(tmp_path)

        def fake_run(*_args, **_kwargs):
            return types.SimpleNamespace(returncode=1, stdout="out", stderr="err")

        monkeypatch.setattr(keycloak.subprocess, "run", fake_run)

        with pytest.raises(RuntimeError) as exc:
            keycloak.add_keycloak_user("alice", "secret")

        msg = str(exc.value)
        assert "Failed to add Keycloak user via CLI." in msg
        assert "out" in msg or "err" in msg


class TestListKeycloakUsers:
    def test_list_keycloak_users_returns_empty_list_when_no_output(self, monkeypatch, tmp_path):
        monkeypatch.chdir(tmp_path)

        def fake_run(*_args, **_kwargs):
            return types.SimpleNamespace(returncode=0, stdout="", stderr="")

        monkeypatch.setattr(keycloak.subprocess, "run", fake_run)

        users = keycloak.list_keycloak_users()
        assert users == []

    def test_list_keycloak_users_parses_plain_json_array(self, monkeypatch, tmp_path):
        monkeypatch.chdir(tmp_path)
        payload = [
            {"username": "user1", "email": "u1@example.com", "enabled": True},
            {"username": "user2", "email": None, "enabled": False},
        ]

        def fake_run(*_args, **_kwargs):
            return types.SimpleNamespace(returncode=0, stdout=json.dumps(payload), stderr="")

        monkeypatch.setattr(keycloak.subprocess, "run", fake_run)

        users = keycloak.list_keycloak_users()
        assert isinstance(users, list)
        assert users[0]["username"] == "user1"
        assert users[1]["enabled"] is False

    def test_list_keycloak_users_parses_output_with_leading_command_prefix(self, monkeypatch, tmp_path):
        monkeypatch.chdir(tmp_path)
        payload = [
            {"username": "user1"},
        ]
        stdout = "./scripts/list-keycloak-users.sh " + json.dumps(payload)

        def fake_run(*_args, **_kwargs):
            return types.SimpleNamespace(returncode=0, stdout=stdout, stderr="")

        monkeypatch.setattr(keycloak.subprocess, "run", fake_run)

        users = keycloak.list_keycloak_users()
        assert users == payload

    def test_list_keycloak_users_raises_on_non_zero_exit(self, monkeypatch, tmp_path):
        monkeypatch.chdir(tmp_path)

        def fake_run(*_args, **_kwargs):
            return types.SimpleNamespace(returncode=1, stdout="[]", stderr="boom")

        monkeypatch.setattr(keycloak.subprocess, "run", fake_run)

        with pytest.raises(RuntimeError) as exc:
            keycloak.list_keycloak_users()

        assert "Failed to list Keycloak users via CLI." in str(exc.value)
