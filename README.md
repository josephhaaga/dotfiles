# dotfiles

Repeatable macOS development-environment configuration, managed with [chezmoi](https://www.chezmoi.io).

## Setup

```bash
brew install chezmoi age
ln -s ~/Documents/dotfiles ~/.local/share/chezmoi   # keep the git repo at this fixed path
mkdir -p ~/.config/chezmoi
# Restore the age private key from 1Password to ~/.config/chezmoi/key.txt (chmod 600)
# before running init, or secrets won't decrypt. See docs/secrets.md.
chezmoi init --apply
```

`chezmoi init` prompts once for whether this is a work machine (`work = true/false`, stored in `~/.config/chezmoi/chezmoi.toml`) and persists your answer — see `AGENTS.md` for what that controls. `chezmoi apply` then symlinks nothing; it renders/copies every managed file from `home/` to `$HOME`, installs Homebrew if missing, runs `brew bundle` from the declared package list, and runs the one-time setup scripts (oh-my-zsh, Plannotator, `uv` CLIs, `gh` extensions).

## Day-to-day

```bash
chezmoi diff                           # Preview pending changes before applying
chezmoi apply                          # Apply local edits under home/ to $HOME
chezmoi update                         # git pull + apply — the new scripts/update.sh
bash scripts/load.sh                   # Pull latest for both dotfiles and journal repos
bash scripts/reconcile.sh              # Report undeclared Homebrew and App Store state
bash scripts/validate.sh               # Validate syntax and scan secrets when gitleaks is installed
bash scripts/validate.sh --check-installed  # Also compare installed packages to the rendered Brewfile
bash scripts/status.sh                 # Health check: yabai/skhd, git config, chezmoi drift
```

To edit a dotfile day-to-day, prefer `chezmoi edit --apply <target-path>` (e.g. `chezmoi edit --apply ~/.config/nvim/init.lua`) over editing the deployed file directly — chezmoi renders `home/` to `$HOME`, it doesn't symlink, so direct edits to the deployed file won't make it back into this repo without `chezmoi re-add`.

Managed macOS preferences are in `scripts/macos-defaults.sh`; managed yabai/skhd services are controlled with `scripts/window-manager.sh` (both are invoked automatically by chezmoi's `.chezmoiscripts/`, but can be run standalone too). See `docs/secrets.md` for how encrypted files are handled.

To install tmux plugins, open `tmux` and hit **Prefix** + <kbd>I</kbd>.

- If you don't see anything, open `tmux` and then try running `tmux source ~/.config/tmux/tmux.conf` [as per the tpm README](https://github.com/tmux-plugins/tpm/blob/b699a7e01c253ffb7818b02d62bce24190ec1019/README.md?plain=1#L39)

## Resources

[How to install Vim plugins](https://linuxhint.com/vim_install_plugins/)  
[Intro to tmux](https://www.hamvocke.com/blog/a-quick-and-easy-guide-to-tmux/)  
[Install Powerline fonts for Agnoster-based oh-my-zsh themes](https://fmacedoo.medium.com/oh-my-zsh-with-powerline-fonts-pretty-simple-as-you-deserve-fbe7f6d23723)  
[VimAwesome – list of Vim resources](https://vimawesome.com/plugin/youcompleteme#installation)

## TODO

- scripts (e.g. journal, tomorrow, notes) are on path, or aliased
- profile and speed up new window/tab creation

## Tutorials

### tmux

<kbd>Control</kbd> + <kbd>b</kbd> is my **Prefix**. (a.k.a <kbd>C-b</kbd>)

```bash
# start tmux
$ tmux

# list sessions
$ tmux ls

# attach to previous session
$ tmux a

# delete all sessions except current one
$ tmux kill-session -a
```

**Split horizontally**: **Prefix** + <kbd>|</kbd>  
**Split vertically**: **Prefix** + <kbd>-</kbd>  
**Switch pane**: **Prefix** + <kbd>h,j,k,l</kbd>  
**Move pane left**: **Prefix** + <kbd>shift</kbd> + <kbd>[</kbd>  
**Flip panes horizontally**: **Prefix** + <kbd>cmd</kbd> + <kbd>o</kbd>  
**Switch split orientation**: **Prefix** + <kbd>Space</kbd>  
**Enter select mode**: **Prefix** + <kbd>[</kbd>  
**Begin selection**: <kbd>v</kbd>  
**Begin line selection**: <kbd>V</kbd>  
**Exit select mode**: <kbd>q</kbd>  
**Create new window**: **Prefix** + <kbd>c</kbd>  
**See all commands**: **Prefix** + <kbd>?</kbd>  
**Start recording pane**: `:pipe-pane 'cat >~/mypanelog`  
**Stop recording pane**: `:pipe-pane`  
**Renumber windows starting at 1**: **Prefix** + `:move-window -r`  
**Move window to**: **Prefix** + <kbd>.</kbd>
**Help**: **Prefix** + <kbd>?</kbd>

#### floating window

**Open a floating `journal`**: **Prefix** + <kbd>Control</kbd> + <kbd>j</kbd>
**Open a floating terminal**: **Prefix** + <kbd>Control</kbd> + <kbd>t</kbd>
**Open a floating `lazygit`**: **Prefix** + <kbd>Control</kbd> + <kbd>y</kbd>
**Open a floating `ipython`**: **Prefix** + <kbd>Control</kbd> + <kbd>p</kbd>

#### other commands

`list-keys` to view all key bindings

<https://tmuxcheatsheet.com/>

### brew

I use Homebrew, the popular OS X package manager, to install most of my desktop applications (e.g. Chrome).

Run `brew bundle` in a directory containing a `Brewfile` to install all listed applications.

Run `brew bundle dump` to generate a `Brewfile`

`yabai` and `skhd` are installed from `asmvik/formulae` and managed through their native launchd commands.

```bash
~/Documents/dotfiles/scripts/window-manager.sh status
~/Documents/dotfiles/scripts/window-manager.sh restart
~/Documents/dotfiles/scripts/window-manager.sh stop
```

The helper also cleans stale `com.koekeishiya.yabai` LaunchAgents left over from before the upstream service label changed to `com.asmvik.yabai`.

[How to use Homebrew with multiple OS X users](https://stackoverflow.com/a/44481141)

- UPDATE: now I'm using a designated admin account (`brewadmin`) to own the `brew` installation

### vim

I use neovim and `vim-plug`, a popular plugin manager written by [junegunn](https://github.com/junegunn).

**Append an exclamation point to every line**: `:%norm A!`  
**Append an exclamation point to selected lines**: <kbd>Control</kbd> + <kbd>v</kbd> (to select lines), and then `:norm A!`  
**Replace selection**: I forgot how to do this; best to just yank the text from visual mode and paste into your `:%s/HERE/replacement/g` command

- `%` means entire document
- `s` means replace
- `g` means all occurrences on a line, not just the first match
  **Open link under cursor**: <kbd>g</kbd> <kbd>x</kbd>
  **Clear and redraw screen**: <kbd>Control</kbd> + <kbd>l</kbd>

<https://neovim.io/doc/user/various.html#various>

**View all themes**: `:Telescope colorscheme`

**Set background on start**: `vi +"set background=light"`

**Set colorscheme on start**: `vi +"colorscheme peachpuff"`

### oh-my-zsh

The default shell in OS X is now `zsh`. I use a popular customization framework called `oh-my-zsh` for terminal theming, handy aliases etc.

**Reload** by running `omz reload`

### Terminal.app

Themes are from [lysyi3m/macos-terminal-themes](https://github.com/lysyi3m/macos-terminal-themes)

### Misc

`nodemon` can run a command when a file/directory changes

- `nodemon -w my_directory -e .py -x "clear; python3 my_directory/t.py"`
