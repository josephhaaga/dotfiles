# oh-my-zsh setup
export ZSH=$HOME/.oh-my-zsh

ZSH_THEME="robbyrussell"

ZSH_DISABLE_COMPFIX=true

plugins=(
    git
    shrink-path
    jira
)

source $ZSH/oh-my-zsh.sh


# User configuration
# DEFAULT_USER=`whoami`

# Python environment
export PYTHONDONTWRITEBYTECODE=1

# Custom Aliases
alias vim="nvim"
alias vi="nvim"
alias vimdiff='nvim -d'
export EDITOR=nvim
alias lx="ls -latch | vi -"
alias save="~/Documents/dotfiles/scripts/save.sh"
alias load="~/Documents/dotfiles/scripts/load.sh"
alias notes="vi ~/Documents/Journal/notes"
alias ideas="vi ~/Documents/Journal/notes/Ideas.md"
alias fish="asciiquarium"
alias speedread="/usr/local/Homebrew/Library/Taps/homebrew/homebrew-core/Formula/speedread.rb"
alias dotfiles="echo 'H' | nvim -c 'Neotree' -s - ~/Documents/dotfiles"

# zsh-histdb
if test -f $HOME/.oh-my-zsh/custom/plugins/zsh-histdb/sqlite-history.zsh; then
    HISTDB_TABULATE_CMD=(sed -e $'s/\x1f/\t/g')
    source $HOME/.oh-my-zsh/custom/plugins/zsh-histdb/sqlite-history.zsh
fi
autoload -Uz add-zsh-hook
