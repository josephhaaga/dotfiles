# OpenCode VM connections

OpenCode on the VM is reachable through three independent connection paths.
They serve different clients, use different authentication, and must not be
combined into one tunnel.

| Method | Local entry point | VM destination | Lifetime |
| --- | --- | --- | --- |
| Local TUI | `http://127.0.0.1:14096` | `127.0.0.1:49374` | Persistent LaunchAgent |
| OpenAI OAuth | `http://localhost:1455/auth/callback` | `127.0.0.1:1455` | Temporary manual tunnel |

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
   opencode --server http://127.0.0.1:14096
```

The env file contains only a 1Password secret reference. Create an `OpenCode
VM` item in the `Employee` vault and set its `password` field to the password
shown by `opencode pair` on the VM. The resolved password exists only in the
client process environment.

## OpenAI browser OAuth

The local TUI connects to the source-managed OpenCode V2 server on the VM
(`127.0.0.1:49374`).

The server's pairing password is a VM-local runtime value in
`~/.config/opencode/server.env`. Both user services read it; the file is never
managed by chezmoi or committed.

OpenAI redirects browser authentication to the fixed loopback URL
`http://localhost:1455/auth/callback`. For authentication initiated by the
VM-hosted OpenCode server, temporarily forward that local port to the VM.

1. In a local terminal, initiate browser OAuth against that server:

   ```bash
   ssh -t \
     -o ExitOnForwardFailure=yes \
     -L 1455:127.0.0.1:1455 \
     ec2-user@josephhaaga.sh.tribe.ai \
     '$HOME/.local/bin/opencode auth login \
       --provider openai --method "ChatGPT Pro/Plus (browser)"'
   ```

2. Open the displayed authorization URL in the local browser and approve it.

3. Wait for OpenCode to confirm the connection. The temporary SSH tunnel exits
   with the authentication command.

The browser callback travels through port `1455`, but the resulting OpenAI
credential is stored in the VM's shared OpenCode runtime. Do not commit or copy
that runtime authentication state into this repository.
