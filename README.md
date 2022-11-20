
## Installation
```bash
cd ~/Documents
git clone https;//github.com/josephhaaga/dotfiles
cd ~
ln -s ~/Documents/dotfiles/.* ~
rm -rf .git
mkdir -p ~/.oh-my-zsh/custom
ln -s ~/Documents/dotfiles/omzcustom/custom/* ~/.oh-my-zsh/custom
```

To install the Terminal.app theme, open Terminal, go to Terminal > Preferences > Profiles and click Import under the `...` button at the bottom


## Resources
[How to install Vim plugins](https://linuxhint.com/vim_install_plugins/)

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

