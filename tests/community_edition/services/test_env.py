from community_edition.services.env import load_env


class TestLoadEnv:
    def test_load_env_returns_empty_dict_if_file_missing(self, tmp_path, monkeypatch):
        fake_env = tmp_path / ".env"
        monkeypatch.chdir(tmp_path)

        env = load_env()

        assert env == {}
        assert not fake_env.exists()

    def test_load_env_parses_key_values_and_ignores_comments_and_empty_lines(self, tmp_path, monkeypatch):
        env_content = """
        # comment line
        KEY1=value1

        KEY2=" value2 "
        KEY3='value3'
        """
        env_path = tmp_path / ".env"
        env_path.write_text(env_content)

        monkeypatch.chdir(tmp_path)

        env = load_env()

        assert env == {
            "KEY1": "value1",
            "KEY2": "value2",
            "KEY3": "value3",
        }
