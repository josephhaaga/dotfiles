# VM web access

The server profile publishes static reports at
`https://josephhaaga.sh.tribe.ai` without exposing their backing services or
files directly. An approved device must authenticate to Caddy with a client
certificate before Caddy handles any request.

## Request flow

```text
Safari with device certificate
  -> HTTPS on josephhaaga.sh.tribe.ai:443
  -> mTLS client-certificate verification at Caddy
  -> /reports/*: static files in the dotfiles checkout
```

## Certificates and keys

| Material | Location | Secret? | Purpose |
| --- | --- | --- | --- |
| Let's Encrypt server certificate | Caddy-managed runtime state on the VM | No | Identifies the public hostname |
| Let's Encrypt server private key | Caddy-managed runtime state on the VM | Yes | Proves Caddy owns the server certificate |
| Client CA certificate | `~/.config/caddy/client-ca.pem` on the VM and in dotfiles | No | Lets Caddy verify approved devices |
| Client CA private key | `~/.local/share/dotfiles/caddy-ca` outside Git | Yes | Issues device certificates |
| Device certificate and key | Installed on each approved Mac or iPhone | Key is secret | Proves the device is approved |

Each device should have its own certificate and private key. The `.p12` file
used for installation contains the private key and must remain secret.

## Service boundaries

- Caddy alone listens publicly on ports 80 and 443.
- Caddy serves `/reports/*` from the repository's `reports/` directory. It
  provides a directory index and disables browser and intermediary caching.
- The OpenCode service listens only on `127.0.0.1:49374` and remains
  available through the SSH tunnel for `opencode-vm`.

See [VM-hosted reports](vm-hosted-reports.md) for the report publishing
contract and workflow.

## Secret handling

Only non-secret configuration and the public client CA certificate belong in
dotfiles. Do not commit the client CA private key, device private keys, `.p12`
files, provider credentials, or application runtime state.

Back up `~/.local/share/dotfiles/caddy-ca` securely. If the CA private key is
exposed, replace the trusted CA and issue new identities for every device.
