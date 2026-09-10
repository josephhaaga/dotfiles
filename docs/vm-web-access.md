# VM web access

The server profile publishes OpenChamber at
`https://josephhaaga.sh.tribe.ai` without exposing OpenChamber itself. An
approved device must authenticate to Caddy with a client certificate before
Caddy proxies any request.

## Request flow

```text
Safari with device certificate
  -> HTTPS on josephhaaga.sh.tribe.ai:443
  -> mTLS client-certificate verification at Caddy
  -> OpenChamber on VM loopback port 3000
  -> stable OpenCode managed by OpenChamber
```

Caddy handles WebSocket upgrades automatically. Its `flush_interval -1`
setting forwards OpenChamber's SSE streams without buffering.

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
- OpenChamber listens only on `127.0.0.1:3000`.
- The beta OpenCode service listens only on `127.0.0.1:49374` and remains
  available through the SSH tunnel for `opencode-vm`.
- OpenChamber uses the stable `~/.local/bin/opencode` binary because its SDK is
  not compatible with the beta service. Its runtime data is isolated under
  `~/.local/share/openchamber/opencode` to protect the beta database.

## Secret handling

Only non-secret configuration and the public client CA certificate belong in
dotfiles. Do not commit the client CA private key, device private keys, `.p12`
files, provider credentials, or application runtime state.

Back up `~/.local/share/dotfiles/caddy-ca` securely. If the CA private key is
exposed, replace the trusted CA and issue new identities for every device.
