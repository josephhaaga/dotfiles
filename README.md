# dotfiles

Repeatable dev environment config

## Installation

```bash
# Clone the repository
cd ~/Documents
git clone https://github.com/josephhaaga/dotfiles && cd dotfiles

# Install Homebrew, a package manager for macOS
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
(echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"

# Brew dependencies
brew bundle --file=.config/brew/Brewfile
# Example packages: yabai (window manager), nvim (vim-based IDE), skhd (hotkey manager), ghostty (terminal), uv (CLI config)
brew bundle

# brew bundle --force cleanup
# https://gist.github.com/ChristopherA/a579274536aab36ea9966f301ff14f3f

# install oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Restart Terminal.app to reload .zshrc
rest

# Symlink config files to user directory
ln -s ~/Documents/dotfiles/.config ~

# install tmux plugins
# Run <C-b> + I to install Tmux plugins

# yabai: install scripting addition (enables most features)
echo "$(whoami) ALL=(root) NOPASSWD: sha256:$(shasum -a 256 $(which yabai) | cut -d " " -f 1) $(which yabai) --load-sa" | sudo tee /private/etc/sudoers.d/yabai
# start window manager (yabai) + hotkey manager (skhd)
yabai --start-service
skhd --start-service

# re-install neovim to fix python-provider (powers many vim plugins)
$ python3 -m pip install --user --upgrade pynvim
$ brew reinstall neovim

# install Vim plugins via vim-plug
vim -c ':PlugInstall'
```

## Quick Start

Use the new scripts for quick setup and updates:

```bash
# Install your entire environment from scratch
bash scripts/install.sh

# Update your machine to the latest configuration
bash scripts/update.sh

# Install the configuration:
bash scripts/install.sh

# Update your setup as needed:
bash scripts/update.sh
```

Use the new scripts for quick setup and updates:

```bash
# Install your entire environment from scratch
bash scripts/install.sh

# Update your machine to the latest configuration
bash scripts/update.sh
```

## Prompts Directory

The `prompts/` directory is for storing reusable prompt templates and workflows. Subdirectories include:

- `actions/`: Task-specific prompts, e.g., refactoring, committing, or testing.
- `rules/`: Guidelines for coding styles, standards, or language-specific rules.

To install tmux plugins, open `tmux` and hit **Prefix** + <kbd>I</kbd>.

- If you don't see anything, open `tmux` and then try running `tmux source ~/.tmux.conf` [as per the tpm README](https://github.com/tmux-plugins/tpm/blob/b699a7e01c253ffb7818b02d62bce24190ec1019/README.md?plain=1#L39)

## Resources

[How to install Vim plugins](https://linuxhint.com/vim_install_plugins/)  
[Intro to tmux](https://www.hamvocke.com/blog/a-quick-and-easy-guide-to-tmux/)  
[Install Powerline fonts for Agnoster-based oh-my-zsh themes](https://fmacedoo.medium.com/oh-my-zsh-with-powerline-fonts-pretty-simple-as-you-deserve-fbe7f6d23723)  
[VimAwesome – list of Vim resources](https://vimawesome.com/plugin/youcompleteme#installation)

## TODO

- better articulate dependencies that cause `.zshrc` errors on Terminal start
  - `brew` installs neovim, but we need to set the global python and re-install neovim so YouCompleteMe installs can compile
- install zsh
- install oh-my-zsh
- update .zshrc
- scripts (e.g. journal, tomorrow, notes) are on path, or aliased
- figure out the .oh-my-zsh submodule, and find a better location for josephhaaga.zsh-theme
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

Run `brew services` to see all services (including `skhd`, `yabai`, `spacebar` etc.

- `brew services stop --all` and `brew services start --all` usually fixes any issues

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

**Customize PS1** by altering `prompt_context()` in `josephhaaga.zsh-theme`

- the `%m` characters are called "prompt sequences" ([see "Expansion of Prompt Sequences" in `man zshmisc`](https://stackoverflow.com/questions/13660636/what-is-percent-tilde-in-zsh))

### Terminal.app

Themes are from [lysyi3m/macos-terminal-themes](https://github.com/lysyi3m/macos-terminal-themes)

### Misc

`nodemon` can run a command when a file/directory changes

- `nodemon -w my_directory -e .py -x "clear; python3 my_directory/t.py"`
