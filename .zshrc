export ZSH=$HOME/.oh-my-zsh
export ZSH_CUSTOM=$HOME/Documents/dotfiles/omzcustom/custom
export HOMEBREW_MAIN_USER=brewadmin

ZSH_THEME="dst"

ZSH_DISABLE_COMPFIX=true

plugins=(
    git
    shrink-path
    jira
)

source $ZSH/oh-my-zsh.sh

# User configuration
ZSH_THEME="josephhaaga"
prompt_context(){}


# Python environment
export PYTHONDONTWRITEBYTECODE=1

## pyenv 2.3.0 setup
if ! command -v pyenv > /dev/null 2>&1; then
    echo "pyenv not installed! skipping environment configuration"
else
    export PYENV_ROOT="$HOME/.pyenv"
    command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"

    # https://gabnotes.org/how-use-pipx-pyenv/
    export PIPX_DEFAULT_PYTHON=`pyenv which python3`

    # Adding pipx apps to PATH
    export PATH="$HOME/.local/bin:$PATH"
fi

eval "$(pyenv virtualenv-init -)"


# Custom Aliases
if [ -f "/usr/local/bin/vim" ]; then
    alias vi="/usr/local/bin/vim"
else
    echo "vim not found at /usr/local/bin/vim - skipping 'vi' alias creation"
fi

alias brew='sudo -Hu $HOMEBREW_MAIN_USER brew'
alias lx="ls -latch | vi -"
alias save="~/Documents/dotfiles/scripts/save.sh"
alias load="~/Documents/dotfiles/scripts/load.sh"
alias notes="vi ~/Documents/Journal/notes"
alias ideas="vi ~/Documents/Journal/notes/Ideas.md"
alias fish="asciiquarium"
alias speedread="/usr/local/Homebrew/Library/Taps/homebrew/homebrew-core/Formula/speedread.rb"

# zsh-histdb
if test -f $HOME/.oh-my-zsh/custom/plugins/zsh-histdb/sqlite-history.zsh; then
    HISTDB_TABULATE_CMD=(sed -e $'s/\x1f/\t/g')
    source $HOME/.oh-my-zsh/custom/plugins/zsh-histdb/sqlite-history.zsh
fi
autoload -Uz add-zsh-hook
