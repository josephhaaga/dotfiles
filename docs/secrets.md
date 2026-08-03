# Secrets

This repository uses chezmoi's native [age](https://www.chezmoi.io/user-guide/encryption/age/) encryption for tracked credentials, rather than a standalone SOPS setup. Encrypted files live in `home/` with an `encrypted_` prefix and a `.age` suffix (e.g. `home/dot_config/zsh/encrypted_private_dot_secrets.age`); chezmoi decrypts them transparently on `chezmoi apply`.

## Currently encrypted

- `home/dot_config/zsh/encrypted_private_dot_secrets.age` -> `~/.config/zsh/.secrets`
- `home/dot_config/opencode/encrypted_opencode.personal.json.age` -> `~/.config/opencode/opencode.personal.json`

Neither currently holds a real credential (both are placeholder content as of the chezmoi migration), but they're encrypted anyway since they're the designated places for personal secrets going forward.

## Key management

- The encryption key is an age keypair. The private key lives at `~/.config/chezmoi/key.txt` (mode `600`, never committed) and must be present before running `chezmoi init`/`chezmoi apply` on any machine.
- **Back up `~/.config/chezmoi/key.txt` in 1Password.** Losing it means losing access to every encrypted file in this repo — there is no recovery path otherwise.
- The **public** recipient key is not secret and is committed in `home/.chezmoi.toml.tmpl` (the `[age]` section), so any machine with the private key restored to `~/.config/chezmoi/key.txt` can decrypt on `chezmoi init`/`apply` without further setup.

## Editing an encrypted file

```bash
chezmoi decrypt < home/dot_config/zsh/encrypted_private_dot_secrets.age   # inspect
# edit the decrypted content, then:
chezmoi encrypt < /path/to/edited/file > home/dot_config/zsh/encrypted_private_dot_secrets.age
```

Or use `chezmoi edit --apply ~/.config/zsh/.secrets`, which round-trips decrypt/edit/re-encrypt automatically.

## `~/.config/gh` / `~/.config/gcloud`

These remain **outside** chezmoi's managed tree entirely (see `AGENTS.md`), since they hold live OAuth tokens and local CLI state that must never be overwritten by `chezmoi apply`. `configs/gh/hosts.yml` (currently just host/protocol metadata, no live token) and `configs/gcloud/` stay as untracked-by-chezmoi reference copies at their current repo location; they are not applied to any machine.

## Safety net

`scripts/validate.sh` runs `gitleaks detect` when installed, scanning the working tree for accidentally-committed plaintext credentials regardless of the above.
