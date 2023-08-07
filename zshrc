# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load. Optionally, if you set this to "random"
# it'll load a random theme each time that oh-my-zsh is loaded.
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
#ZSH_THEME="robbyrussell"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to load
# Setting this variable when ZSH_THEME=random
# cause zsh load theme from this variable instead of
# looking in ~/.oh-my-zsh/themes/
# An empty array have no effect
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

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
)

source $ZSH/oh-my-zsh.sh

#PROMPT='$(kube_ps1)'$PROMPT

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
alias k="kubectl"

alias gitref="cat ~/git-alias-ref.txt | grep"

alias xcopy="xclip -selection c"
alias xpaste="xclip -selection clipboard -o"

alias tmate.copy="tmate show-messages | egrep -o 'ssh session: (.*)' | xcopy; echo 'copied!'"

# Temp for Homebase project (remove me when done!)
alias ag='ag --path-to-ignore /src/.agignore'

function docker.set_ruby_version {
  export RUBY_VERSION=$1
}

function code-remote {
  p=$(printf "%s" "$1" | xxd -p) && code --folder-uri "vscode-remote://dev-container+${p//[[:space:]]/}/$2"
}

# Alias hub to git
# eval "$(hub alias -s)"
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# tabtab source for serverless package
# uninstall by removing these lines or running `tabtab uninstall serverless`
[[ -f /home/ben/.config/yarn/global/node_modules/tabtab/.completions/serverless.zsh ]] && . /home/ben/.config/yarn/global/node_modules/tabtab/.completions/serverless.zsh
# tabtab source for sls package
# uninstall by removing these lines or running `tabtab uninstall sls`
[[ -f /home/ben/.config/yarn/global/node_modules/tabtab/.completions/sls.zsh ]] && . /home/ben/.config/yarn/global/node_modules/tabtab/.completions/sls.zsh

# Load zsh-hist if it is present
[[ -f $ZSH/custom/plugins/zsh-hist/zsh-hist.plugin.zsh ]] && source $ZSH/custom/plugins/zsh-hist/zsh-hist.plugin.zsh

zshaddhistory() {
 [[ $1 != 'hist '* ]]
}

alias disablehistory="function zshaddhistory() {  return 1 }"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

inith() {
  if [ $# -ne 3 ]; then
    echo "Usage: inith <password> <key> <host>"
    return 1
  fi

  local password="$1"
  local key="$2"
  local host="$3"

  echo >> ~/.zshrc
  echo >> ~/.zshrc
  echo "export ATUIN_HOST_NAME=$host" >> ~/.zshrc
  echo "export ATUIN_HOST_USER=ben" >> ~/.zshrc
  echo 'eval "$(atuin init zsh --disable-up-arrow)"' >> ~/.zshrc

  atuin logout > /dev/null 2>&1
  atuin login -u ben -p "$password" -k "$key"

  source ~/.zshrc
}
