# whisp

Local, config-driven voice dictation for macOS with **LLM-powered rewriting** —
a free, no-trial, dotfiles-managed alternative to Superwhisper.

- **STT:** [whisper.cpp](https://github.com/ggml-org/whisper.cpp) (`whisper-cli`), fully local.
- **Rewrite:** per-Mode LLM via a local [Ollama](https://ollama.com) model *or* any
  OpenAI-compatible API (BYOK).
- **Trigger:** a single **skhd modal chord** — `Control + V`, then a letter picks a Mode.
- **Overlay:** an [Übersicht](https://tracesof.net/uebersicht/) widget styled like the
  native macOS OSD/HUD (think "AirPods moved to iPhone"), showing a LazyVim-style which-key
  list and live status.
- **Output:** result is copied to the clipboard and pasted into the focused app (`skhd -k`).

Everything here lives in the dotfiles repo and installs via `brew bundle`.

## How it works

```
Control + V                  enter the "whisp" chord (overlay shows the mode list)
  press r / c / e / w        pick a Mode → start recording (OSD: ● Recording)
  speak…
  Control + Shift + V        stop → transcribe → rewrite → paste
    (or press the same mode letter again to stop)
```

Pipeline: `sox` captures mic → `whisper-cli` transcribes → `whisp-rewrite.sh` applies the
Mode's prompt via its provider → text is pasted at the cursor. If anything fails (model
missing, Ollama down, no API key), it falls back to the **verbatim transcript** — you never
lose your words.

## Default Modes (`modes.json`)

| Key | Mode         | Provider | What it does |
|-----|--------------|----------|--------------|
| `r` | Ramble       | ollama   | Clean rambling speech into clear prose |
| `c` | Code changes | ollama   | Summarize as a commit message |
| `e` | Email        | openai   | Rewrite as a professional email body |
| `w` | Raw          | none     | Verbatim transcription, no rewrite |

## Configuration

All Modes and providers live in [`modes.json`](./modes.json). The provider schema mirrors
OpenCode: a `provider` map keyed by ID with `type`, `baseURL`, `model`, and an `apiKey` that
supports `{env:VAR}` and `{file:~/path}` substitution.

```jsonc
{
  "chord": "ctrl - v",
  "defaults": { "stt": { "model": "ggml-large-v3-turbo.bin", "language": "en" } },
  "provider": {
    "ollama": { "type": "ollama", "baseURL": "http://localhost:11434", "model": "llama3.1:8b" },
    "openai": { "type": "openai-compatible", "baseURL": "https://api.openai.com/v1",
                "model": "gpt-4o-mini", "apiKey": "{env:OPENAI_API_KEY}" }
  },
  "modes": {
    "ramble": { "key": "r", "label": "Ramble", "icon": "text.bubble",
                "provider": "ollama", "prompt": "…" }
  }
}
```

### Add a Mode

1. Add an entry under `modes` with a unique `key`, a `label`, an `icon`, a `provider`, and a
   `prompt` (omit `prompt` and set `"provider": "none"` for verbatim).
2. Mirror the hotkey in [`../skhd/skhdrc`](../skhd/skhdrc) inside the `whisp` block:
   `whisp < <key> : ~/.config/whisp/bin/whisp-record.sh <modeId> ; skhd -k "escape"`
3. `skhd --reload`.

### Providers & API keys (BYOK)

`apiKey` is resolved in this order:

1. Literal value, or `{env:VAR}` (e.g. export `OPENAI_API_KEY` from `~/.config/zsh/.secrets`).
2. `{file:~/path}` (e.g. `{file:~/.config/whisp/.groq-key}` — git-ignored).
3. macOS Keychain, service `whisp-<providerId>`:
   ```sh
   security add-generic-password -a "$USER" -s whisp-openai -w 'sk-…'
   ```

If no key resolves for an `openai-compatible` provider, that Mode falls back to verbatim.

Local Ollama models need no key; the rewrite step lazy-starts `ollama serve` if it isn't
already running (or run it as a service: `brew services start ollama`).

## Install

Dependencies are in the repo Brewfile and installed by `brew bundle`:
`whisper-cpp`, `sox`, `ollama`, and the `ubersicht` cask.

`scripts/install.sh` then:
- makes `bin/*.sh` executable,
- symlinks `ubersicht/whisp.widget` into Übersicht's widgets folder,
- downloads the default Whisper model into `models/` (~1.6 GB, guarded),
- pulls `llama3.1:8b` via Ollama (guarded),
- reloads skhd.

### One-time macOS permissions

- **Microphone** → enable **skhd** (it runs `sox`).
- **Accessibility** → enable **skhd** (keystroke synthesis; already needed for yabai).
- **Screen Recording** → enable **Übersicht** (to draw the desktop overlay).

## Files

```
configs/whisp/
├── modes.json                 # Modes + providers (edit this)
├── config.sh                  # paths / tunables
├── bin/
│   ├── whisp-record.sh        # toggle record/stop + pipeline orchestration
│   ├── whisp-transcribe.sh    # whisper-cli wrapper → raw transcript
│   ├── whisp-rewrite.sh       # provider-based LLM rewrite (ollama|openai|none)
│   ├── whisp-status.sh        # writes status.json for the overlay
│   └── whisp-lib.sh           # shared helpers (subst, jq getters, keys, status)
├── ubersicht/whisp.widget/index.jsx   # native-OSD which-key + status overlay
└── models/                    # GGML model(s), git-ignored
```

Runtime state lives in `/tmp/whisp/` (`clip.wav`, `status.json`, `debug.log`, …).

## Tunables (env, see `config.sh`)

- `WHISP_MAX_SECONDS` (default 120) — safety auto-stop cap.
- `WHISP_SAMPLE_RATE` (16000) — capture rate (whisper wants 16 kHz mono).
- `WHISP_HTTP_TIMEOUT` (60) — LLM request timeout.
- `WHISP_INSERTED_FADE` (1) — seconds the "Inserted" OSD lingers.

## Troubleshooting

- Nothing happens on `Control+V`: confirm skhd reloaded (`skhd --reload`) and has Accessibility.
- No overlay: ensure Übersicht is running and has Screen Recording permission; the widget is
  symlinked into its widgets folder.
- Empty/odd transcript: check the model exists in `models/`; see `/tmp/whisp/debug.log`.
- Rewrite returns verbatim: Ollama not running, or no API key resolved — see `debug.log`.
