# Secrets

Credentials must not be added to regular tracked configuration. This repository currently has credential-bearing paths that need a one-time migration: `configs/zsh/.secrets`, `configs/gh/hosts.yml`, and `configs/opencode/opencode.personal.json`.

Use SOPS with an age recipient stored outside the repository. Add the recipient to `.sops.yaml`, encrypt each file in place, then remove any plaintext from Git history in a separately reviewed operation. Do not rotate or rewrite existing credentials until replacement credentials and the age recovery path have been verified.

Run `scripts/validate.sh` locally and in CI; when `gitleaks` is installed it scans the working tree for accidental plaintext credentials.
