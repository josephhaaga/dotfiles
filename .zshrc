# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

# Environment Variables for GraknAI
export JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk1.8.0_192.jdk/Contents/Home/
export PYSPARK_DRIVER_PYTHON=/anaconda3/bin/jupyter
export PYSPARK_DRIVER_PYTHON_OPTS=notebook
export SPARK_OPTS="--packages graphframes:graphframes:0.6.0-spark2.3-2_2.11"

# Environment variables for Neo4J-Spark connector
# export $SPARK_HOME=/usr/local 

# Set name of the theme to load. Optionally, if you set this to "random"
# it'll load a random theme each time that oh-my-zsh is loaded.
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
#ZSH_THEME="materialshell"
ZSH_THEME="agnoster"
DEFAULT_USER="josephhaaga"
prompt_context(){}


# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion. Case
# sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
    git
    shrink-path
)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ssh
# export SSH_KEY_PATH="~/.ssh/rsa_id"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# setopt prompt_subst
# PS1='%n@%m $(shrink_path -f)>'


# Set name of the theme to load. Optionally, if you set this to "random"
# it'll load a random theme each time that oh-my-zsh is loaded.
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
#ZSH_THEME="materialshell"
# ZSH_THEME="agnoster"
# DEFAULT_USER="josephhaaga"
# prompt_context(){}



# added by Anaconda3 5.0.1 installer
# export PATH="/anaconda3/bin:$PATH"
# . /anaconda3/etc/profile.d/conda.sh  # commented out by conda initialize




# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/josephhaaga/Downloads/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/josephhaaga/Downloads/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/josephhaaga/Downloads/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/josephhaaga/Downloads/google-cloud-sdk/completion.zsh.inc'; fi

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/Users/josephhaaga/anaconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/Users/josephhaaga/anaconda3/etc/profile.d/conda.sh" ]; then
        . "/Users/josephhaaga/anaconda3/etc/profile.d/conda.sh"
    else
        export PATH="/Users/josephhaaga/anaconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<


# Python environment
export PYTHONDONTWRITEBYTECODE=1

# Custom Aliases
alias ssh6340="ssh -p 1234 cs6340@localhost"
alias start6340="VBoxManage startvm \"CS6340 VM Fall 2019 18.04LTS\" --type headless"
alias stop6340="VBoxManage controlvm \"CS6340 VM Fall 2019 18.04LTS\" poweroff"
alias updatetodo="git add . && git commit -m 'update todo' && git push"

# alias python3="~/anaconda3/bin/python3"
# alias pip="~/anaconda3/bin/pip3"
alias todo="python3 ~/Documents/code/todos/todos/main.py"
alias lx="ls -latch | vi -"
alias vi="/usr/local/bin/vim"
alias save="~/Documents/Utilities/save.sh"

alias fraym="cd ~/Documents/freelance/Fraym"

export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

