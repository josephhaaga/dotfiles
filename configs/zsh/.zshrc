# oh-my-zsh setup
export ZSH=$HOME/.oh-my-zsh

ZSH_THEME="wedisagree" # set by `omz`

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

# for `kata/openmhz-to-map`
export PATH="/opt/homebrew/opt/ffmpeg@6/bin:$PATH"
export DYLD_LIBRARY_PATH=$(brew --prefix ffmpeg)/lib:$DYLD_LIBRARY_PATH

# for `tldr`
export TEALDEER_CONFIG_DIR="~/.config/tealdeer"

# set Brewfile location for `brew bundle` commands
export HOMEBREW_BREWFILE="~/.config/brew/Brewfile"
function brew() {
    if [[ "$1" == "bundle" ]]; then
        # Check if --file is specified
        if [[ "$*" != *"--file"* ]]; then
            # Add --file ./some/path if not specified
            command brew bundle --file $HOMEBREW_BREWFILE "${@:2}"
        else
            # Run the command as is
            command brew "$@"
        fi
    else
        # Run the command as is for other brew commands
        command brew "$@"
    fi
}
