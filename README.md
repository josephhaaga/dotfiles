# dotfiles
Repeatable dev environment config

## Installation
```bash
cd ~/Documents
git clone https://github.com/josephhaaga/dotfiles
brew bundle
cd ~
ln -s ~/Documents/dotfiles/.* ~
ln -s ~/Documents/dotfiles/spacebarrc ~/.config/spacebar/spacebarrc
rm -rf ~/.git

# install tmux plugin manager
cd ~
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# start window manager (yabai) + hotkey manager (skhd)
brew services start --all

# hide OS X menubar
defaults write NSGlobalDomain _HIHideMenuBar -bool true
```

To install the Terminal.app theme, open Terminal, go to Terminal > Preferences > Profiles and click Import under the `...` button at the bottom

To install tmux plugins, open `tmux` and hit <key>I</key>.
* If you don't see anything, open `tmux` and then try running `tmux source ~/.tmux.conf` [as per the tpm README](https://github.com/tmux-plugins/tpm/blob/b699a7e01c253ffb7818b02d62bce24190ec1019/README.md?plain=1#L39)


## Resources
[How to install Vim plugins](https://linuxhint.com/vim_install_plugins/)
[Intro to tmux](https://www.hamvocke.com/blog/a-quick-and-easy-guide-to-tmux/)

## TODO
- better articulate dependencies (e.g. pyenv) that cause `.zshrc` errors on Terminal start
- install zsh
- install oh-my-zsh
- update .zshrc
- scripts (e.g. journal, tomorrow, notes) are on path, or aliased
- figure out the .oh-my-zsh submodule, and find a better location for josephhaaga.zsh-theme 


## Tutorials
### tmux
<key>Control</key> + <key>b</key> is my **Prefix**. (a.k.a <key>C-b</key>)

```bash
# start tmux
$ tmux
```

**Split horizontally**: **Prefix** + <key>|</key>
**Split vertically**: **Prefix** + <key>-</key>
**Switch pane**: **Prefix** + <key>h,j,k,l</key>
**Enter select mode**: **Prefix** + <key>[</key>
**Begin selection**: <key>v</key>
**Begin line selection**: <key>V</key>
**Exit select mode**: <key>q</key>
**Create new window**: **Prefix** + <key>c</key>
**See all commands**: **Prefix** + <key>?</key>


### brew
Run `brew bundle` in a directory containing a `Brewfile` to install all listed applications.

Run `brew bundle dump` to generate a `Brewfile`

Run `brew services` to see all services (including `skhd`, `yabai`, `spacebar` etc.
* `brew services stop --all` and `brew services start --all` usually fixes any issues
