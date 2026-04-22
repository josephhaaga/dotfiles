#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import re
import shutil
import sqlite3
import ssl
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime
from pathlib import Path

# macOS Python doesn't use the system cert store by default; use it explicitly.
_SSL_CONTEXT = ssl.create_default_context(cafile="/etc/ssl/cert.pem")


def get_slack_cookie() -> str | None:
    """
    Decrypt the Slack 'd' session cookie from the Slack desktop app's cookie store.
    Returns the xoxd- token string, or None if unavailable.
    """
    try:
        from Crypto.Cipher import AES
    except ImportError:
        print("Warning: pycryptodome not installed; cannot download private images.", file=sys.stderr)
        return None

    cookie_path = Path.home() / "Library/Application Support/Slack/Cookies"
    if not cookie_path.exists():
        print("Warning: Slack cookie store not found; cannot download private images.", file=sys.stderr)
        return None

    try:
        password = subprocess.check_output(
            ["security", "find-generic-password", "-s", "Slack Safe Storage", "-w"],
            stderr=subprocess.DEVNULL,
        ).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("Warning: Slack Safe Storage key not found in keychain.", file=sys.stderr)
        return None

    try:
        tmp = tempfile.mktemp(suffix=".db")
        shutil.copy2(cookie_path, tmp)
        conn = sqlite3.connect(tmp)
        row = conn.cursor().execute(
            "SELECT encrypted_value FROM cookies WHERE name = 'd' AND host_key = '.slack.com'"
        ).fetchone()
        conn.close()
        os.unlink(tmp)
    except Exception as e:
        print(f"Warning: Could not read Slack cookie DB: {e}", file=sys.stderr)
        return None

    if not row:
        print("Warning: Slack 'd' cookie not found.", file=sys.stderr)
        return None

    from Crypto.Cipher import AES

    enc = bytes(row[0])
    if not enc.startswith(b"v10"):
        return None

    dk = hashlib.pbkdf2_hmac("sha1", password, b"saltysalt", 1003, dklen=16)
    decrypted = AES.new(dk, AES.MODE_CBC, b" " * 16).decrypt(enc[3:])
    match = re.search(rb"xoxd-\S+", decrypted)
    return match.group(0).decode() if match else None


def make_opener(cookie: str | None) -> urllib.request.OpenerDirector:
    """Build a urllib opener that attaches the Slack cookie on every request, including redirects."""

    class CookieRedirectHandler(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, headers, newurl):
            new_req = super().redirect_request(req, fp, code, msg, headers, newurl)
            if new_req and cookie:
                new_req.add_header("Cookie", f"d={cookie}")
            return new_req

    opener = urllib.request.build_opener(
        CookieRedirectHandler,
        urllib.request.HTTPSHandler(context=_SSL_CONTEXT),
    )
    if cookie:
        opener.addheaders = [("Cookie", f"d={cookie}")]
    return opener


def download_image(url: str, dest_dir: str, opener: urllib.request.OpenerDirector) -> str | None:
    """
    Download a Slack private image URL to dest_dir.
    Returns the local filename (basename only), or None on failure.
    """
    parsed = urllib.parse.urlparse(url)
    filename = Path(parsed.path).name or "image"
    dest = os.path.join(dest_dir, filename)

    if os.path.exists(dest):
        return filename

    try:
        with opener.open(url, timeout=30) as resp:
            with open(dest, "wb") as f:
                f.write(resp.read())
        return filename
    except urllib.error.HTTPError as e:
        print(f"Warning: Failed to download {url} — HTTP {e.code} {e.reason}", file=sys.stderr)
        return None
    except urllib.error.URLError as e:
        print(f"Warning: Failed to download {url} — {e.reason}", file=sys.stderr)
        return None


def indent_content(text, prefix="> "):
    """Ensures multi-line text and code blocks stay inside the blockquote."""
    return text.replace("\n", f"\n{prefix}")


def convert_thread(output_dir: str | None):
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        return

    messages = data if isinstance(data, list) else data.get("messages", [])
    if not messages:
        return

    first_ts = float(messages[0].get("ts", 0))
    date_header = datetime.fromtimestamp(first_ts).strftime("%Y-%m-%d")

    # Set up download if -o was given
    opener = None
    if output_dir:
        cookie = get_slack_cookie()
        opener = make_opener(cookie)

    lines = []
    lines.append(f"**Thread Archive ({date_header})**\n")

    has_private_urls = False

    for i, msg in enumerate(messages):
        if msg.get("type") != "message":
            continue

        username = msg.get("user") or msg.get("username")
        if not username and "user_profile" in msg:
            username = msg["user_profile"].get("name") or msg["user_profile"].get("real_name")
        username = username or "Unknown"

        text = msg.get("text", "").strip()

        file_links = []
        if "files" in msg:
            for f in msg["files"]:
                file_url = f.get("url_private") or f.get("permalink_public") or "URL missing"
                file_name = f.get("name", "attachment")

                if f.get("mimetype", "").startswith("image/"):
                    if output_dir and file_url != "URL missing":
                        local = download_image(file_url, output_dir, opener)
                        if local:
                            file_url = local
                        # else: fall back to original URL
                    elif not output_dir and file_url.startswith("https://files.slack.com"):
                        has_private_urls = True
                    file_links.append(f"![{file_name}]({file_url})")
                else:
                    file_links.append(f"📎 [{file_name}]({file_url})")

        full_content = text
        if file_links:
            full_content += "\n" + "\n".join(file_links)

        ts = float(msg.get("ts", 0))
        time_str = datetime.fromtimestamp(ts).strftime("%H:%M")

        if i == 0:
            lines.append(f"**{username}** `{time_str}`: {full_content}\n")
        else:
            prefix = "> "
            clean_content = indent_content(full_content, prefix)
            lines.append(f"{prefix}**{username}** `{time_str}`: {clean_content}\n{prefix}")

    md = "\n".join(lines) + "\n"

    if output_dir:
        out_path = os.path.join(output_dir, "thread.md")
        with open(out_path, "w") as f:
            f.write(md)
        print(f"Wrote {out_path}", file=sys.stderr)
    else:
        if has_private_urls:
            print(
                "Warning: thread contains private Slack image URLs that will be broken. "
                "Use -o DIR to download images locally.",
                file=sys.stderr,
            )
        sys.stdout.write(md)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Format slackdump JSON as Markdown."
    )
    parser.add_argument(
        "-o",
        metavar="DIR",
        dest="output_dir",
        default=None,
        help="Write thread.md and downloaded images into DIR.",
    )
    args = parser.parse_args()
    convert_thread(output_dir=args.output_dir)
