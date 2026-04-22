#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime
from pathlib import Path


def get_slack_cookie() -> str | None:
    """
    Decrypt the Slack 'd' session cookie from the Slack desktop app's cookie store.
    Returns the xoxd- token string, or None if unavailable.
    """
    try:
        from Crypto.Cipher import AES
    except ImportError:
        return None

    cookie_path = Path.home() / "Library/Application Support/Slack/Cookies"
    if not cookie_path.exists():
        return None

    try:
        password = subprocess.check_output(
            ["security", "find-generic-password", "-s", "Slack Safe Storage", "-w"],
            stderr=subprocess.DEVNULL,
        ).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
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
    except Exception:
        return None

    if not row:
        return None

    enc = bytes(row[0])
    if not enc.startswith(b"v10"):
        return None

    dk = hashlib.pbkdf2_hmac("sha1", password, b"saltysalt", 1003, dklen=16)
    decrypted = AES.new(dk, AES.MODE_CBC, b" " * 16).decrypt(enc[3:])
    match = re.search(rb"xoxd-\S+", decrypted)
    return match.group(0).decode() if match else None


def download_image(url: str, dest_dir: str, cookie: str | None) -> str | None:
    """
    Download a Slack private image URL to dest_dir.
    Returns the local file path, or None on failure.
    """
    parsed = urllib.parse.urlparse(url)
    filename = Path(parsed.path).name or "image"
    dest = os.path.join(dest_dir, filename)

    # Avoid re-downloading
    if os.path.exists(dest):
        return dest

    req = urllib.request.Request(url)
    if cookie:
        req.add_header("Cookie", f"d={cookie}")

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            with open(dest, "wb") as f:
                f.write(resp.read())
        return dest
    except urllib.error.URLError:
        return None


def indent_content(text, prefix="> "):
    """Ensures multi-line text and code blocks stay inside the blockquote."""
    return text.replace("\n", f"\n{prefix}")


def convert_thread(download_dir: str | None, no_download: bool):
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        return

    messages = data if isinstance(data, list) else data.get("messages", [])
    if not messages:
        return

    first_ts = float(messages[0].get("ts", 0))
    date_header = datetime.fromtimestamp(first_ts).strftime("%Y-%m-%d")

    sys.stdout.write(f"**Thread Archive ({date_header})**\n\n")

    cookie = None
    if not no_download:
        cookie = get_slack_cookie()
        if download_dir is None:
            download_dir = tempfile.mkdtemp(prefix="slackmd-")

    for i, msg in enumerate(messages):
        if msg.get("type") != "message":
            continue

        username = msg.get("user") or msg.get("username")
        if not username and "user_profile" in msg:
            username = msg["user_profile"].get("name") or msg["user_profile"].get(
                "real_name"
            )
        username = username or "Unknown"

        text = msg.get("text", "").strip()

        # --- Handle Files/Images ---
        file_links = []
        if "files" in msg:
            for f in msg["files"]:
                file_url = (
                    f.get("url_private") or f.get("permalink_public") or "URL missing"
                )
                file_name = f.get("name", "attachment")

                if f.get("mimetype", "").startswith("image/"):
                    if not no_download and file_url != "URL missing":
                        local = download_image(file_url, download_dir, cookie)
                        if local:
                            file_url = local
                    file_links.append(f"![{file_name}]({file_url})")
                else:
                    file_links.append(f"📎 [{file_name}]({file_url})")

        # Combine text and files
        full_content = text
        if file_links:
            full_content += "\n" + "\n".join(file_links)

        ts = float(msg.get("ts", 0))
        time_str = datetime.fromtimestamp(ts).strftime("%H:%M")

        if i == 0:
            sys.stdout.write(f"**{username}** `{time_str}`: {full_content}\n\n")
        else:
            prefix = "> "
            clean_content = indent_content(full_content, prefix)
            sys.stdout.write(
                f"{prefix}**{username}** `{time_str}`: {clean_content}\n{prefix}\n"
            )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Format slackdump JSON as Markdown, downloading private images."
    )
    parser.add_argument(
        "--download-dir",
        metavar="DIR",
        default=None,
        help="Directory to save downloaded images (default: a temp dir).",
    )
    parser.add_argument(
        "--no-download",
        action="store_true",
        help="Skip downloading private images; leave URLs as-is.",
    )
    args = parser.parse_args()
    convert_thread(download_dir=args.download_dir, no_download=args.no_download)
