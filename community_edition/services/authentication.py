from urllib.parse import urlparse, urljoin

from flask import request, redirect, url_for

def is_safe_url(target: str | None) -> bool:
    if not target:
        return False
    ref_url = urlparse(request.host_url)
    test_url = urlparse(urljoin(request.host_url, target))
    return test_url.scheme in ("http", "https") and ref_url.netloc == test_url.netloc


def desired_next_url(candidate: str | None = None) -> str:
    if not candidate:
        candidate = request.full_path if request.method == "GET" else request.referrer
    candidate = (candidate or "/").rstrip("?")
    if candidate and is_safe_url(candidate):
        return candidate
    return url_for("setup")


def redirect_to_login():
    return redirect(url_for("authentication.login", next=desired_next_url()))