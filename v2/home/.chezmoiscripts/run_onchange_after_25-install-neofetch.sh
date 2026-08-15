#!/usr/bin/env bash

set -euo pipefail

version="7.1.0"
expected="3dc33493e54029fb1528251552093a9f9a2894fcf94f9c3a6f809136a42348c7"
url="https://raw.githubusercontent.com/dylanaraps/neofetch/$version/neofetch"
destination="$HOME/.local/bin/neofetch"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

curl -fsSL "$url" -o "$tmp"
if command -v sha256sum >/dev/null 2>&1; then
  actual="$(sha256sum "$tmp" | awk '{print $1}')"
else
  actual="$(shasum -a 256 "$tmp" | awk '{print $1}')"
fi
if [ "$actual" != "$expected" ]; then
  printf 'neofetch checksum mismatch: expected %s, got %s\n' "$expected" "$actual" >&2
  exit 1
fi

mkdir -p "$(dirname "$destination")"
install -m 0755 "$tmp" "$destination"
