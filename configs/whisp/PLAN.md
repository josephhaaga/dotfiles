# Plan: Local, config-driven voice dictation with LLM rewrite ("whisp")

Replace OpenTypeless with a **100% free, no-trial, fully local-capable, dotfiles-managed**
voice dictation stack with **Superwhisper-style LLM rewriting**, where all **Modes/Scenes
are config files** in this repo.

Trigger model: a **single skhd modal chord** (`Control + V` → press a letter to pick a Mode),
with a **LazyVim which-key-style hint overlay** rendered via **Übersicht**, styled to match
the **native macOS OSD/HUD** (e.g. the "AirPods moved to iPhone" panel).

Everything installs via Homebrew (`brew bundle`).

---

## Goals / constraints (from the user)

- 100% free, no trial limits.
- Config-file driven Modes/Scenes, living in the dotfiles repo.
- Installable via Homebrew (custom tap/cask allowed; here only formulae/casks are needed).
- LLM-powered rewriting (the core value of Superwhisper et al.).
- STT engine: **whisper-cpp via Homebrew**.
- Trigger: **skhd modal chord** — `Control + V` starts the chord, then a single letter
  selects a Mode (e.g. `r` = ramble, `c` = code changes, …).
- Mode discovery: **Übersicht** overlay listing the chord options, unobtrusive, which-key style.
- Overlay look: **native macOS OSD/HUD** styling (dark translucent rounded panel, centered,
  SF-style glyph, brief auto-fade) — not a Notification Center banner.
- LLM backend: **both** local (Ollama) and BYOK cloud, selectable per-Mode.
- BYOK key storage: **both** env var/`.secrets` and macOS Keychain supported.
- Provider config: **standardized like OpenCode** (`baseURL` + `model` + `{env:…}`/`{file:…}` key).
- Paste: **clipboard + `skhd -k` Cmd+V**.

### Why a custom stack (not VoiceInk/Whispree/Handy)

- `Handy` (already in Brewfile) and `whisp`(Hammerspoon) are **transcription-only** — no LLM rewrite.
- `VoiceInk` has LLM rewrite + Ollama, but ships a **paid trial/license** and stores Modes in an app DB.
- `Whispree` has Modes incl. custom prompts but is **app-managed** and partly OpenAI-oriented.
- None store Modes as plain dotfiles config. The custom stack satisfies **all** constraints with
  shell scripts + JSON config + an Übersicht widget; no app to package/sign.

---

## Architecture

```
Control + V                     ── enter skhd "whisp" mode (modal)
   └─ Übersicht overlay appears: native-OSD panel listing Mode letters (which-key)
   └─ press a letter (r/c/e/…)  ── selects Mode, exits mode, runs whisp-record.sh <mode> (toggle)
        not recording? → start sox capture → /tmp/whisp/clip.wav; OSD shows "● Recording — <Mode>"
        recording?     → stop capture, then pipeline:
              whisper-cli (local STT) → raw transcript
                 └─ rewrite per Mode (provider-based):
                       provider.type=ollama          → POST {baseURL}/api/chat (local)
                       provider.type=openai-compatible → POST {baseURL}/chat/completions (BYOK/local)
                       key via {env:VAR} or {file:~/…} or macOS Keychain
                    └─ final text → pbcopy → skhd -k "cmd - v"; OSD shows "✓ Inserted — <Mode>"
```

- Same-key toggle: pressing the chosen Mode letter again stops + processes (we re-enter the
  chord and press the same letter; documented). The active recording is also stoppable via a
  dedicated stop binding (below).
- **State dir:** `/tmp/whisp/` (clip.wav, whisp.pid, mode, status.json, raw.txt, out.txt, debug.log).
- **Status surface:** the Übersicht widget reads `/tmp/whisp/status.json` and renders the OSD
  panel (chord hints, recording, transcribing, inserted, error). Pipeline is local-first; cloud
  only when a Mode opts in.

---

## Homebrew dependencies (added to `configs/brew/Brewfile`)

```ruby
# Local voice dictation ("whisp")
brew "whisper-cpp"   # local STT (whisper-cli)
brew "sox"           # mic capture (rec/sox)
brew "ollama"        # local LLM rewrite backend (optional but default)
cask "ubersicht"     # desktop widget host for the which-key / OSD overlay
# jq already present (parse modes.json / write status.json)
# curl is system-provided (LLM HTTP calls)
```

Notes:
- `whisper-cpp` provides `whisper-cli` and needs a GGML model file (not bundled).
- `ollama` optional at runtime: `provider.type=none` skips LLM; `openai-compatible` uses cloud
  or a local OpenAI server. Installed so local rewrite works out of the box.
- `ubersicht` hosts the overlay widget; widget files live in dotfiles (symlinked — see below).
- No `cliclick` (paste uses `skhd -k`).
- Ollama runtime: plan documents `brew services start ollama`; scripts also lazy-start
  `ollama serve` if the API is unreachable.

---

## Repo layout (new files under `configs/whisp/`)

`~/.config` is a symlink to `configs/`, so `configs/whisp/` is auto-available at `~/.config/whisp/`.

```
configs/whisp/
├── PLAN.md                  # this document
├── README.md               # usage, permissions, model download, mode + provider authoring
├── config.sh               # shared paths/env: model path, whisper flags, state dir, widget paths
├── modes.json              # *** Modes/Scenes + providers config (the thing you edit) ***
├── bin/
│   ├── whisp-mode.sh       # (optional) helper to render chord list + write status for overlay
│   ├── whisp-record.sh     # toggle: start/stop recording; on stop, run pipeline
│   ├── whisp-transcribe.sh # wraps whisper-cli → raw transcript
│   ├── whisp-rewrite.sh    # applies a Mode's prompt via its provider (ollama|openai-compatible|none)
│   ├── whisp-status.sh     # writes /tmp/whisp/status.json (state machine for the OSD)
│   └── whisp-lib.sh        # shared helpers (status, state, jq getters, key resolution, value subst)
├── ubersicht/
│   └── whisp.widget/
│       └── index.jsx       # Übersicht widget: native-OSD panel; reads status.json
└── models/                 # .gitignored; GGML model(s) downloaded here
    └── .gitkeep
```

Übersicht loads widgets from `~/Library/Application Support/Übersicht/widgets/`. Since that
path is **outside** `~/.config`, the single top-level symlink doesn't cover it. Plan:
- `scripts/install.sh` adds a symlink:
  `ln -sfn ~/.config/whisp/ubersicht/whisp.widget "~/Library/Application Support/Übersicht/widgets/whisp.widget"`
  (so the widget source stays version-controlled in dotfiles).

`.gitignore` additions (local `configs/whisp/.gitignore`):
- `models/*.bin`, `*.wav`, `debug.log`, `status.json`

---

## Modes/Scenes + provider config (`configs/whisp/modes.json`)

Standardized after **OpenCode**: a top-level `provider` map keyed by an ID, each with
`type`, `baseURL`, `model`, and an `apiKey` that supports `{env:VAR}` and `{file:~/path}`
substitution. Each Mode references a provider by ID and supplies a `prompt`. Mode also
carries its chord `key` and `label`/`icon` for the overlay.

```json
{
  "$schema": "./whisp.schema.json",
  "chord": "ctrl - v",
  "defaults": {
    "stt": { "model": "ggml-large-v3-turbo.bin", "language": "en" },
    "provider": "ollama"
  },
  "provider": {
    "ollama": {
      "type": "ollama",
      "baseURL": "http://localhost:11434",
      "model": "llama3.1:8b"
    },
    "openai": {
      "type": "openai-compatible",
      "baseURL": "https://api.openai.com/v1",
      "model": "gpt-4o-mini",
      "apiKey": "{env:OPENAI_API_KEY}"
    },
    "groq": {
      "type": "openai-compatible",
      "baseURL": "https://api.groq.com/openai/v1",
      "model": "llama-3.3-70b-versatile",
      "apiKey": "{file:~/.config/whisp/.groq-key}"
    }
  },
  "modes": {
    "ramble": {
      "key": "r",
      "label": "Ramble",
      "icon": "text.bubble",
      "description": "Clean up rambling speech into clear prose (local)",
      "provider": "ollama",
      "prompt": "Turn this rambling transcription into clear, well-punctuated prose. Remove filler words and false starts. Keep meaning and wording. Output only the text."
    },
    "code": {
      "key": "c",
      "label": "Code changes",
      "icon": "chevron.left.forwardslash.chevron.right",
      "description": "Summarize as a commit message / code-change note (local)",
      "provider": "ollama",
      "prompt": "Rewrite the transcript as a concise software commit message in imperative mood. Output only the message."
    },
    "email": {
      "key": "e",
      "label": "Email",
      "icon": "envelope",
      "description": "Professional email body (BYOK cloud)",
      "provider": "openai",
      "prompt": "Rewrite the transcript as a clear, professional email body. No greeting/sign-off unless dictated. Output only the email text."
    },
    "raw": {
      "key": "w",
      "label": "Raw",
      "icon": "waveform",
      "description": "Verbatim transcription, no rewrite",
      "provider": "none"
    }
  }
}
```

- `provider.type`: `ollama` | `openai-compatible` | (mode-level `"none"` to skip rewrite).
- Key resolution order for `apiKey`: literal/`{env:VAR}` → `{file:~/…}` → macOS Keychain
  (service `whisp-<providerId>`) → notify + verbatim fallback. Mirrors OpenCode's `{env:}`/`{file:}`.
- `chord` is the source of truth for the leader; mode `key`s are the source of truth for the
  overlay AND mirrored into the skhd modal block (initial version mirrors manually; auto-gen
  is a future enhancement).
- A small `whisp.schema.json` (optional) documents the shape for editor validation.

---

## skhd integration — modal chord (`configs/skhd/skhdrc`)

Use skhd's **modal hotkey system** (confirmed in skhd docs: `:: mode` declarations and
`mode < hotkey` bindings; `@` captures all keypresses while in the mode). Append a marked block:

```skhd
####### whisp: voice dictation (modal chord) #############
# Declare a capturing mode; on entry, show the which-key overlay
:: whisp @ : ~/.config/whisp/bin/whisp-status.sh chord

# Enter the chord with Control + V (from default mode)
ctrl - v ; whisp

# Inside whisp mode: pick a Mode by letter (mirrors modes.json keys), then return to default
whisp < r : ~/.config/whisp/bin/whisp-record.sh ramble ; skhd -k "escape" 
whisp < c : ~/.config/whisp/bin/whisp-record.sh code   ; skhd -k "escape"
whisp < e : ~/.config/whisp/bin/whisp-record.sh email  ; skhd -k "escape"
whisp < w : ~/.config/whisp/bin/whisp-record.sh raw    ; skhd -k "escape"

# Stop/cancel: leave the chord (also clears overlay)
whisp < escape : ~/.config/whisp/bin/whisp-status.sh idle
# Global stop while recording (outside the chord)
ctrl + shift - v : ~/.config/whisp/bin/whisp-record.sh stop
```

Mechanics & checks:
- `:: whisp @` enters a mode that **captures every keypress**, so stray keys don't leak to apps
  while the overlay is up; on entry it writes `status.json` state=`chord` to show the panel.
- Returning to default mode: each action runs the toggle then sends `escape` to exit the mode.
  (skhd modes are exited by switching back to `default`; exact return-syntax to be verified at
  implementation with `skhd -V`. Fallback: bind each letter to also `; default` if the version
  supports inline mode-switch.)
- Conflict check: `ctrl - v` and `ctrl + shift - v` are **not** currently bound in skhdrc
  (only `alt`/`cmd` chords exist). No yabai bindings touched.
- After editing skhdrc: `skhd --reload` (or existing `alt + shift - r`).

> Open verification item: exact skhd modal return-to-default syntax (`; default` vs sending
> `escape`). Will confirm against installed `skhd` (`-V` observe) during implementation; the
> plan keeps a documented fallback either way.

---

## Übersicht overlay — native macOS OSD/HUD style

A single widget `whisp.widget/index.jsx` polls `/tmp/whisp/status.json` (e.g. every 0.2–0.3s)
and renders a centered panel that **looks like the system OSD** (the "AirPods moved to iPhone"
HUD), not a banner.

States rendered:
- `chord`  → which-key list: each Mode as a row `key  ⟶  label` with its SF Symbol glyph.
- `recording` → pulsing red ● + "Recording — <label>" + elapsed timer.
- `transcribing` → spinner + "Transcribing…".
- `rewriting` → spinner + "Rewriting (<provider/model>)…".
- `inserted` → ✓ + "Inserted — <label>", auto-fades after ~1s.
- `error` → ⚠︎ + short message, auto-fades.

OSD visual spec (to match macOS HUD):
- Centered horizontally; vertically ~15–20% from bottom (HUD-like), configurable.
- Rounded rect ~ **18–22px corner radius**, dark translucent material
  (`background: rgba(30,30,30,0.6)` + `backdrop-filter: blur(30px) saturate(150%)`),
  subtle 1px inner hairline border, soft drop shadow.
- Large centered glyph on top (SF Symbols via system font / unicode fallback), label below in
  white ~13–15px medium; secondary text dimmed.
- Fade in ~120ms, fade out ~400ms; `pointer-events: none` so it never steals focus.
- `which-key` list uses a compact 2-column layout (key chip on the left, label on the right),
  mirroring LazyVim's popup density.

Notes:
- True SF Symbols aren't directly renderable in a webview by name; plan uses the closest
  approach that stays dependency-free: system-font SF Symbols glyphs where available, with a
  curated unicode/emoji fallback map per `icon`. (Exact glyph rendering verified during impl;
  acceptable fallback documented.)
- Widget is pure presentation; all logic/state lives in the shell scripts + `status.json`.

---

## Recording + pipeline scripts (behavioral spec)

### `whisp-status.sh <state> [args]`
- Writes `/tmp/whisp/status.json` (atomic write via temp+mv) with `{ state, mode, label, icon,
  provider, model, started_at, message }`. States: `chord|idle|recording|transcribing|rewriting|
  inserted|error`. The Übersicht widget reads this file. `chord` state also includes the full
  Mode list (from modes.json) for the which-key panel.

### `whisp-record.sh <mode|stop>`
1. Source `config.sh` + `whisp-lib.sh`.
2. `stop` (or mode while recording): stop sox, `status transcribing`,
   `raw=$(whisp-transcribe.sh clip.wav)`, `status rewriting`,
   `final=$(whisp-rewrite.sh "$mode" "$raw")`, `printf %s "$final" | pbcopy`,
   `skhd -k "cmd - v"`, `status inserted`, cleanup, then `status idle` after fade.
3. Start (not recording): validate mode in modes.json (jq) else `status error`; `mkdir -p`
   state dir; write `mode`; start `rec/sox` → `clip.wav` (16 kHz mono WAV); save PID;
   `status recording`. Optional `afplay` start/stop blips (off by default to match silent OSD).
4. Optional safety cap: max recording seconds → auto-stop+process.

### `whisp-transcribe.sh <wav>`
- `whisper-cli -m models/<STT_MODEL> -l <lang> -nt -otxt …`; echo transcript; stderr→debug.log.

### `whisp-rewrite.sh <mode> <raw>`
- Resolve Mode → provider (jq). `none` → echo `$raw`.
- `ollama`: ensure reachable (curl `{baseURL}/api/tags`; lazy-start `ollama serve`); POST
  `{baseURL}/api/chat` (system=prompt,user=raw,stream:false) → `.message.content`.
- `openai-compatible`: resolve `apiKey` (value subst → keychain); POST
  `{baseURL}/chat/completions` → `.choices[0].message.content`.
- Any error → `$raw` fallback + `status error` (never lose transcription).

### `whisp-lib.sh`
- `subst <value>`: expand `{env:VAR}` and `{file:~/path}` (OpenCode-style).
- `provider_field <id> <key>`, `mode_field <mode> <key>` (with `defaults` fallback).
- `resolve_key <providerId>`: subst(apiKey) → Keychain `whisp-<id>` → empty.
- state/status helpers; `is_recording`.

---

## BYOK key storage (both paths) + provider standardization

- **Value substitution (OpenCode-style):** `apiKey` supports `{env:OPENAI_API_KEY}` and
  `{file:~/.config/whisp/.groq-key}`. Your `~/.config/zsh/.secrets` (sops) can export the env
  var; file-based keys are git-ignored.
- **Keychain fallback:** if `apiKey` resolves empty, try
  `security find-generic-password -s whisp-<providerId> -w`. One-time setup documented:
  `security add-generic-password -a "$USER" -s whisp-openai -w 'sk-…'`.
- Nothing secret committed; `.groq-key`-style files and `status.json` are git-ignored.

---

## Install / bootstrap changes

- **Brewfile:** add `whisper-cpp`, `sox`, `ollama`, `cask "ubersicht"`.
- **scripts/install.sh** (after `brew bundle`):
  - `chmod +x ~/.config/whisp/bin/*.sh`.
  - Symlink widget into Übersicht:
    `ln -sfn ~/.config/whisp/ubersicht/whisp.widget "$HOME/Library/Application Support/Übersicht/widgets/whisp.widget"`.
  - Launch/refresh Übersicht (`open -a "Übersicht"`); note it must be granted Screen Recording
    permission to draw over the desktop (documented).
  - Guarded GGML model download into `configs/whisp/models/` (default turbo) if missing.
  - Guarded `ollama pull llama3.1:8b` (or printed suggestion).
  - Print macOS permissions reminders (Accessibility + Microphone for skhd; Screen Recording
    for Übersicht).
  - `skhd --reload`.
- **scripts/update.sh:** no change required (already runs `brew bundle` + `skhd --restart-service`).

### macOS permissions (one-time, documented in README)

- **Microphone**: granted to the process running `sox` (skhd / its launching shell).
- **Accessibility**: skhd already has it (keystroke synthesis).
- **Screen Recording**: Übersicht needs it to render the desktop overlay.
- `whisper-cli` / `ollama` need no special permission.

---

## Validation / acceptance

- `ruby -c configs/brew/Brewfile`; `brew bundle check` shows the new deps.
- `bash -n configs/whisp/bin/*.sh`; `jq . configs/whisp/modes.json` valid; each provider has
  `type`+`baseURL`+`model`; each mode has `key`+`provider`(+`prompt` unless `none`).
- Widget: `node --check configs/whisp/ubersicht/whisp.widget/index.jsx` (syntax) and a visual
  check that each `status.json` state renders the OSD panel.
- Dry runs:
  - `whisp-transcribe.sh sample.wav` → text.
  - `whisp-rewrite.sh ramble "um so like the build is broken"` → cleaned text (Ollama).
  - `whisp-rewrite.sh email "…"` → text (BYOK) or graceful verbatim fallback.
- End-to-end: `Control+V` shows OSD which-key → press `r` → speak → `Control+shift+V` (or re-chord
  `r`) → cleaned text pasted; OSD shows recording → transcribing → rewriting → inserted.
- Negative: missing model / Ollama down / missing key → verbatim + `error` OSD; never crashes.
- Overlay never steals focus (`pointer-events:none`) and auto-fades.

---

## Out of scope (initial) / future enhancements

- Auto-generating the skhd modal block from `modes.json` (initial: manual mirror).
- Hold-to-talk (key-down/up) — modal chord chosen instead.
- Streaming partial transcripts in the OSD.
- Per-app automatic Mode selection (Superwhisper "smart modes").
- Dictionary/vocab correction layer (`replacements.json`).
- Real SF Symbols rendering beyond the curated glyph fallback.

---

## Open decisions to confirm before implementation

1. **Mode set + letters**: proposed `r` ramble, `c` code changes, `e` email, `w` raw under
   `Control+V`. Add/rename any (e.g. `s` slack, `j` jira, `p` prompt)?
2. **Default STT model**: `ggml-large-v3-turbo.bin` (~1.6 GB, best) vs `ggml-base.en.bin`
   (~150 MB, fast, English-only).
3. **Default local LLM**: `llama3.1:8b` vs smaller `qwen2.5:3b` (faster/less RAM).
4. **Default cloud provider for BYOK modes**: OpenAI (`gpt-4o-mini`) vs Groq (free-tier friendly).
5. **OSD placement**: bottom-center HUD (like volume/AirPods) vs true screen-center. Default:
   bottom-center to mirror the AirPods OSD.
6. **Install aggressiveness**: auto-download model + `ollama pull` in install.sh, or print
   instructions only (keep install fast/offline-friendly)?
7. **skhd modal exit syntax**: confirm `; default` vs sending `escape` on the installed skhd
   build (documented fallback either way).
