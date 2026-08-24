# OpenCode VM connections

OpenCode on the VM is reachable through three independent connection paths.
They serve different clients, use different authentication, and must not be
combined into one tunnel.

| Method | Local entry point | VM destination | Lifetime |
| --- | --- | --- | --- |
| Safari web | `https://josephhaaga.sh.tribe.ai` | Caddy to `127.0.0.1:49374` | Per browser request |
| Local TUI | `http://127.0.0.1:14096` | `127.0.0.1:49374` | Persistent LaunchAgent |
| OpenAI OAuth | `http://localhost:1455/auth/callback` | `127.0.0.1:1455` | Temporary manual tunnel |

## Safari web access

Safari connects directly to the public Caddy endpoint. No SSH tunnel is used.

```text
Safari
  -> HTTPS on josephhaaga.sh.tribe.ai:443
  -> verified client-certificate route at Caddy
  -> OpenCode Basic Authorization added by Caddy
  -> OpenCode on VM loopback port 49374
```

The device must have its client certificate and private key installed. Caddy
reads the OpenCode password from the VM's root-owned runtime configuration;
the browser never receives that password. See [OpenCode web access](opencode-web.md)
for certificate and proxy details.

## Local TUI attachment

The desktop LaunchAgent `com.josephhaaga.opencode-tunnel` maintains this SSH
local forward:

```text
127.0.0.1:14096 -> VM 127.0.0.1:49374
```

The `opencode-vm` zsh alias starts the local V2 client against that forwarded
server:

```bash
opencode-vm
opencode-vm --continue
```

The alias expands to:

```bash
op run --env-file="$HOME/.config/opencode/opencode-vm.env" -- \
  opencode2 --server http://127.0.0.1:14096
```

The env file contains only a 1Password secret reference. Create an `OpenCode
VM` item in the `Employee` vault and set its `password` field to the password
shown by `opencode2 pair` on the VM. The resolved password exists only in the
client process environment.

## OpenAI browser OAuth

OpenAI redirects browser authentication to the fixed loopback URL
`http://localhost:1455/auth/callback`. For authentication initiated by the
VM-hosted OpenCode server, temporarily forward that local port to the VM.

1. Start the tunnel in a local terminal:

   ```bash
   ssh -NT \
     -o ExitOnForwardFailure=yes \
     -L 1455:127.0.0.1:1455 \
     ec2-user@josephhaaga.sh.tribe.ai
   ```

2. In another local terminal, attach to the VM server and initiate OAuth:

   ```bash
   opencode-vm
   ```

   Run `/connect`, select OpenAI, then select `ChatGPT Pro/Plus (browser)`.

3. Open the displayed authorization URL in the local browser and approve it.

4. After OpenCode confirms the connection, stop the temporary SSH tunnel with
   `Ctrl-C`.

The browser callback travels through port `1455`, but the resulting OpenAI
credential is stored by the OpenCode server on the VM. Do not commit or copy
that runtime authentication state into this repository.
