from urllib.parse import urlparse

from community_edition.services.authentication import (
    desired_next_url,
    is_safe_url,
    redirect_to_login,
)


class TestIsSafeUrl:
    def test_is_safe_url_false_for_none(self, app):
        with app.test_request_context("/"):
            assert is_safe_url(None) is False

    def test_is_safe_url_allows_same_host_relative_and_absolute(self, app):
        with app.test_request_context("/"):
            assert is_safe_url("/")
            assert is_safe_url("http://localhost/") or is_safe_url("http://127.0.0.1/")

    def test_is_safe_url_rejects_different_host(self, app):
        with app.test_request_context("/"):
            assert is_safe_url("https://example.com/other") is False


class TestDesiredNextUrl:
    def test_desired_next_url_uses_candidate_if_safe(self, app):
        with app.test_request_context("/target"):
            url = desired_next_url("/target?foo=bar")
            assert url == "/target?foo=bar".rstrip("?")

    def test_desired_next_url_falls_back_to_setup_if_unsafe(self, app):
        with app.test_request_context("/"):
            url = desired_next_url("https://evil.com/phish")
            assert url == "/"


def test_redirect_to_login_builds_login_url(app):
    with app.test_request_context("/protected"):
        response = redirect_to_login()
        assert response.status_code == 302
        location = response.headers["Location"]
        parsed = urlparse(location)
        assert parsed.path == "/login"
        assert "next=" in parsed.query
