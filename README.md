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

To install tmux plugins, open `tmux` and hit <kbd>I</kbd>.
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
**Flip panes**: **Prefix** + <kbd>shift</kbd> + <kbd>[</kbd>  
**Switch split orientation**: **Prefix** + <kbd>Space</kbd>  
**Enter select mode**: **Prefix** + <kbd>[</kbd>  
**Begin selection**: <kbd>v</kbd>  
**Begin line selection**: <kbd>V</kbd>  
**Exit select mode**: <kbd>q</kbd>  
**Create new window**: **Prefix** + <kbd>c</kbd>  
**See all commands**: **Prefix** + <kbd>?</kbd>  
**Start recording pane**: `:pipe-pane 'cat >~/mypanelog`  
**Stop recording pane**: `:pipe-pane`  
 

### brew
Run `brew bundle` in a directory containing a `Brewfile` to install all listed applications.  

Run `brew bundle dump` to generate a `Brewfile`  

Run `brew services` to see all services (including `skhd`, `yabai`, `spacebar` etc.  
* `brew services stop --all` and `brew services start --all` usually fixes any issues  

[How to use Homebrew with multiple OS X users](https://stackoverflow.com/a/44481141)


### vim
**Append an exclamation point to every line**: `:%norm A!`  
**Append an exclamation point to selected lines**: <kbd>Control</kbd> + <kbd>v</kbd> (to select lines), and then `:norm A!`  
**Replace selection**: I forgot how to do this; best to just yank the text from visual mode and paste into your `:%s/HERE/replacement/g` command
  * `%` means entire document 
  * `s` means replace 
  * `g` means all occurrences on a line, not just the first match


