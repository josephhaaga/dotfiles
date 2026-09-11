# VM-hosted reports

The VM can publish self-contained reports to approved devices through the same
mTLS-protected Caddy endpoint as OpenChamber. This is intended for durable HTML
artifacts that should be readable from a laptop, tablet, or phone without an
SSH session or a separate application server.

## Publishing contract

A published report must satisfy these requirements:

- Store the artifact as `reports/<descriptive-slug>.html` in this repository.
- Make the HTML self-contained so it does not depend on a local development
  server, build output, or files outside `reports/`.
- Include a responsive viewport and verify that the primary content works at a
  phone-sized width.
- Treat the report as repository content: review it for credentials, private
  data, unintended prompts, and machine-specific paths before committing it.
- Use relative links for supporting files if a report needs assets under its
  own `reports/<descriptive-slug>/` directory.

The endpoint is access-controlled, not a secret store. Reports must not contain
API keys, OAuth tokens, private keys, passwords, cookies, or regulated client
data. Device certificates can be lost or copied, and repository history is
durable.

## Request flow

```text
Approved device
  -> https://josephhaaga.sh.tribe.ai/reports/
  -> Caddy mTLS verification
  -> strip the /reports prefix
  -> serve from <dotfiles checkout>/reports/
```

Caddy exposes a directory index at `/reports/` so adding a report does not
require another route. The report URL follows directly from its repository
path:

```text
reports/dotfiles-field-guide.html
  -> https://josephhaaga.sh.tribe.ai/reports/dotfiles-field-guide.html
```

The historical `/dotfiles-report` and `/dotfiles-report/` paths redirect to
that canonical URL.

## Publish a report

1. Generate or copy a self-contained HTML artifact into `reports/` with a
   descriptive, stable filename.
2. Open it locally at desktop and mobile widths and check its links, overflow,
   contrast, and touch targets.
3. Run `bash scripts/validate.sh` to scan tracked configuration and report
   content for leaked secrets.
4. Commit and push the report, then update the VM checkout with `git pull
   --ff-only`.
5. Open `https://josephhaaga.sh.tribe.ai/reports/` from each approved device.

Report-only updates are visible as soon as the VM checkout changes because
Caddy reads the directory directly. Run `chezmoi apply --source "$PWD"` when
the Caddy template or another managed configuration file changes; the server
profile validates and reloads Caddy during that apply.

## Device access

Each device needs its own client certificate signed by the trusted client CA.
On iPhone and iPad, install the device-specific `.p12` identity and approve the
certificate profile before opening the site in Safari. Never reuse or commit a
device identity. See [VM web access](vm-web-access.md) for certificate and
private-key boundaries.

## Removing a report

Delete the artifact, commit and push the deletion, and update the VM checkout.
Removing the file makes the URL return `404`; Git history still retains the
old content, which is why sensitive data must never be published in the first
place.
