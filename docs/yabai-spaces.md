# Spaces Lab

Launch the local browser editor from the repository:

```sh
bash scripts/yabai-spaces.sh
```

The server binds to `127.0.0.1` on an available port and opens your browser. Stop it with Ctrl-C. Use `--no-open` to print the URL without opening a browser, or `--port 8765` for a fixed port. Python 3 is the only editor dependency. Yabai supplies the optional live inventory and focus tests.

## Configure a plan

1. Click **Try a starter plan**, **Use my current spaces**, or **Add space**.
2. Select a space to edit its purpose, existing desktop index, and jump shortcut.
3. Add app shortcuts using exact app names from the live inventory. Type a shortcut like `ctrl + alt - t`, or press it while its input is focused.
4. Click **Preview changes** to catch conflicting keys, then **Save to source**.

An empty shortcut leaves that destination without a keybind. Removing a proposed space removes its draft app shortcuts, never the live desktop. The initial committed plan is empty: installing the tool does not claim any new hotkeys.

App shortcuts focus an existing app window wherever it lives, preferring the already focused window, otherwise the lowest window ID. If no window exists, they activate or launch the app with `open -a`. An optional title substring narrows the window search; a missing match reports an error instead of launching. A purpose shortcut focuses its space.

**Test jump** and **Test app focus** immediately change focus (or open an app). They use the current unsaved draft and do not install its keys. Pressing a shortcut in the editor records it; it does not simulate an OS-wide skhd binding. Existing OS hotkeys may intercept a recorded chord, so typing the notation always remains available.

**Route future windows** is off by default. After applying and restoring, it registers a yabai rule for newly created windows only. It does not move existing windows. If several matching routes target different spaces, yabai's later rule wins; use distinct title filters to avoid overlap.

## Apply only the tool files

Review the source changes first:

```sh
git diff -- home/dot_config/yabai/space-shortcuts.json home/executable_dot_skhdrc
```

Preview the scoped deployment from the repository root:

```sh
chezmoi apply --dry-run --source "$PWD" --override-data '{"profile":"desktop"}' \
  "$HOME/.skhdrc" \
  "$HOME/.config/yabai/space-shortcuts.json" \
  "$HOME/.config/yabai/yabairc" \
  "$HOME/.local/bin/space-shortcuts" \
  "$HOME/.local/lib/dotfiles/space_shortcuts.py" \
  "$HOME/.local/share/yabai-spaces/index.html"
```

Use `enterprise` instead of `desktop` on an enterprise-profile Mac. After reviewing, run the same command without `--dry-run`. Then restore labels/routing and reload skhd:

```sh
"$HOME/.local/bin/space-shortcuts" restore
skhd --reload
```

Yabai's managed startup configuration also restores the plan on restart. This tool never creates or destroys spaces and never runs privileged commands. Space focusing/routing depends on the permissions and scripting-addition capabilities of your existing yabai installation. Failures are reported, not treated as successful tests.

## Space numbering

Indices include native-fullscreen spaces and can change when displays or fullscreen windows change. Compare against the live inventory; do not assume desktop 2 is your second regular desktop. Draft tests use the numeric index. Applied purpose shortcuts prefer their `spaceslab-<id>` label, which survives renumbering while yabai is running. Restoring reassigns labels by the plan's numeric indices, so recheck the plan after changing display topology or fullscreen arrangement. Disable macOS **Automatically rearrange Spaces based on most recent use** for more predictable indices.

## Safety and validation

The editor saves only the two source files listed above. It preserves everything outside the marked skhd block and rejects stale saves after another process changes the source. It does not modify deployed files, run chezmoi, reload services, persist inventory, or collect window titles. App/title strings are passed as subprocess arguments, not shell commands. The loopback server checks Host, Origin, and a per-launch token; it exposes no arbitrary filesystem or command endpoint. Do not expose or proxy it onto a network.

Conflict detection covers the existing direct bindings in this repository's skhd file. It does not inspect macOS system shortcuts or independent skhd `.load` files/modes. Existing unrelated duplicate keys are not rewritten.

Run the no-mutation tests:

```sh
python3 -m unittest discover -s tests -p 'test_space_shortcuts.py'
bash scripts/validate.sh
```
